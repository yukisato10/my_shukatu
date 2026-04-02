import 'package:flutter/material.dart';
import '../config/ad_config.dart';
import '../widgets/banner_ad_widget.dart';

class AdScaffold extends StatelessWidget {
  const AdScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.bottomSheet,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.drawer,
    this.endDrawer,
    this.backgroundColor,
    this.resizeToAvoidBottomInset = true,
    this.showBanner = true,
  });

  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? bottomSheet;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget? drawer;
  final Widget? endDrawer;
  final Color? backgroundColor;
  final bool resizeToAvoidBottomInset;
  final bool showBanner;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      body: body,
      bottomSheet: bottomSheet,
      drawer: drawer,
      endDrawer: endDrawer,
      backgroundColor: backgroundColor,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      bottomNavigationBar: showBanner &&
          AdConfig.adsEnabled &&
          AdConfig.bannerEnabled
          ? BannerAdWidget(
        adUnitId: AdConfig.bannerUnitId,
      )
          : null,
    );
  }
}
