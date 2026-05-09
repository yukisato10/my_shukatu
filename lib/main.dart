import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

import 'firebase_options.dart';
import 'db/hive_service.dart';
import 'pages/home_page.dart';
import 'pages/company_page.dart';
import 'pages/memo_page.dart';
import 'pages/agent_page.dart';
import 'ads/interstitial_ad_manager.dart';
import 'ads/app_open_ad_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await FirebaseAnalytics.instance.logEvent(
    name: 'app_start',
  );

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  await MobileAds.instance.initialize();

  await InterstitialAdManager.preload();

  // 初回起動では表示せず、バックグラウンド復帰時だけ表示
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
      home: const RootScreen(),
    );
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

    FirebaseAnalytics.instance.logEvent(
      name: 'view_home',
    );

    InterstitialAdManager.preload();
  }

  Future<void> _logTabEvent(int i) async {
    if (i == 0) {
      await FirebaseAnalytics.instance.logEvent(name: 'view_home');
    } else if (i == 1) {
      await FirebaseAnalytics.instance.logEvent(name: 'view_company_page');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) async {
          await _logTabEvent(i);
          setState(() => _index = i);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'ホーム'),
          NavigationDestination(icon: Icon(Icons.apartment), label: '企業管理'),
          NavigationDestination(icon: Icon(Icons.badge), label: 'プロフィール'),
          NavigationDestination(icon: Icon(Icons.library_books), label: 'お役立ち'),
        ],
      ),
    );
  }
}