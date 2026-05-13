import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

import 'firebase_options.dart';
import 'db/hive_service.dart';
import 'models/company.dart';

import 'pages/home_page.dart';
import 'pages/company_page.dart';
import 'pages/memo_page.dart';
import 'pages/agent_page.dart';

import 'ads/interstitial_ad_manager.dart';
import 'ads/app_open_ad_manager.dart';

import 'notifications/notification_service.dart';
import 'notifications/schedule_notification_scheduler.dart';

String scheduleTypeLabel(ScheduleType type) {
  switch (type) {
    case ScheduleType.event:
      return '説明会';
    case ScheduleType.esDeadline:
      return 'ES締切';
    case ScheduleType.webTest:
      return 'WEBテスト';
    case ScheduleType.gd:
      return 'GD';
    case ScheduleType.interview1:
      return '1次面接';
    case ScheduleType.interview2:
      return '2次面接';
    case ScheduleType.interview3:
      return '3次面接';
    case ScheduleType.interview4:
      return '4次面接';
    case ScheduleType.finalInterview:
      return '最終面接';
    case ScheduleType.other:
      return 'その他';
  }
}

Future<void> _rescheduleExistingNotifications() async {
  final enabled = await ScheduleNotificationScheduler.isEnabled();

  if (!enabled) {
    await ScheduleNotificationScheduler.cancelAll();
    return;
  }

  final box = HiveService.companyBox();
  final items = <ScheduleNotificationItem>[];

  for (final company in box.values) {
    for (final schedule in company.schedules) {
      items.add(
        ScheduleNotificationItem(
          date: schedule.dateTime,
          typeLabel: scheduleTypeLabel(schedule.type),
        ),
      );
    }
  }

  await ScheduleNotificationScheduler.rescheduleAll(items);
}

Future<void> _initializeAfterLaunch() async {
  try {
    await FirebaseAnalytics.instance.logEvent(
      name: 'app_start',
    );

    await NotificationService.initialize();

    await Future.wait([
      _rescheduleExistingNotifications(),
      InterstitialAdManager.preload(),
      AppOpenAdManager.initialize(),
    ]);
  } catch (e, st) {
    debugPrint('❌ background initialize error: $e');
    debugPrint('$st');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await HiveService.init();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  await initializeDateFormatting('ja_JP', null);

  await MobileAds.instance.initialize();

  runApp(const MyApp());

  WidgetsBinding.instance.addPostFrameCallback((_) {
    _initializeAfterLaunch();
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('ja', 'JP'),
      supportedLocales: const [
        Locale('ja', 'JP'),
      ],
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

class _RootScreenState extends State<RootScreen>
    with WidgetsBindingObserver {
  int _index = 0;
  bool _hasGoneBackground = false;

  final pages = const [
    HomePage(),
    CompanyPage(),
    MemoPage(),
    AgentPage(),
  ];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    FirebaseAnalytics.instance.logEvent(
      name: 'view_home',
    );

    InterstitialAdManager.preload();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('📱 lifecycle: $state');

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _hasGoneBackground = true;
      debugPrint('📦 app moved background');
      return;
    }

    if (state == AppLifecycleState.resumed && _hasGoneBackground) {
      debugPrint('🚀 app resumed from background');

      _hasGoneBackground = false;

      AppOpenAdManager.showIfAvailable();
    }
  }

  Future<void> _logTabEvent(int i) async {
    if (i == 0) {
      await FirebaseAnalytics.instance.logEvent(
        name: 'view_home',
      );
    } else if (i == 1) {
      await FirebaseAnalytics.instance.logEvent(
        name: 'view_company_page',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) async {
          await _logTabEvent(i);

          setState(() {
            _index = i;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home),
            label: 'ホーム',
          ),
          NavigationDestination(
            icon: Icon(Icons.apartment),
            label: '企業管理',
          ),
          NavigationDestination(
            icon: Icon(Icons.badge),
            label: 'プロフィール',
          ),
          NavigationDestination(
            icon: Icon(Icons.library_books),
            label: 'お役立ち',
          ),
        ],
      ),
    );
  }
}
