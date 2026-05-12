import 'dart:io';

class AdConfig {

  // 広告全体
  static const bool adsEnabled = true;

  // 個別制御
  static const bool bannerEnabled = true;
  static const bool interstitialEnabled = false;
  static const bool appOpenEnabled = true;

  // ネイティブ広告
  static const bool nativeEnabled = true;

  // 開発中は true 推奨
  static const bool useTestAds = true;

  // =========================
  // Test Ad Unit IDs
  // =========================

  // Banner test
  static const String testBanner =
      'ca-app-pub-3940256099942544/6300978111';

  // Interstitial test
  static const String testInterstitial =
      'ca-app-pub-3940256099942544/1033173712';

  // Native test
  static const String testNativeAndroid =
      'ca-app-pub-3940256099942544/2247696110';

  static const String testNativeIos =
      'ca-app-pub-3940256099942544/3986624511';

  // App Open test
  static const String testAppOpenAndroid =
      'ca-app-pub-3940256099942544/9257395921';

  static const String testAppOpenIos =
      'ca-app-pub-3940256099942544/5575463023';

  // =========================
  // Production Ad Unit IDs
  // =========================

  // Banner
  static const String androidBanner =
      'ca-app-pub-8287454355119436/2569422898';

  static const String iosBanner =
      'ca-app-pub-8287454355119436/2241193794';

  // Interstitial
  static const String androidInterstitial =
      'ca-app-pub-xxxxxxxxxxxxxxxx/xxxxxxxxxx';

  static const String iosInterstitial =
      'ca-app-pub-xxxxxxxxxxxxxxxx/xxxxxxxxxx';

  // Native
  // Androidでは使わない
  static const String androidNative = '';

  static const String iosNative =
      'ca-app-pub-8287454355119436/3789726871';

  // App Open
  static const String androidAppOpen =
      'ca-app-pub-8287454355119436/3963019675';

  static const String iosAppOpen =
      'ca-app-pub-8287454355119436/5451361161';

  // =========================
  // Banner
  // =========================

  static String get bannerUnitId {
    if (useTestAds) {
      return testBanner;
    }

    if (Platform.isAndroid) return androidBanner;
    if (Platform.isIOS) return iosBanner;

    return testBanner;
  }

  // =========================
  // Interstitial
  // =========================

  static String get interstitialUnitId {
    if (useTestAds) {
      return testInterstitial;
    }

    if (Platform.isAndroid) return androidInterstitial;
    if (Platform.isIOS) return iosInterstitial;

    return testInterstitial;
  }

  // =========================
  // Native
  // =========================

  static String get nativeUnitId {
    if (useTestAds) {
      if (Platform.isIOS) return testNativeIos;
      return testNativeAndroid;
    }

    if (Platform.isIOS) return iosNative;

    // Androidでは使用しない
    return testNativeAndroid;
  }

  // =========================
  // App Open
  // =========================

  static String get appOpenUnitId {
    if (useTestAds) {
      if (Platform.isAndroid) return testAppOpenAndroid;
      if (Platform.isIOS) return testAppOpenIos;

      return testAppOpenAndroid;
    }

    if (Platform.isAndroid) return androidAppOpen;
    if (Platform.isIOS) return iosAppOpen;

    return testAppOpenAndroid;
  }
}