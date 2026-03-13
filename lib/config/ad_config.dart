import 'dart:io';

class AdConfig {

  // 広告全体
  static const bool adsEnabled = true;

  // 個別制御
  static const bool bannerEnabled = true;
  static const bool interstitialEnabled = false;
  static const bool appOpenEnabled = false;

  static const bool useTestAds = false;

  // Banner test
  // static const String testBanner =
  //     'ca-app-pub-3940256099942544/6300978111';

  // Interstitial test
  static const String testInterstitial =
      'ca-app-pub-3940256099942544/1033173712';

  // App Open test
  static const String testAppOpenAndroid =
      'ca-app-pub-3940256099942544/9257395921';
  static const String testAppOpenIos =
      'ca-app-pub-3940256099942544/5575463023';

  // ===== 本番ID =====
  static const String androidBanner =
      'ca-app-pub-8287454355119436/2569422898';
  static const String iosBanner =
      'ca-app-pub-8287454355119436/2241193794';

  static const String androidInterstitial =
      'ca-app-pub-xxxxxxxxxxxxxxxx/xxxxxxxxxx';
  static const String iosInterstitial =
      'ca-app-pub-xxxxxxxxxxxxxxxx/xxxxxxxxxx';

  static const String androidAppOpen =
      'ca-app-pub-xxxxxxxxxxxxxxxx/xxxxxxxxxx';
  static const String iosAppOpen =
      'ca-app-pub-xxxxxxxxxxxxxxxx/xxxxxxxxxx';

  static String get bannerUnitId {

    if (Platform.isAndroid) return androidBanner;
    if (Platform.isIOS) return iosBanner;
    return androidBanner;
  }

  static String get interstitialUnitId {
    if (useTestAds) return testInterstitial;
    if (Platform.isAndroid) return androidInterstitial;
    if (Platform.isIOS) return iosInterstitial;
    return testInterstitial;
  }

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
