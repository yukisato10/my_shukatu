// lib/notifications/notification_settings_service.dart

import 'package:shared_preferences/shared_preferences.dart';

class NotificationSettingsService {
  static const String _scheduleNotificationKey = 'scheduleNotificationEnabled';
  static const String _newsNotificationKey = 'newsNotificationEnabled';

  /// 予定通知のON/OFF取得
  static Future<bool> isScheduleNotificationEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_scheduleNotificationKey) ?? true;
  }

  /// 予定通知のON/OFF保存
  static Future<void> setScheduleNotificationEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_scheduleNotificationKey, enabled);
  }

  /// ニュース通知のON/OFF取得
  static Future<bool> isNewsNotificationEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_newsNotificationKey) ?? true;
  }

  /// ニュース通知のON/OFF保存
  static Future<void> setNewsNotificationEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_newsNotificationKey, enabled);
  }
}