import 'dart:async';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/ad_config.dart';

class InterstitialAdManager {
  InterstitialAdManager._();

  static const _kLastShownMillis = 'ad_last_shown_millis';
  static const _cooldown = Duration(hours: 24);

  static InterstitialAd? _ad;
  static bool _loading = false;
  static bool _showing = false;

  /// 事前ロード（起動時に呼ぶ推奨）
  static Future<void> preload({String? adUnitId}) async {
    if (!AdConfig.adsEnabled) return;
    if (!AdConfig.interstitialEnabled) return;
    if (_ad != null || _loading) return;

    _loading = true;
    final c = Completer<void>();

    InterstitialAd.load(
      adUnitId: adUnitId ?? AdConfig.interstitialUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _ad = ad;
          _loading = false;
          c.complete();
        },
        onAdFailedToLoad: (err) {
          _loading = false;
          c.complete();
        },
      ),
    );

    await c.future;
  }

  /// 24時間に1回だけ表示（表示できたらtrue）
  static Future<bool> showIfAllowed({String? adUnitId}) async {
    if (!AdConfig.adsEnabled) return false;
    if (!AdConfig.interstitialEnabled) return false;
    if (_showing) return false;

    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getInt(_kLastShownMillis);
    final now = DateTime.now().millisecondsSinceEpoch;

    final allowed = last == null || (now - last) >= _cooldown.inMilliseconds;
    if (!allowed) return false;

    if (_ad == null) {
      await preload(adUnitId: adUnitId);
    }

    final ad = _ad;
    if (ad == null) return false;

    _showing = true;
    final completer = Completer<bool>();

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) async {
        await prefs.setInt(_kLastShownMillis, now);
      },
      onAdDismissedFullScreenContent: (ad) async {
        ad.dispose();
        _ad = null;
        _showing = false;
        await preload(adUnitId: adUnitId);
        if (!completer.isCompleted) completer.complete(true);
      },
      onAdFailedToShowFullScreenContent: (ad, err) async {
        ad.dispose();
        _ad = null;
        _showing = false;
        await preload(adUnitId: adUnitId);
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

  static void dispose() {
    _ad?.dispose();
    _ad = null;
    _loading = false;
    _showing = false;
  }
}