import 'package:shared_preferences/shared_preferences.dart';

import 'notification_service.dart';

class ScheduleNotificationItem {
  final DateTime date;
  final String typeLabel;

  const ScheduleNotificationItem({
    required this.date,
    required this.typeLabel,
  });
}

class ScheduleNotificationScheduler {
  ScheduleNotificationScheduler._();

  static const String _scheduleEnabledKey = 'schedule_notifications_enabled';

  static const int _todayBaseId = 10000;
  static const int _tomorrowBaseId = 20000;
  static const int _weekBaseId = 30000;

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_scheduleEnabledKey) ?? true;
  }

  static Future<void> setEnabled(
      bool enabled, {
        List<ScheduleNotificationItem> schedules = const [],
      }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_scheduleEnabledKey, enabled);

    if (enabled) {
      await rescheduleAll(schedules);
    } else {
      await cancelAll();
    }
  }

  static Future<void> rescheduleAll(
      List<ScheduleNotificationItem> schedules,
      ) async {
    final enabled = await isEnabled();

    await cancelAll();

    if (!enabled) {
      return;
    }

    await _scheduleTodayNotifications(schedules);
    await _scheduleTomorrowNotifications(schedules);
    await _scheduleWeeklyNotifications(schedules);
  }

  static Future<void> cancelAll() async {
    for (int i = 0; i < 370; i++) {
      await NotificationService.cancel(_todayBaseId + i);
      await NotificationService.cancel(_tomorrowBaseId + i);
      await NotificationService.cancel(_weekBaseId + i);
    }
  }

  static Future<void> _scheduleTodayNotifications(
      List<ScheduleNotificationItem> schedules,
      ) async {
    final today = _dateOnly(DateTime.now());

    for (int i = 0; i < 365; i++) {
      final targetDate = today.add(Duration(days: i));
      final targetSchedules = _itemsOnDate(schedules, targetDate);

      if (targetSchedules.isEmpty) {
        continue;
      }

      final notifyAt = DateTime(
        targetDate.year,
        targetDate.month,
        targetDate.day,
        8,
        0,
      );

      await NotificationService.scheduleDateTime(
        id: _todayBaseId + i,
        title: '今日の予定',
        body: _buildCountBody(targetSchedules),
        dateTime: notifyAt,
      );
    }
  }

  static Future<void> _scheduleTomorrowNotifications(
      List<ScheduleNotificationItem> schedules,
      ) async {
    final today = _dateOnly(DateTime.now());

    for (int i = 1; i <= 365; i++) {
      final targetDate = today.add(Duration(days: i));
      final targetSchedules = _itemsOnDate(schedules, targetDate);

      if (targetSchedules.isEmpty) {
        continue;
      }

      final previousDate = targetDate.subtract(const Duration(days: 1));

      final notifyAt = DateTime(
        previousDate.year,
        previousDate.month,
        previousDate.day,
        19,
        0,
      );

      await NotificationService.scheduleDateTime(
        id: _tomorrowBaseId + i,
        title: '明日の予定',
        body: _buildCountBody(targetSchedules),
        dateTime: notifyAt,
      );
    }
  }

  static Future<void> _scheduleWeeklyNotifications(
      List<ScheduleNotificationItem> schedules,
      ) async {
    final today = _dateOnly(DateTime.now());
    final firstMonday = _nextMonday(today);

    for (int week = 0; week < 52; week++) {
      final monday = firstMonday.add(Duration(days: week * 7));
      final sunday = monday.add(const Duration(days: 6));

      final weekSchedules = schedules.where((item) {
        final d = _dateOnly(item.date);
        return !d.isBefore(monday) && !d.isAfter(sunday);
      }).toList();

      if (weekSchedules.isEmpty) {
        continue;
      }

      final notifyAt = DateTime(
        monday.year,
        monday.month,
        monday.day,
        9,
        0,
      );

      await NotificationService.scheduleDateTime(
        id: _weekBaseId + week,
        title: '今週の予定',
        body: _buildCountBody(weekSchedules),
        dateTime: notifyAt,
      );
    }
  }

  static List<ScheduleNotificationItem> _itemsOnDate(
      List<ScheduleNotificationItem> schedules,
      DateTime date,
      ) {
    final target = _dateOnly(date);

    return schedules.where((item) {
      return _dateOnly(item.date) == target;
    }).toList();
  }

  static String _buildCountBody(List<ScheduleNotificationItem> schedules) {
    final Map<String, int> counts = {};

    for (final item in schedules) {
      final label = item.typeLabel.trim().isEmpty ? 'その他' : item.typeLabel;
      counts[label] = (counts[label] ?? 0) + 1;
    }

    final sortedEntries = counts.entries.toList()
      ..sort((a, b) => _sortPriority(a.key).compareTo(_sortPriority(b.key)));

    return sortedEntries.map((e) => '・${e.key} ${e.value}件').join('\n');
  }

  static int _sortPriority(String label) {
    const priority = {
      '説明会': 1,
      'ES締切': 2,
      'WEBテスト': 3,
      'GD': 4,
      '1次面接': 5,
      '2次面接': 6,
      '3次面接': 7,
      '4次面接': 8,
      '最終面接': 9,
      'その他': 99,
    };

    return priority[label] ?? 50;
  }


  static DateTime _dateOnly(DateTime d) {
    return DateTime(d.year, d.month, d.day);
  }

  static DateTime _nextMonday(DateTime from) {
    var d = _dateOnly(from);

    while (d.weekday != DateTime.monday) {
      d = d.add(const Duration(days: 1));
    }

    return d;
  }
}