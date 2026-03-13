import 'dart:async';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/ad_config.dart';

class AppOpenAdManager {
  AppOpenAdManager._();

  static AppOpenAd? _appOpenAd;
  static bool _isLoading = false;
  static bool _isShowing = false;
  static DateTime? _loadedAt;
  static StreamSubscription<AppState>? _appStateSub;

  static const _kLastShownMillis = 'app_open_last_shown_millis';

  // 1日1回
  static const Duration cooldown = Duration(hours: 24);

  /// App Open 広告は4時間を超えると期限切れ扱い
  static const Duration maxCacheAge = Duration(hours: 4);

  static bool get _isAdAvailable {
    return _appOpenAd != null &&
        _loadedAt != null &&
        DateTime.now().difference(_loadedAt!) < maxCacheAge;
  }

  static Future<void> initialize() async {
    if (!AdConfig.adsEnabled) return;
    if (!AdConfig.appOpenEnabled) return;

    await loadAd();

    _appStateSub ??=
        AppStateEventNotifier.appStateStream.listen((AppState state) async {
          if (state == AppState.foreground) {
            await showIfAvailable();
          }
        });
  }

  static Future<void> loadAd() async {
    if (!AdConfig.adsEnabled) return;
    if (!AdConfig.appOpenEnabled) return;
    if (_isLoading) return;
    if (_isAdAvailable) return;

    _isLoading = true;

    final completer = Completer<void>();

    AppOpenAd.load(
      adUnitId: AdConfig.appOpenUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _appOpenAd?.dispose();
          _appOpenAd = ad;
          _loadedAt = DateTime.now();
          _isLoading = false;
          completer.complete();
        },
        onAdFailedToLoad: (error) {
          _isLoading = false;
          completer.complete();
        },
      ),
    );

    await completer.future;
  }

  static Future<bool> _isCooldownPassed() async {
    final prefs = await SharedPreferences.getInstance();
    final lastMillis = prefs.getInt(_kLastShownMillis);
    if (lastMillis == null) return true;

    final last = DateTime.fromMillisecondsSinceEpoch(lastMillis);
    return DateTime.now().difference(last) >= cooldown;
  }

  static Future<void> _markShownNow() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _kLastShownMillis,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  static Future<bool> showIfAvailable() async {
    if (!AdConfig.adsEnabled) return false;
    if (!AdConfig.appOpenEnabled) return false;
    if (_isShowing) return false;

    final allowed = await _isCooldownPassed();
    if (!allowed) return false;

    if (!_isAdAvailable) {
      await loadAd();
    }

    final ad = _appOpenAd;
    if (ad == null) return false;

    _isShowing = true;

    final completer = Completer<bool>();

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) async {
        await _markShownNow();
      },
      onAdDismissedFullScreenContent: (ad) async {
        ad.dispose();
        _appOpenAd = null;
        _loadedAt = null;
        _isShowing = false;
        unawaited(loadAd());
        if (!completer.isCompleted) completer.complete(true);
      },
      onAdFailedToShowFullScreenContent: (ad, error) async {
        ad.dispose();
        _appOpenAd = null;
        _loadedAt = null;
        _isShowing = false;
        unawaited(loadAd());
        if (!completer.isCompleted) completer.complete(false);
      },
    );

    ad.show();
    return completer.future;
  }

  static Future<void> resetCooldownForTest() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kLastShownMillis);
  }

  static Future<void> dispose() async {
    await _appStateSub?.cancel();
    _appStateSub = null;
    _appOpenAd?.dispose();
    _appOpenAd = null;
    _loadedAt = null;
    _isLoading = false;
    _isShowing = false;
  }
}