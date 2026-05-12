// lib/notifications/news_notification_service.dart

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NewsNotificationService {
  NewsNotificationService._();

  static const String _topicName = 'job_news';
  static const String _prefKey = 'newsNotificationEnabled';

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// 初期化
  static Future<void> initialize() async {
    await _requestPermission();

    final enabled = await isEnabled();
    if (enabled) {
      await subscribe();
    }
  }

  /// 通知許可リクエスト
  static Future<void> _requestPermission() async {
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  /// ニュース通知ON
  static Future<void> subscribe() async {
    await _messaging.subscribeToTopic(_topicName);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, true);
  }

  /// ニュース通知OFF
  static Future<void> unsubscribe() async {
    await _messaging.unsubscribeFromTopic(_topicName);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, false);
  }

  /// ON/OFF切り替え
  static Future<void> setEnabled(bool enabled) async {
    if (enabled) {
      await subscribe();
    } else {
      await unsubscribe();
    }
  }

  /// 現在の設定取得
  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();

    // デフォルトはON
    return prefs.getBool(_prefKey) ?? true;
  }

  /// FCMトークン確認用
  static Future<String?> getToken() async {
    return _messaging.getToken();
  }
}