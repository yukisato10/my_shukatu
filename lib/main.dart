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
import 'notifications/news_notification_service.dart';
import 'notifications/schedule_notification_scheduler.dart';

final ValueNotifier<String> startupStatus =
ValueNotifier<String>('起動診断を開始しています...');

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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const StartupDiagnosticApp());

  await _runStartupDiagnostics();
}

Future<void> _runStartupDiagnostics() async {
  try {
    startupStatus.value = 'STEP 1: Firebase 初期化中...';
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    startupStatus.value = 'STEP 1: Firebase 完了';

    startupStatus.value = 'STEP 2: Hive 初期化中...';
    await HiveService.init();
    startupStatus.value = 'STEP 2: Hive 完了';

    startupStatus.value = 'STEP 3: 日付フォーマット初期化中...';
    await initializeDateFormatting('ja_JP', null);
    startupStatus.value = 'STEP 3: 日付フォーマット完了';

    startupStatus.value = 'STEP 4: 画面向き固定中...';
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    startupStatus.value = 'STEP 4: 画面向き固定完了';

    startupStatus.value = 'STEP 5: 通知初期化中...';
    await NotificationService.initialize();
    startupStatus.value = 'STEP 5: 通知初期化完了';

    startupStatus.value = 'STEP 6: ニュース通知初期化中...';
    await NewsNotificationService.initialize();
    startupStatus.value = 'STEP 6: ニュース通知初期化完了';

    startupStatus.value = 'STEP 7: 既存予定通知の再登録中...';
    await _rescheduleExistingNotifications();
    startupStatus.value = 'STEP 7: 既存予定通知の再登録完了';

    startupStatus.value = 'STEP 8: Analytics送信中...';
    await FirebaseAnalytics.instance.logEvent(
      name: 'app_start',
    );
    startupStatus.value = 'STEP 8: Analytics送信完了';

    startupStatus.value = 'STEP 9: MobileAds初期化中...';
    await MobileAds.instance.initialize();
    startupStatus.value = 'STEP 9: MobileAds初期化完了';

    startupStatus.value = 'STEP 10: インタースティシャル広告ロード中...';
    await InterstitialAdManager.preload();
    startupStatus.value = 'STEP 10: インタースティシャル広告ロード完了';

    startupStatus.value = 'STEP 11: AppOpen広告初期化中...';
    await AppOpenAdManager.initialize();
    startupStatus.value = 'STEP 11: AppOpen広告初期化完了';

    startupStatus.value = 'STEP 12: アプリ起動完了';

    await Future.delayed(const Duration(milliseconds: 500));

    runApp(const MyApp());
  } catch (e, s) {
    debugPrint('STARTUP ERROR: $e');
    debugPrintStack(stackTrace: s);

    startupStatus.value = '起動エラー発生:\n$e';
  }
}

class StartupDiagnosticApp extends StatelessWidget {
  const StartupDiagnosticApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ValueListenableBuilder<String>(
              valueListenable: startupStatus,
              builder: (context, value, _) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 24),
                    const Text(
                      '起動診断中',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      value,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.5,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
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