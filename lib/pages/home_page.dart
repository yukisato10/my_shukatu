// home_page.dart
//
// 修正点
// ・平日に祝日がある場合、その日の日付数字を赤に変更
// ・曜日行だけ薄い青
// ・「○年○月」のヘッダー行は背景色なし
// ・左上の設定ボタンは BottomSheet を表示
// ・プライバシーポリシーは BottomSheet で表示
//
// 依存：HiveService / Company / ScheduleItem / ScheduleType / jpholiday

import '../widgets/ad_scaffold.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:holiday_jp/holiday_jp.dart' as holiday_jp;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';

import '../db/hive_service.dart';
import '../models/company.dart';

// =====================
// Calendar models
// =====================
enum EventType { deadline, interview, test, gd, event, other }

class CalendarEvent {
  final EventType type;
  final int companyKey;
  final Company company;
  final DateTime dateTime;
  final ScheduleType scheduleType;
  final String? note;

  CalendarEvent({
    required this.type,
    required this.companyKey,
    required this.company,
    required this.dateTime,
    required this.scheduleType,
    this.note,
  });
}

// =====================
// HomePage
// =====================
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  OverlayEntry? _daySheetOverlay;
  final ValueNotifier<int> _sheetRefresh = ValueNotifier<int>(0);

  static const _kDeadlineColorKey = 'deadlineColor';
  static const _kInterviewColorKey = 'interviewColor';
  static const _kTestColorKey = 'testColor';
  static const _kGdColorKey = 'gdColor';
  static const _kEventColorKey = 'eventColor';
  static const _kOtherColorKey = 'otherColor';

  static const _kCompanyFilterKeys = 'calendarCompanyFilterKeys';
  static const _kScheduleTypeFilterKeys = 'calendarScheduleTypeFilterKeys';

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  Map<DateTime, List<CalendarEvent>> _eventMap = {};

  int _deadlineColorValue = Colors.red.value;
  int _interviewColorValue = Colors.blue.value;
  int _testColorValue = Colors.teal.value;
  int _gdColorValue = Colors.deepOrange.value;
  int _eventColorValue = Colors.green.value;
  int _otherColorValue = Colors.grey.value;

  Color get _deadlineColor => Color(_deadlineColorValue);
  Color get _interviewColor => Color(_interviewColorValue);
  Color get _testColor => Color(_testColorValue);
  Color get _gdColor => Color(_gdColorValue);
  Color get _eventColor => Color(_eventColorValue);
  Color get _otherColor => Color(_otherColorValue);

  Set<int> _companyFilter = <int>{};
  Set<ScheduleType> _scheduleTypeFilter = <ScheduleType>{};

  static const Map<ScheduleType, String> _scheduleTypeLabel = {
    ScheduleType.event: '説明会',
    ScheduleType.esDeadline: 'ES締切',
    ScheduleType.webTest: 'WEBテスト',
    ScheduleType.gd: 'GD',
    ScheduleType.interview1: '1次面接',
    ScheduleType.interview2: '2次面接',
    ScheduleType.interview3: '3次面接',
    ScheduleType.interview4: '4次面接',
    ScheduleType.finalInterview: '最終面接',
    ScheduleType.other: 'その他',
  };

  @override
  void initState() {
    super.initState();
    _selectedDay = _normalize(DateTime.now());
    _loadPrefs();
  }

  @override
  void dispose() {
    _removeDaySheetOverlay();
    _sheetRefresh.dispose();
    super.dispose();
  }

  DateTime _normalize(DateTime d) => DateTime(d.year, d.month, d.day);

  bool _isSunday(DateTime day) => day.weekday == DateTime.sunday;
  bool _isSaturday(DateTime day) => day.weekday == DateTime.saturday;

  bool _isHoliday(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    return holiday_jp.getHoliday(d) != null;
  }

  Color _dayNumberColor(BuildContext context, DateTime day, {bool outside = false}) {
    Color color;
    if (_isSunday(day) || _isHoliday(day)) {
      color = Colors.red;
    } else if (_isSaturday(day)) {
      color = Colors.blue;
    } else {
      color = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black87;
    }
    return outside ? color.withOpacity(0.45) : color;
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    setState(() {
      _deadlineColorValue =
          prefs.getInt(_kDeadlineColorKey) ?? Colors.red.value;
      _interviewColorValue =
          prefs.getInt(_kInterviewColorKey) ?? Colors.blue.value;
      _testColorValue = prefs.getInt(_kTestColorKey) ?? Colors.teal.value;
      _gdColorValue = prefs.getInt(_kGdColorKey) ?? Colors.deepOrange.value;
      _eventColorValue = prefs.getInt(_kEventColorKey) ?? Colors.green.value;
      _otherColorValue = prefs.getInt(_kOtherColorKey) ?? Colors.grey.value;

      final cCsv = prefs.getString(_kCompanyFilterKeys) ?? '';
      _companyFilter = cCsv.trim().isEmpty
          ? <int>{}
          : cCsv
          .split(',')
          .map((e) => int.tryParse(e.trim()))
          .whereType<int>()
          .toSet();

      final sCsv = prefs.getString(_kScheduleTypeFilterKeys) ?? '';
      _scheduleTypeFilter = sCsv.trim().isEmpty
          ? <ScheduleType>{}
          : sCsv
          .split(',')
          .map((e) => int.tryParse(e.trim()))
          .whereType<int>()
          .where((i) => i >= 0 && i < ScheduleType.values.length)
          .map((i) => ScheduleType.values[i])
          .toSet();
    });
  }

  Future<void> _saveColor(String key, int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(key, value);
  }

  Future<void> _saveFilters() async {
    final prefs = await SharedPreferences.getInstance();
    final cCsv = _companyFilter.isEmpty ? '' : _companyFilter.join(',');
    final sCsv = _scheduleTypeFilter.isEmpty
        ? ''
        : _scheduleTypeFilter.map((t) => t.index).join(',');
    await prefs.setString(_kCompanyFilterKeys, cCsv);
    await prefs.setString(_kScheduleTypeFilterKeys, sCsv);
  }

  EventType _eventTypeFromSchedule(ScheduleType t) {
    switch (t) {
      case ScheduleType.esDeadline:
        return EventType.deadline;
      case ScheduleType.interview1:
      case ScheduleType.interview2:
      case ScheduleType.interview3:
      case ScheduleType.interview4:
      case ScheduleType.finalInterview:
        return EventType.interview;
      case ScheduleType.webTest:
        return EventType.test;
      case ScheduleType.gd:
        return EventType.gd;
      case ScheduleType.event:
        return EventType.event;
      case ScheduleType.other:
        return EventType.other;
    }
  }

  Color _colorForEventType(EventType t) {
    switch (t) {
      case EventType.deadline:
        return _deadlineColor;
      case EventType.interview:
        return _interviewColor;
      case EventType.test:
        return _testColor;
      case EventType.gd:
        return _gdColor;
      case EventType.event:
        return _eventColor;
      case EventType.other:
        return _otherColor;
    }
  }

  IconData _iconForEventType(EventType t) {
    switch (t) {
      case EventType.deadline:
        return Icons.flag;
      case EventType.interview:
        return Icons.record_voice_over;
      case EventType.test:
        return Icons.edit;
      case EventType.gd:
        return Icons.groups;
      case EventType.event:
        return Icons.event_available;
      case EventType.other:
        return Icons.more_horiz;
    }
  }

  String _shortType(ScheduleType t) {
    switch (t) {
      case ScheduleType.esDeadline:
        return 'ES';
      case ScheduleType.webTest:
        return 'テスト';
      case ScheduleType.gd:
        return 'GD';
      case ScheduleType.event:
        return '説明会';
      case ScheduleType.interview1:
      case ScheduleType.interview2:
      case ScheduleType.interview3:
      case ScheduleType.interview4:
      case ScheduleType.finalInterview:
        return '面接';
      case ScheduleType.other:
        return '他';
    }
  }

  void _rebuildEventMapFromCompanies(Box<Company> box) {
    final map = <DateTime, List<CalendarEvent>>{};
    final entries = box.toMap().entries.toList();

    for (final e in entries) {
      final key = e.key;
      if (key is! int) continue;
      final c = e.value;

      if (_companyFilter.isNotEmpty && !_companyFilter.contains(key)) continue;

      for (final s in c.schedules) {
        if (_scheduleTypeFilter.isNotEmpty &&
            !_scheduleTypeFilter.contains(s.type)) {
          continue;
        }

        final dt = s.dateTime.toLocal();
        final dayKey = _normalize(dt);

        (map[dayKey] ??= []).add(
          CalendarEvent(
            type: _eventTypeFromSchedule(s.type),
            companyKey: key,
            company: c,
            dateTime: dt,
            scheduleType: s.type,
            note: s.note,
          ),
        );
      }
    }

    for (final k in map.keys) {
      map[k]!.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    }

    _eventMap = map;
  }

  List<CalendarEvent> _eventsForDay(DateTime day) =>
      _eventMap[_normalize(day)] ?? const [];

  String _fmt(DateTime dt) => dt.toLocal().toString().substring(0, 16);

  Future<void> _showPrivacyPolicy() async {
    const policyText = '''
プライバシーポリシー

本アプリは、ユーザーの利便性向上および広告配信のために、必要な範囲で情報を取り扱います。

1. 取得する情報
本アプリでは、以下の情報を取得する場合があります。
・広告配信に必要な情報
・端末情報、広告ID等
・アプリの利用状況に関する情報

2. 利用目的
取得した情報は、以下の目的で利用します。
・広告の表示および最適化
・アプリの改善
・不具合の調査および品質向上

3. 第三者サービスについて
本アプリでは、広告配信のために Google AdMob などの第三者サービスを利用する場合があります。
これらの第三者サービスは、利用者情報を取得し、それぞれのプライバシーポリシーに基づいて利用することがあります。

4. 情報の管理
本アプリは、取得した情報を適切に管理し、不正アクセス、漏えい、改ざん等の防止に努めます。

5. プライバシーポリシーの変更
本ポリシーは、必要に応じて変更することがあります。変更後の内容は、本アプリ内または公開ページにて周知します。

6. お問い合わせ
本ポリシーに関するお問い合わせは、開発者連絡先までお願いいたします。
''';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _BottomSheetScaffold(
          child: SafeArea(
            child: DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.92,
              minChildSize: 0.60,
              maxChildSize: 0.98,
              builder: (ctx, controller) {
                return Material(
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: SizedBox(
                          height: 40,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('閉じる'),
                                ),
                              ),
                              Text(
                                'プライバシーポリシー',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: ListView(
                          controller: controller,
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          children: const [
                            Text(
                              policyText,
                              style: TextStyle(fontSize: 13, height: 1.6),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _openSupportSheet() async {
    final cs = Theme.of(context).colorScheme;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'サポート',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  leading: Icon(Icons.privacy_tip_outlined, color: cs.primary),
                  title: const Text(
                    'プライバシーポリシー',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _showPrivacyPolicy();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _dayCell(
      BuildContext context,
      DateTime day, {
        required bool isSelected,
        required bool isToday,
        bool outside = false,
      }) {
    final borderColor = Theme.of(context).dividerColor.withOpacity(0.40);

    final bg = isSelected
        ? Theme.of(context).colorScheme.primary.withOpacity(0.20)
        : isToday
        ? Theme.of(context).colorScheme.primary.withOpacity(0.10)
        : Colors.transparent;

    final dayTextColor = _dayNumberColor(context, day, outside: outside);

    final events = _eventsForDay(day);
    final shown = events;

    Widget band(CalendarEvent e) {
      final c = _colorForEventType(e.type);

      const double bandHeight = 16;
      const double fontSize = 12;
      const double radius = 0;
      const double paddingH = 0;
      const double marginTop = 2;

      final bandBg = outside ? c.withOpacity(0.22) : c.withOpacity(0.85);
      final bandFg = Colors.white.withOpacity(outside ? 0.55 : 1.0);

      final text = '${e.company.name} / ${_shortType(e.scheduleType)}';

      return Container(
        height: bandHeight,
        margin: const EdgeInsets.only(top: marginTop),
        padding: const EdgeInsets.symmetric(horizontal: paddingH),
        decoration: BoxDecoration(
          color: bandBg,
          borderRadius: BorderRadius.circular(radius),
        ),
        alignment: Alignment.centerLeft,
        clipBehavior: Clip.hardEdge,
        child: Text(
          text,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.clip,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            color: bandFg,
            height: 1,
          ),
        ),
      );
    }

    return SizedBox.expand(
      child: Container(
        margin: EdgeInsets.zero,
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(width: 0.5, color: borderColor),
          borderRadius: BorderRadius.zero,
        ),
        padding: const EdgeInsets.fromLTRB(2, 4, 2, 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${day.day}',
              style: TextStyle(
                color: dayTextColor,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 0),
            Expanded(
              child: ScrollConfiguration(
                behavior: const _NoGlowScrollBehavior(),
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  primary: false,
                  physics: const ClampingScrollPhysics(),
                  itemCount: shown.length,
                  itemBuilder: (_, i) => band(shown[i]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _removeDaySheetOverlay() {
    _daySheetOverlay?.remove();
    _daySheetOverlay = null;
  }

  void _openDaySheetOverlay(Box<Company> box, DateTime day) {
    final selected = _normalize(day);

    _removeDaySheetOverlay();

    final overlay = Overlay.of(context);
    if (overlay == null) return;

    _daySheetOverlay = OverlayEntry(
      builder: (ctx) {
        final mq = MediaQuery.of(context);
        final navH = kBottomNavigationBarHeight + mq.padding.bottom + 45;

        return Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              bottom: navH,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _removeDaySheetOverlay,
                child: Container(color: Colors.black.withOpacity(0.0)),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: navH,
              child: Material(
                elevation: 1,
                borderRadius:
                const BorderRadius.vertical(top: Radius.circular(18)),
                clipBehavior: Clip.antiAlias,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: mq.size.height * 0.34),
                  child: _DaySheet(
                    date: selected,
                    refreshListenable: _sheetRefresh,
                    eventsProvider: () => List<CalendarEvent>.from(
                      _eventsForDay(selected),
                    )..sort((a, b) => a.dateTime.compareTo(b.dateTime)),
                    scheduleTypeLabel: _scheduleTypeLabel,
                    colorFor: _colorForEventType,
                    iconFor: _iconForEventType,
                    fmt: _fmt,
                    onAdd: () async {
                      _removeDaySheetOverlay();
                      final added = await _openAddScheduleSheet(box, selected);
                      if (!mounted) return;
                      if (added) {
                        _sheetRefresh.value++;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('予定を追加しました')),
                        );
                      }
                    },
                    onTapEvent: (e) async {
                      _removeDaySheetOverlay();
                      await Future<void>.delayed(
                        const Duration(milliseconds: 1),
                      );
                      if (!mounted) return;
                      await _openEventDetailSheet(box, e);
                    },
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    overlay.insert(_daySheetOverlay!);
  }

  bool _sameSchedule(ScheduleItem s, CalendarEvent e) {
    final sameType = s.type == e.scheduleType;
    final sameDt =
        s.dateTime.millisecondsSinceEpoch == e.dateTime.millisecondsSinceEpoch;
    final sn = (s.note ?? '').trim();
    final en = (e.note ?? '').trim();
    return sameType && sameDt && sn == en;
  }

  Future<void> _deleteSchedule(Box<Company> box, CalendarEvent e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('確認'),
        content: const Text('この予定を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final company = box.get(e.companyKey);
    if (company == null) return;

    final list = List<ScheduleItem>.from(company.schedules);
    list.removeWhere((s) => _sameSchedule(s, e));
    company.schedules = list;
    company.updatedAt = DateTime.now();
    await company.save();

    if (!mounted) return;
    _sheetRefresh.value++;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('削除しました')),
    );
  }

  Future<ScheduleType?> _pickScheduleTypeSheet(ScheduleType current) async {
    return showModalBottomSheet<ScheduleType>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        ScheduleType temp = current;
        return StatefulBuilder(
          builder: (ctx, setS) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          '種類を選択',
                          style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, null),
                          child: const Text('キャンセル'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx, temp),
                          child: const Text('決定'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(ctx).size.height * 0.55,
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: ScheduleType.values.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final t = ScheduleType.values[i];
                          final selected = t == temp;
                          return ListTile(
                            dense: true,
                            title: Text(
                              _scheduleTypeLabel[t] ?? t.name,
                              style: const TextStyle(fontSize: 13),
                            ),
                            trailing:
                            selected ? const Icon(Icons.check) : null,
                            onTap: () => setS(() => temp = t),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<int?> _pickCompanySheet({
    required List<MapEntry<int, Company>> companies,
    required int current,
  }) async {
    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        int temp = current;
        return StatefulBuilder(
          builder: (ctx, setS) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          '企業を選択',
                          style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, null),
                          child: const Text('キャンセル'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx, temp),
                          child: const Text('決定'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(ctx).size.height * 0.60,
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: companies.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final k = companies[i].key;
                          final c = companies[i].value;
                          final selected = k == temp;
                          return ListTile(
                            dense: true,
                            title: Text(
                              c.name,
                              style: const TextStyle(fontSize: 13),
                            ),
                            trailing:
                            selected ? const Icon(Icons.check) : null,
                            onTap: () => setS(() => temp = k),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  DateTime _snapToMinuteInterval(DateTime dt, int minuteInterval) {
    final m = dt.minute;
    final snapped = (m ~/ minuteInterval) * minuteInterval;
    return DateTime(dt.year, dt.month, dt.day, dt.hour, snapped);
  }

  Future<DateTime?> _pickDateTimeSheet(DateTime? current) async {
    final now = DateTime.now();
    const interval = 5;
    DateTime temp = _snapToMinuteInterval(current ?? now, interval);

    return showModalBottomSheet<DateTime?>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      '日時を選択',
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, null),
                      child: const Text('キャンセル'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, temp),
                      child: const Text('決定'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 220,
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.dateAndTime,
                    initialDateTime: temp,
                    minimumDate: DateTime(now.year - 1),
                    maximumDate: DateTime(now.year + 5),
                    use24hFormat: true,
                    minuteInterval: interval,
                    onDateTimeChanged: (v) =>
                    temp = _snapToMinuteInterval(v, interval),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<bool> _openAddScheduleSheet(Box<Company> box, DateTime day) async {
    final companies = box
        .toMap()
        .entries
        .where((e) => e.key is int)
        .map((e) => MapEntry(e.key as int, e.value))
        .toList()
      ..sort((a, b) => a.value.name.compareTo(b.value.name));

    if (companies.isEmpty) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('先に企業を登録してください。')),
      );
      return false;
    }

    final res = await _showScheduleEditorSheet(
      title: '予定の追加',
      initialCompanyKey: companies.first.key,
      initialType: ScheduleType.event,
      initialDateTime: DateTime(day.year, day.month, day.day, 9, 0),
      initialNote: '',
      companies: companies,
      mode: _ScheduleEditorMode.add,
    );

    if (res == null) return false;

    final company = box.get(res.companyKey);
    if (company == null) return false;

    final item = ScheduleItem(
      type: res.type,
      dateTime: res.dateTime,
      note: res.note.trim().isEmpty ? null : res.note.trim(),
    );

    final list = List<ScheduleItem>.from(company.schedules);
    list.add(item);
    list.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    company.schedules = list;
    company.updatedAt = DateTime.now();
    await company.save();
    return true;
  }

  Future<void> _editScheduleSheet(Box<Company> box, CalendarEvent e) async {
    final companies = box
        .toMap()
        .entries
        .where((x) => x.key is int)
        .map((x) => MapEntry(x.key as int, x.value))
        .toList()
      ..sort((a, b) => a.value.name.compareTo(b.value.name));

    final company = box.get(e.companyKey);
    if (company == null) return;

    final res = await _showScheduleEditorSheet(
      title: '予定の編集',
      initialCompanyKey: e.companyKey,
      initialType: e.scheduleType,
      initialDateTime: e.dateTime,
      initialNote: e.note ?? '',
      companies: companies,
      mode: _ScheduleEditorMode.edit,
    );

    if (res == null) return;

    final list = List<ScheduleItem>.from(company.schedules);
    final idx = list.indexWhere((s) => _sameSchedule(s, e));
    if (idx < 0) return;

    list[idx] = ScheduleItem(
      type: res.type,
      dateTime: res.dateTime,
      note: res.note.trim().isEmpty ? null : res.note.trim(),
    );
    list.sort((a, b) => a.dateTime.compareTo(b.dateTime));

    company.schedules = list;
    company.updatedAt = DateTime.now();
    await company.save();

    if (!mounted) return;
    _sheetRefresh.value++;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('更新しました')),
    );
  }

  Future<void> _openEventDetailSheet(Box<Company> box, CalendarEvent e) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _BottomSheetScaffold(
          child: _EventDetailSheet(
            event: e,
            scheduleTypeLabel: _scheduleTypeLabel,
            iconFor: _iconForEventType,
            colorFor: _colorForEventType,
            fmt: _fmt,
            onEdit: () async {
              Navigator.pop(ctx);
              await _editScheduleSheet(box, e);
            },
            onDelete: () async {
              Navigator.pop(ctx);
              await _deleteSchedule(box, e);
            },
          ),
        );
      },
    );
  }

  Future<_ScheduleEditorResult?> _showScheduleEditorSheet({
    required String title,
    required int initialCompanyKey,
    required ScheduleType initialType,
    required DateTime initialDateTime,
    required String initialNote,
    required List<MapEntry<int, Company>> companies,
    required _ScheduleEditorMode mode,
  }) async {
    return showModalBottomSheet<_ScheduleEditorResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _BottomSheetScaffold(
          child: _ScheduleEditorSheet(
            title: title,
            companies: companies,
            initialCompanyKey: initialCompanyKey,
            initialType: initialType,
            initialDateTime: initialDateTime,
            initialNote: initialNote,
            scheduleTypeLabel: _scheduleTypeLabel,
            pickCompany: (current) async =>
            (await _pickCompanySheet(
              companies: companies,
              current: current,
            )) ??
                current,
            pickType: (current) async =>
            (await _pickScheduleTypeSheet(current)) ?? current,
            pickDateTime: _pickDateTimeSheet,
            mode: mode,
          ),
        );
      },
    );
  }

  Future<void> _pickColor({
    required String title,
    required int current,
    required ValueChanged<int> onSelected,
  }) async {
    final picked = await showDialog<int>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _ColorPickerDialog(
        title: title,
        current: Color(current),
      ),
    );

    if (picked == null) return;
    onSelected(picked);
  }

  Future<void> _openDisplaySettings(Box<Company> box) async {
    Set<int> tempCompany = Set<int>.from(_companyFilter);
    Set<ScheduleType> tempFlow = Set<ScheduleType>.from(_scheduleTypeFilter);

    int tempDeadline = _deadlineColorValue;
    int tempInterview = _interviewColorValue;
    int tempTest = _testColorValue;
    int tempGd = _gdColorValue;
    int tempEvent = _eventColorValue;
    int tempOther = _otherColorValue;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setS) {
            Future<void> pickCompanies() async {
              final res = await showDialog<Set<int>>(
                context: ctx,
                barrierDismissible: false,
                builder: (_) =>
                    _MultiCompanyPickerDialog(box: box, initial: tempCompany),
              );
              if (res == null) return;
              setS(() => tempCompany = res);
            }

            Future<void> pickFlows() async {
              final res = await showDialog<Set<ScheduleType>>(
                context: ctx,
                barrierDismissible: false,
                builder: (_) => _MultiScheduleTypePickerDialog(
                  initial: tempFlow,
                  label: _scheduleTypeLabel,
                ),
              );
              if (res == null) return;
              setS(() => tempFlow = res);
            }

            Future<void> pickAndApplyColor({
              required String title,
              required int current,
              required void Function(int) setTemp,
              required void Function(int) setParent,
              required String prefKey,
            }) async {
              await _pickColor(
                title: title,
                current: current,
                onSelected: (val) async {
                  setS(() => setTemp(val));
                  setState(() => setParent(val));
                  await _saveColor(prefKey, val);
                  _sheetRefresh.value++;
                },
              );
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '表示設定',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'マーカー色',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _ColorChip(
                            label: '締切',
                            color: Color(tempDeadline),
                            onTap: () => pickAndApplyColor(
                              title: '締切マーカーの色',
                              current: tempDeadline,
                              setTemp: (v) => tempDeadline = v,
                              setParent: (v) => _deadlineColorValue = v,
                              prefKey: _kDeadlineColorKey,
                            ),
                          ),
                          _ColorChip(
                            label: '面接',
                            color: Color(tempInterview),
                            onTap: () => pickAndApplyColor(
                              title: '面接マーカーの色',
                              current: tempInterview,
                              setTemp: (v) => tempInterview = v,
                              setParent: (v) => _interviewColorValue = v,
                              prefKey: _kInterviewColorKey,
                            ),
                          ),
                          _ColorChip(
                            label: 'WEBテスト',
                            color: Color(tempTest),
                            onTap: () => pickAndApplyColor(
                              title: 'WEBテストマーカーの色',
                              current: tempTest,
                              setTemp: (v) => tempTest = v,
                              setParent: (v) => _testColorValue = v,
                              prefKey: _kTestColorKey,
                            ),
                          ),
                          _ColorChip(
                            label: 'GD',
                            color: Color(tempGd),
                            onTap: () => pickAndApplyColor(
                              title: 'GDマーカーの色',
                              current: tempGd,
                              setTemp: (v) => tempGd = v,
                              setParent: (v) => _gdColorValue = v,
                              prefKey: _kGdColorKey,
                            ),
                          ),
                          _ColorChip(
                            label: '説明会',
                            color: Color(tempEvent),
                            onTap: () => pickAndApplyColor(
                              title: '説明会マーカーの色',
                              current: tempEvent,
                              setTemp: (v) => tempEvent = v,
                              setParent: (v) => _eventColorValue = v,
                              prefKey: _kEventColorKey,
                            ),
                          ),
                          _ColorChip(
                            label: 'その他',
                            color: Color(tempOther),
                            onTap: () => pickAndApplyColor(
                              title: 'その他マーカーの色',
                              current: tempOther,
                              setTemp: (v) => tempOther = v,
                              setParent: (v) => _otherColorValue = v,
                              prefKey: _kOtherColorKey,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'カレンダー絞り込み',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('企業で絞り込み'),
                        subtitle: Text(
                          tempCompany.isEmpty
                              ? '全企業'
                              : '${tempCompany.length}社を選択中',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: pickCompanies,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('選考フローで絞り込み'),
                        subtitle: Text(
                          tempFlow.isEmpty
                              ? '全フロー'
                              : '${tempFlow.length}種を選択中',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: pickFlows,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () {
                              setS(() {
                                tempCompany.clear();
                                tempFlow.clear();
                              });
                            },
                            child: const Text('リセット'),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('キャンセル'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: () async {
                              setState(() {
                                _companyFilter = tempCompany;
                                _scheduleTypeFilter = tempFlow;
                              });
                              await _saveFilters();
                              _sheetRefresh.value++;
                              if (ctx.mounted) Navigator.pop(ctx);
                            },
                            child: const Text('適用'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _dowLabel(int weekday) {
    switch (weekday) {
      case DateTime.sunday:
        return '日';
      case DateTime.monday:
        return '月';
      case DateTime.tuesday:
        return '火';
      case DateTime.wednesday:
        return '水';
      case DateTime.thursday:
        return '木';
      case DateTime.friday:
        return '金';
      case DateTime.saturday:
        return '土';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final box = HiveService.companyBox();
    final selected = _selectedDay ?? _normalize(DateTime.now());

    return AdScaffold(
      appBar: AppBar(
        centerTitle: true,
        leading: IconButton(
          tooltip: '設定',
          icon: const Icon(Icons.settings),
          onPressed: _openSupportSheet,
        ),
        title: const Text(
          'ホーム',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            tooltip: '表示設定',
            icon: const Icon(Icons.tune),
            onPressed: () => _openDisplaySettings(box),
          ),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: box.listenable(),
        builder: (context, Box<Company> b, _) {
          _rebuildEventMapFromCompanies(b);

          return TableCalendar<CalendarEvent>(
            locale: 'ja_JP',
            startingDayOfWeek: StartingDayOfWeek.sunday,
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2035, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(day, selected),
            eventLoader: _eventsForDay,
            onDaySelected: (sel, focused) {
              setState(() {
                _selectedDay = _normalize(sel);
                _focusedDay = focused;
              });
              _openDaySheetOverlay(b, sel);
            },
            onPageChanged: (focused) => _focusedDay = focused,
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              headerPadding: EdgeInsets.symmetric(vertical: 0), // ここで縦幅を縮める
              titleTextStyle: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
              ),
              leftChevronIcon: Icon(Icons.chevron_left, color: Colors.black87, size: 20),
              rightChevronIcon: Icon(Icons.chevron_right, color: Colors.black87, size: 20),
              decoration: BoxDecoration(
                color: Colors.transparent,
              ),
            ),
            daysOfWeekHeight: 30,

            rowHeight: 94,
            calendarStyle: const CalendarStyle(
              outsideDaysVisible: true,
              cellMargin: EdgeInsets.zero,
            ),
            daysOfWeekStyle: DaysOfWeekStyle(
              decoration: BoxDecoration(
                color: Colors.lightBlue.shade100,
              ),
              weekdayStyle: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
              weekendStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
              dowTextFormatter: (date, locale) => _dowLabel(date.weekday),
            ),
            calendarBuilders: CalendarBuilders<CalendarEvent>(
              dowBuilder: (context, day) {
                final isSun = day.weekday == DateTime.sunday;
                final isSat = day.weekday == DateTime.saturday;

                Color textColor = Colors.black87;
                if (isSun) textColor = Colors.red;
                if (isSat) textColor = Colors.blue;

                return Container(
                  color: Colors.lightBlue.shade100,
                  alignment: Alignment.center,
                  child: Text(
                    _dowLabel(day.weekday),
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                );
              },
              defaultBuilder: (context, day, focusedDay) =>
                  _dayCell(context, day, isSelected: false, isToday: false),
              todayBuilder: (context, day, focusedDay) =>
                  _dayCell(context, day, isSelected: false, isToday: true),
              selectedBuilder: (context, day, focusedDay) =>
                  _dayCell(context, day, isSelected: true, isToday: false),
              outsideBuilder: (context, day, focusedDay) => _dayCell(
                context,
                day,
                isSelected: false,
                isToday: false,
                outside: true,
              ),
              markerBuilder: (context, day, events) =>
              const SizedBox.shrink(),
            ),
          );
        },
      ),
    );
  }
}

class _NoGlowScrollBehavior extends ScrollBehavior {
  const _NoGlowScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
      BuildContext context,
      Widget child,
      ScrollableDetails details,
      ) {
    return child;
  }
}

// =====================
// BottomSheet container
// =====================
class _BottomSheetScaffold extends StatelessWidget {
  final Widget child;
  const _BottomSheetScaffold({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      child: Material(
        elevation: 2,
        child: child,
      ),
    );
  }
}

// =====================
// Day sheet widget
// =====================
class _DaySheet extends StatelessWidget {
  final DateTime date;
  final ValueListenable<int> refreshListenable;

  final List<CalendarEvent> Function() eventsProvider;
  final Map<ScheduleType, String> scheduleTypeLabel;
  final Color Function(EventType) colorFor;
  final IconData Function(EventType) iconFor;
  final String Function(DateTime) fmt;
  final VoidCallback onAdd;
  final void Function(CalendarEvent) onTapEvent;

  const _DaySheet({
    required this.date,
    required this.refreshListenable,
    required this.eventsProvider,
    required this.scheduleTypeLabel,
    required this.colorFor,
    required this.iconFor,
    required this.fmt,
    required this.onAdd,
    required this.onTapEvent,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${date.month}月${date.day}日の予定',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add),
                  label: const Text('追加'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            Expanded(
              child: ValueListenableBuilder<int>(
                valueListenable: refreshListenable,
                builder: (_, __, ___) {
                  final events = eventsProvider();
                  if (events.isEmpty) {
                    return const Center(child: Text('この日の予定はありません。'));
                  }

                  return ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: events.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final e = events[i];
                      final kind =
                          scheduleTypeLabel[e.scheduleType] ?? e.scheduleType.name;
                      final timeText = fmt(e.dateTime);

                      return ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        minLeadingWidth: 24,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 0,
                          vertical: 2,
                        ),
                        leading: Icon(
                          iconFor(e.type),
                          color: colorFor(e.type),
                          size: 18,
                        ),
                        title: Text(
                          e.company.name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          '$kind / $timeText',
                          style: const TextStyle(fontSize: 11),
                        ),
                        onTap: () => onTapEvent(e),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================
// 詳細BottomSheet
// =====================
class _EventDetailSheet extends StatelessWidget {
  final CalendarEvent event;
  final Map<ScheduleType, String> scheduleTypeLabel;
  final IconData Function(EventType) iconFor;
  final Color Function(EventType) colorFor;
  final String Function(DateTime) fmt;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _EventDetailSheet({
    required this.event,
    required this.scheduleTypeLabel,
    required this.iconFor,
    required this.colorFor,
    required this.fmt,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final kind = scheduleTypeLabel[event.scheduleType] ?? event.scheduleType.name;
    final timeText = fmt(event.dateTime);
    final note = (event.note ?? '').trim();

    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.92,
        minChildSize: 0.55,
        maxChildSize: 0.98,
        builder: (ctx, controller) {
          return Material(
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: SizedBox(
                    height: 40,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('閉じる'),
                          ),
                        ),
                        Text(
                          '予定の詳細',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      Text(
                        event.company.name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(iconFor(event.type), color: colorFor(event.type)),
                          const SizedBox(width: 8),
                          Text(kind, style: Theme.of(context).textTheme.titleSmall),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text('日時：$timeText'),
                      const SizedBox(height: 16),
                      Text('メモ', style: Theme.of(context).textTheme.labelLarge),
                      const SizedBox(height: 6),
                      Text(note.isEmpty ? '（メモなし）' : note),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit),
                        label: const Text('編集'),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: onDelete,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('削除'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// =====================
// 追加/編集BottomSheet
// =====================
enum _ScheduleEditorMode { add, edit }

class _ScheduleEditorResult {
  final int companyKey;
  final ScheduleType type;
  final DateTime dateTime;
  final String note;

  _ScheduleEditorResult({
    required this.companyKey,
    required this.type,
    required this.dateTime,
    required this.note,
  });
}

class _ScheduleEditorSheet extends StatefulWidget {
  final String title;
  final List<MapEntry<int, Company>> companies;

  final int initialCompanyKey;
  final ScheduleType initialType;
  final DateTime initialDateTime;
  final String initialNote;

  final Map<ScheduleType, String> scheduleTypeLabel;

  final Future<int> Function(int current) pickCompany;
  final Future<ScheduleType> Function(ScheduleType current) pickType;
  final Future<DateTime?> Function(DateTime? current) pickDateTime;

  final _ScheduleEditorMode mode;

  const _ScheduleEditorSheet({
    required this.title,
    required this.companies,
    required this.initialCompanyKey,
    required this.initialType,
    required this.initialDateTime,
    required this.initialNote,
    required this.scheduleTypeLabel,
    required this.pickCompany,
    required this.pickType,
    required this.pickDateTime,
    required this.mode,
  });

  @override
  State<_ScheduleEditorSheet> createState() => _ScheduleEditorSheetState();
}

class _ScheduleEditorSheetState extends State<_ScheduleEditorSheet> {
  late int _companyKey;
  late ScheduleType _type;
  late DateTime _dt;
  late String _note;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _companyKey = widget.initialCompanyKey;
    _type = widget.initialType;
    _dt = widget.initialDateTime;
    _note = widget.initialNote;
  }

  String _fmt(DateTime dt) => dt.toLocal().toString().substring(0, 16);

  String _companyName(int key) {
    final hit = widget.companies.where((e) => e.key == key).toList();
    if (hit.isEmpty) return '未選択';
    return hit.first.value.name;
  }

  Future<void> _openMemoEditor() async {
    final res = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _BottomSheetScaffold(
          child: _MemoEditorSheet(
            initial: _note,
            title: 'メモ',
          ),
        );
      },
    );

    if (res == null) return;
    setState(() => _note = res);
  }

  @override
  Widget build(BuildContext context) {
    final typeText = widget.scheduleTypeLabel[_type] ?? _type.name;

    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.92,
        minChildSize: 0.60,
        maxChildSize: 0.98,
        builder: (ctx, controller) {
          return Material(
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: _saving ? null : () => Navigator.pop(context),
                        child: const Text('キャンセル'),
                      ),
                      const Spacer(),
                      Text(
                        widget.title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: _saving
                            ? null
                            : () {
                          setState(() => _saving = true);
                          Navigator.pop(
                            context,
                            _ScheduleEditorResult(
                              companyKey: _companyKey,
                              type: _type,
                              dateTime: _dt,
                              note: _note,
                            ),
                          );
                        },
                        child: const Text('保存'),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    controller: controller,
                    padding: EdgeInsets.only(
                      left: 12,
                      right: 12,
                      top: 12,
                      bottom: 12 + MediaQuery.of(context).viewInsets.bottom,
                    ),
                    children: [
                      _SheetRow(
                        title: '企業',
                        value: _companyName(_companyKey),
                        onTap: _saving
                            ? null
                            : () async {
                          final picked = await widget.pickCompany(_companyKey);
                          if (!mounted) return;
                          setState(() => _companyKey = picked);
                        },
                      ),
                      const SizedBox(height: 10),
                      _SheetRow(
                        title: '種類',
                        value: typeText,
                        onTap: _saving
                            ? null
                            : () async {
                          final picked = await widget.pickType(_type);
                          if (!mounted) return;
                          setState(() => _type = picked);
                        },
                      ),
                      const SizedBox(height: 10),
                      _SheetRow(
                        title: '日時',
                        value: _fmt(_dt),
                        trailing: const Icon(Icons.access_time, size: 18),
                        onTap: _saving
                            ? null
                            : () async {
                          final picked = await widget.pickDateTime(_dt);
                          if (picked == null) return;
                          if (!mounted) return;
                          setState(() => _dt = picked);
                        },
                      ),
                      const SizedBox(height: 10),
                      _SheetRow(
                        title: 'メモ',
                        value: (_note.trim().isEmpty) ? '（なし）' : '編集',
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _saving ? null : _openMemoEditor,
                      ),
                      if (_saving) ...[
                        const SizedBox(height: 16),
                        const LinearProgressIndicator(),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SheetRow extends StatelessWidget {
  final String title;
  final String value;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SheetRow({
    required this.title,
    required this.value,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final box = BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: Theme.of(context).dividerColor.withOpacity(0.4),
      ),
    );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: box,
        child: Row(
          children: [
            SizedBox(
              width: 72,
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.color
                      ?.withOpacity(0.85),
                ),
              ),
            ),
            const SizedBox(width: 10),
            trailing ?? const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

// =====================
// メモ編集BottomSheet
// =====================
class _MemoEditorSheet extends StatefulWidget {
  final String initial;
  final String title;

  const _MemoEditorSheet({
    required this.initial,
    required this.title,
  });

  @override
  State<_MemoEditorSheet> createState() => _MemoEditorSheetState();
}

class _MemoEditorSheetState extends State<_MemoEditorSheet> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.92,
        minChildSize: 0.60,
        maxChildSize: 0.98,
        builder: (ctx, controller) {
          return Material(
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      const SizedBox(width: 80),
                      const Spacer(),
                      Text(
                        widget.title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.pop(context, _ctrl.text),
                        child: const Text('完了'),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: 12,
                      right: 12,
                      top: 12,
                      bottom: 12 + MediaQuery.of(context).viewInsets.bottom,
                    ),
                    child: TextField(
                      controller: _ctrl,
                      autofocus: true,
                      keyboardType: TextInputType.multiline,
                      maxLines: null,
                      expands: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'メモを入力',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// =====================
// Color chip / picker / filters
// =====================
class _ColorChip extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ColorChip({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final border = Theme.of(context).dividerColor.withOpacity(0.6);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(label),
            const SizedBox(width: 6),
          ],
        ),
      ),
    );
  }
}

class _ColorPickerDialog extends StatelessWidget {
  final String title;
  final Color current;

  const _ColorPickerDialog({
    required this.title,
    required this.current,
  });

  static final List<Color> _preset = [
    Colors.red,
    Colors.pink,
    Colors.purple,
    Colors.deepPurple,
    Colors.indigo,
    Colors.blue,
    Colors.lightBlue,
    Colors.cyan,
    Colors.teal,
    Colors.green,
    Colors.lightGreen,
    Colors.lime,
    Colors.yellow,
    Colors.amber,
    Colors.orange,
    Colors.deepOrange,
    Colors.brown,
    Colors.grey,
    Colors.blueGrey,
    Colors.black,
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: double.maxFinite,
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _preset.map((c) {
            final selected = c.value == current.value;
            return InkWell(
              onTap: () => Navigator.pop(context, c.value),
              borderRadius: BorderRadius.circular(999),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.black.withOpacity(0.15),
                    width: selected ? 3 : 1,
                  ),
                ),
                child: selected
                    ? Icon(
                  Icons.check,
                  color: Theme.of(context).colorScheme.onPrimary,
                )
                    : null,
              ),
            );
          }).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('閉じる'),
        ),
      ],
    );
  }
}

class _MultiCompanyPickerDialog extends StatefulWidget {
  final Box<Company> box;
  final Set<int> initial;

  const _MultiCompanyPickerDialog({
    required this.box,
    required this.initial,
  });

  @override
  State<_MultiCompanyPickerDialog> createState() =>
      _MultiCompanyPickerDialogState();
}

class _MultiCompanyPickerDialogState extends State<_MultiCompanyPickerDialog> {
  late Set<int> _selected;
  late final List<MapEntry<int, Company>> _companies;

  @override
  void initState() {
    super.initState();
    _selected = Set<int>.from(widget.initial);

    _companies = widget.box
        .toMap()
        .entries
        .where((e) => e.key is int)
        .map((e) => MapEntry(e.key as int, e.value))
        .toList()
      ..sort((a, b) => a.value.name.compareTo(b.value.name));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('企業を選択'),
      content: SizedBox(
        width: double.maxFinite,
        height: 420,
        child: _companies.isEmpty
            ? const Center(child: Text('企業がありません。'))
            : ListView.builder(
          itemCount: _companies.length,
          itemBuilder: (_, i) {
            final k = _companies[i].key;
            final c = _companies[i].value;
            final checked = _selected.contains(k);

            return CheckboxListTile(
              value: checked,
              onChanged: (v) {
                setState(() {
                  if (v == true) {
                    _selected.add(k);
                  } else {
                    _selected.remove(k);
                  }
                });
              },
              title: Text(c.name),
              controlAffinity: ListTileControlAffinity.leading,
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => setState(() => _selected.clear()),
          child: const Text('全解除'),
        ),
        const Spacer(),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _selected),
          child: const Text('OK'),
        ),
      ],
    );
  }
}

class _MultiScheduleTypePickerDialog extends StatefulWidget {
  final Set<ScheduleType> initial;
  final Map<ScheduleType, String> label;

  const _MultiScheduleTypePickerDialog({
    required this.initial,
    required this.label,
  });

  @override
  State<_MultiScheduleTypePickerDialog> createState() =>
      _MultiScheduleTypePickerDialogState();
}

class _MultiScheduleTypePickerDialogState
    extends State<_MultiScheduleTypePickerDialog> {
  late Set<ScheduleType> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set<ScheduleType>.from(widget.initial);
  }

  @override
  Widget build(BuildContext context) {
    final types = ScheduleType.values;

    return AlertDialog(
      title: const Text('選考フローを選択'),
      content: SizedBox(
        width: double.maxFinite,
        height: 420,
        child: ListView.builder(
          itemCount: types.length,
          itemBuilder: (_, i) {
            final t = types[i];
            final checked = _selected.contains(t);

            return CheckboxListTile(
              value: checked,
              onChanged: (v) {
                setState(() {
                  if (v == true) {
                    _selected.add(t);
                  } else {
                    _selected.remove(t);
                  }
                });
              },
              title: Text(widget.label[t] ?? t.name),
              controlAffinity: ListTileControlAffinity.leading,
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => setState(() => _selected.clear()),
          child: const Text('全解除'),
        ),
        const Spacer(),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _selected),
          child: const Text('OK'),
        ),
      ],
    );
  }
}
