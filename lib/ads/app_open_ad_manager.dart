import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/ad_config.dart';

class AppOpenAdManager {
  AppOpenAdManager._();

  static AppOpenAd? _appOpenAd;
  static bool _isLoading = false;
  static bool _isShowing = false;
  static DateTime? _loadedAt;

  static const _kLastShownMillis = 'app_open_last_shown_millis';

  // 6時間ごとに1回まで表示
  static const Duration cooldown = Duration(hours: 6);

  // App Open広告は4時間で期限切れ
  static const Duration maxCacheAge = Duration(hours: 4);

  static bool get _isAdAvailable {
    return _appOpenAd != null &&
        _loadedAt != null &&
        DateTime.now().difference(_loadedAt!) < maxCacheAge;
  }

  static Future<void> initialize() async {
    debugPrint('🟦 initialize called');

    if (!AdConfig.adsEnabled) {
      debugPrint('❌ adsEnabled false');
      return;
    }

    if (!AdConfig.appOpenEnabled) {
      debugPrint('❌ appOpenEnabled false');
      return;
    }

    await loadAd();
  }

  static Future<void> loadAd() async {
    debugPrint('⏳ loadAd called');

    if (!AdConfig.adsEnabled) return;
    if (!AdConfig.appOpenEnabled) return;
    if (_isLoading) return;

    if (_isAdAvailable) {
      debugPrint('✅ already loaded');
      return;
    }

    _isLoading = true;

    final completer = Completer<void>();

    AppOpenAd.load(
      adUnitId: AdConfig.appOpenUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('✅ AppOpenAd loaded');

          _appOpenAd?.dispose();
          _appOpenAd = ad;
          _loadedAt = DateTime.now();
          _isLoading = false;

          if (!completer.isCompleted) {
            completer.complete();
          }
        },
        onAdFailedToLoad: (error) {
          debugPrint('❌ AppOpenAd failed: $error');

          _isLoading = false;

          if (!completer.isCompleted) {
            completer.complete();
          }
        },
      ),
    );

    await completer.future;
  }

  static Future<bool> _isCooldownPassed() async {
    final prefs = await SharedPreferences.getInstance();
    final lastMillis = prefs.getInt(_kLastShownMillis);

    if (lastMillis == null) {
      debugPrint('✅ cooldown first');
      return true;
    }

    final last = DateTime.fromMillisecondsSinceEpoch(lastMillis);

    final passed =
        DateTime.now().difference(last) >= cooldown;

    debugPrint('⏱ cooldown passed: $passed');

    return passed;
  }

  static Future<void> _markShownNow() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setInt(
      _kLastShownMillis,
      DateTime.now().millisecondsSinceEpoch,
    );

    debugPrint('📝 marked shown');
  }

  static Future<bool> showIfAvailable() async {
    debugPrint('🟨 showIfAvailable called');

    if (!AdConfig.adsEnabled) return false;
    if (!AdConfig.appOpenEnabled) return false;

    if (_isShowing) {
      debugPrint('⚠ already showing');
      return false;
    }

    final allowed = await _isCooldownPassed();

    if (!allowed) {
      debugPrint('⚠ cooldown not passed');
      return false;
    }

    if (!_isAdAvailable) {
      debugPrint('⚠ ad unavailable -> reload');

      await loadAd();
    }

    final ad = _appOpenAd;

    if (ad == null) {
      debugPrint('❌ ad null');
      return false;
    }

    _isShowing = true;

    final completer = Completer<bool>();

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) async {
        debugPrint('🚀 ad showed');

        await _markShownNow();
      },
      onAdDismissedFullScreenContent: (ad) async {
        debugPrint('✅ ad dismissed');

        ad.dispose();

        _appOpenAd = null;
        _loadedAt = null;
        _isShowing = false;

        unawaited(loadAd());

        if (!completer.isCompleted) {
          completer.complete(true);
        }
      },
      onAdFailedToShowFullScreenContent: (ad, error) async {
        debugPrint('❌ failed to show: $error');

        ad.dispose();

        _appOpenAd = null;
        _loadedAt = null;
        _isShowing = false;

        unawaited(loadAd());

        if (!completer.isCompleted) {
          completer.complete(false);
        }
      },
    );

    debugPrint('🚀 ad.show called');

    ad.show();

    return completer.future;
  }

  static Future<void> resetCooldownForTest() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_kLastShownMillis);

    debugPrint('🧪 cooldown reset');
  }

  static Future<void> dispose() async {
    debugPrint('🧹 dispose');

    _appOpenAd?.dispose();

    _appOpenAd = null;

    _loadedAt = null;
    _isLoading = false;
    _isShowing = false;
  }
}
