import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/ad_config.dart';

class NativeAdWidget extends StatefulWidget {
  const NativeAdWidget({super.key});

  @override
  State<NativeAdWidget> createState() => _NativeAdWidgetState();
}

class _NativeAdWidgetState extends State<NativeAdWidget> {
  NativeAd? _nativeAd;

  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();

    if (!AdConfig.adsEnabled) return;
    if (!AdConfig.nativeEnabled) return;

    if (!Platform.isIOS) return;

    _loadAd();
  }

  void _loadAd() {
    _nativeAd = NativeAd(
      adUnitId: AdConfig.nativeUnitId,
      factoryId: 'listTile',
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          debugPrint('✅ Native Ad Loaded');

          if (!mounted) return;

          setState(() {
            _isLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint(
            '❌ Native Ad Load Failed: ${error.message}',
          );

          ad.dispose();
        },
      ),
      request: const AdRequest(),
    );

    _nativeAd?.load();
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded || _nativeAd == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Theme.of(context).cardColor,
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 120,
        child: AdWidget(
          ad: _nativeAd!,
        ),
      ),
    );
  }
}
