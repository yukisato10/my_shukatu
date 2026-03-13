import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/services.dart';
import 'db/hive_service.dart';
import 'pages/home_page.dart';
import 'pages/company_page.dart';
import 'pages/memo_page.dart';
import 'pages/agent_page.dart';
import 'ads/interstitial_ad_manager.dart';
import 'ads/app_open_ad_manager.dart';

Future<void> main() async {


  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  await MobileAds.instance.initialize();
  await InterstitialAdManager.preload();
  await AppOpenAdManager.initialize();
  await HiveService.init();
  await initializeDateFormatting('ja_JP', null);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('ja', 'JP'),
      supportedLocales: const [Locale('ja', 'JP')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.white,
          brightness: Brightness.light,
        ).copyWith(
          surface: Colors.white,
          background: Colors.white,
          surfaceContainer: Colors.white,
        ),
      ),
      home: const StartupGate(),
    );
  }
}

class StartupGate extends StatefulWidget {
  const StartupGate({super.key});

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    await Future.delayed(const Duration(milliseconds: 500));
    await AppOpenAdManager.showIfAvailable();

    if (!mounted) return;
    setState(() => _done = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_done) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return const RootScreen();
  }
}

class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  int _index = 0;

  final pages = const [
    HomePage(),
    CompanyPage(),
    MemoPage(),
    AgentPage(),
  ];

  @override
  void initState() {
    super.initState();

    // 次回の自然な表示用に先読みだけしておく
    InterstitialAdManager.preload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: "ホーム"),
          NavigationDestination(icon: Icon(Icons.apartment), label: "企業管理"),
          NavigationDestination(icon: Icon(Icons.badge), label: "プロフィール"),
          NavigationDestination(icon: Icon(Icons.library_books), label: "お役立ち"),
        ],
      ),
    );
  }
}