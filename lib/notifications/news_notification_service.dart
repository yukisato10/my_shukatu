// lib/notifications/news_notification_service.dart

import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NewsNotificationService {
  NewsNotificationService._();

  static const String _topicName = 'job_news';
  static const String _prefKey = 'newsNotificationEnabled';

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// 初期化
  static Future<void> initialize() async {
    await _requestPermission();

    if (Platform.isIOS) {
      await _waitForApnsToken();
    }

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

  /// iOS用：APNs tokenが取得できるまで待つ
  static Future<String?> _waitForApnsToken() async {
    if (!Platform.isIOS) {
      return null;
    }

    for (int i = 0; i < 10; i++) {
      final apnsToken = await _messaging.getAPNSToken();

      if (apnsToken != null) {
        debugPrint('APNs token received');
        return apnsToken;
      }

      await Future.delayed(const Duration(seconds: 1));
    }

    debugPrint('APNs token not received yet');
    return null;
  }

  /// ニュース通知ON
  static Future<void> subscribe() async {
    if (Platform.isIOS) {
      final apnsToken = await _waitForApnsToken();

      if (apnsToken == null) {
        debugPrint('subscribeToTopic skipped: APNs token not ready');
        return;
      }
    }

    await _messaging.subscribeToTopic(_topicName);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, true);
  }

  /// ニュース通知OFF
  static Future<void> unsubscribe() async {
    if (Platform.isIOS) {
      final apnsToken = await _waitForApnsToken();

      if (apnsToken == null) {
        debugPrint('unsubscribeFromTopic skipped: APNs token not ready');
        return;
      }
    }

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
    if (Platform.isIOS) {
      final apnsToken = await _waitForApnsToken();

      if (apnsToken == null) {
        debugPrint('getToken skipped: APNs token not ready');
        return null;
      }
    }

    return _messaging.getToken();
  }
}