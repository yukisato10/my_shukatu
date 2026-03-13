// lib/widgets/banner_ad_widget.dart
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// ページ下に置く「アンカー型アダプティブバナー」
///
/// 使い方：
/// Scaffold(
///   body: ...,
///   bottomNavigationBar: const BannerAdWidget(adUnitId: 'あなたの広告ユニットID'),
/// )
class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({
    super.key,
    required this.adUnitId,
    this.enabled = true,
    this.placeholderHeight = 0, // 0ならロード前は何も出さない
  });

  /// AdMobのバナー広告ユニットID
  final String adUnitId;

  /// 広告を無効化したい時用（課金で広告OFFなど）
  final bool enabled;

  /// ロード前に確保する高さ（0推奨）
  final double placeholderHeight;

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _banner;
  AdSize? _size;
  bool _loading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ensureLoaded();
  }

  Future<void> _ensureLoaded() async {
    if (!widget.enabled) return;
    if (_loading) return;
    if (_banner != null) return;

    _loading = true;

    final width = MediaQuery.sizeOf(context).width.truncate();
    final size = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width);

    if (!mounted || size == null) {
      _loading = false;
      return;
    }

    final banner = BannerAd(
      adUnitId: widget.adUnitId,
      request: const AdRequest(),
      size: size,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) return;
          setState(() {
            _banner = ad as BannerAd;
            _size = size;
          });
        },
        onAdFailedToLoad: (ad, err) {
          ad.dispose();
          _loading = false;
        },
      ),
    );

    await banner.load();

    if (!mounted) {
      banner.dispose();
      _loading = false;
      return;
    }

    _loading = false;
  }

  @override
  void didUpdateWidget(covariant BannerAdWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 広告ID/有効状態が変わったら作り直す
    if (oldWidget.adUnitId != widget.adUnitId || oldWidget.enabled != widget.enabled) {
      _banner?.dispose();
      _banner = null;
      _size = null;
      _loading = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _ensureLoaded());
    }
  }

  @override
  void dispose() {
    _banner?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return const SizedBox.shrink();

    final banner = _banner;
    final size = _size;

    if (banner == null || size == null) {
      if (widget.placeholderHeight <= 0) return const SizedBox.shrink();
      return SizedBox(height: widget.placeholderHeight);
    }

    return SafeArea(
      top: false,
      child: SizedBox(
        width: size.width.toDouble(),
        height: size.height.toDouble(),
        child: AdWidget(ad: banner),
      ),
    );
  }
}
