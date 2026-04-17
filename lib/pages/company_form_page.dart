// company_form_page.dart
//
// 修正点
// ・ESの背景を白（ESタブだけ白背景）
// ・ESの編集画面：Dialog → 下から出るBottomSheet（DraggableScrollableSheet）
// ・予定の追加/編集画面：Dialog → 下から出るBottomSheet（DraggableScrollableSheet）
// ・予定タブ：メモ欄を表示（空なら非表示）
// ・予定タブの色/アイコンは home_page.dart の SharedPreferences と完全同期（resumed時も再読込）
// ・編集時の右上メニューに「削除」を追加

import '../widgets/ad_scaffold.dart';
import '../ads/interstitial_ad_manager.dart';
import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../db/hive_service.dart';
import '../models/company.dart';

enum _EventType { deadline, interview, test, gd, event, other }

enum EsCategory { summer, winter, early, main }

class CompanyFormPage extends StatefulWidget {
  final Company? editing;
  const CompanyFormPage({super.key, this.editing});

  @override
  State<CompanyFormPage> createState() => _CompanyFormPageState();
}

class _CompanyFormPageState extends State<CompanyFormPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _nameCtrl = TextEditingController();
  final _mypageUrlCtrl = TextEditingController();
  final _mypageidCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  final _nameFocus = FocusNode();
  final _urlFocus = FocusNode();
  final _idFocus = FocusNode();
  final _passFocus = FocusNode();

  static const List<String> _industryOptions = [
    'コンサル',
    'IT ・ 通信',
    'メーカー',
    '金融',
    '商社',
    '広告 ・ 出版',
    '人材 ・ 教育',
    'インフラ ・ 交通',
    '不動産 ・ 建設',
    '旅行 ・ 観光',
    '医療 ・ 福祉',
    '官公庁 ・ 自治体',
    '小売 ・ 流通',
    'その他',
  ];

  String? _industry;

  SelectionTrack _track = SelectionTrack.main;
  SelectionPhase _phase = SelectionPhase.notApplied;
  DesireLevel? _desire;

  List<EsQa> _esSummer = [];
  List<EsQa> _esWinter = [];
  List<EsQa> _esEarly = [];
  List<EsQa> _esMain = [];

  List<ScheduleItem> _schedules = [];
  bool _pastExpanded = false;

  late final TabController _topTabCtrl;

  bool _saving = false;
  Timer? _debounce;

  bool get _isEdit => widget.editing != null;
  bool get _isCreate => widget.editing == null;

  static const _kDeadlineColorKey = 'deadlineColor';
  static const _kInterviewColorKey = 'interviewColor';
  static const _kTestColorKey = 'testColor';
  static const _kGdColorKey = 'gdColor';
  static const _kEventColorKey = 'eventColor';
  static const _kOtherColorKey = 'otherColor';
  static const _kReviewPromptNextScheduleCountKey =
      'reviewPromptNextScheduleCountMyShukatu';

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

  static const Map<SelectionTrack, String> _trackLabel = {
    SelectionTrack.summerIntern: '夏インターン',
    SelectionTrack.winterIntern: '冬インターン',
    SelectionTrack.early: '早期選考',
    SelectionTrack.main: '本選考',
  };

  static const Map<SelectionPhase, String> _phaseLabel = {
    SelectionPhase.notApplied: '未応募',
    SelectionPhase.entry: 'エントリー',
    SelectionPhase.es: 'ES',
    SelectionPhase.webTest: 'WEBテスト',
    SelectionPhase.gd: 'GD',
    SelectionPhase.interview1: '1次面接',
    SelectionPhase.interview2: '2次面接',
    SelectionPhase.interview3: '3次面接',
    SelectionPhase.interview4: '4次面接',
    SelectionPhase.finalInterview: '最終面接',
    SelectionPhase.offer: '内定',
    SelectionPhase.declined: '辞退',
    SelectionPhase.rejected: '不合格',
  };

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

  static const Map<DesireLevel, String> _desireLabel = {
    DesireLevel.high: '高',
    DesireLevel.mid: '中',
    DesireLevel.low: '低',
  };

  static const Map<EsCategory, String> _esCategoryLabel = {
    EsCategory.summer: '夏インターン',
    EsCategory.winter: '冬インターン',
    EsCategory.early: '早期選考',
    EsCategory.main: '本選考',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _topTabCtrl = TabController(length: 4, vsync: this);

    final e = widget.editing;
    if (e != null) {
      _nameCtrl.text = e.name;
      _mypageUrlCtrl.text = e.mypageUrl ?? '';
      _mypageidCtrl.text = e.mypageid ?? '';
      _passwordCtrl.text = e.mypagePassword ?? '';
      _industry = e.industry;

      _track = e.track;
      _phase = e.phase;
      _noteCtrl.text = e.note ?? '';
      _desire = e.desireLevel;

      _schedules = List<ScheduleItem>.from(e.schedules)
        ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
      _esSummer = List<EsQa>.from(e.esQasSummer);
      _esWinter = List<EsQa>.from(e.esQasWinter);
      _esEarly = List<EsQa>.from(e.esQasEarly);
      _esMain = List<EsQa>.from(e.esQasMain);
    }

    for (final c in [
      _nameCtrl,
      _mypageUrlCtrl,
      _mypageidCtrl,
      _passwordCtrl,
      _noteCtrl,
    ]) {
      c.addListener(_onCompanyInfoChanged);
    }

    _loadCalendarColorPrefs();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_isCreate) _nameFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();

    _topTabCtrl.dispose();

    _nameCtrl.dispose();
    _mypageUrlCtrl.dispose();
    _mypageidCtrl.dispose();
    _passwordCtrl.dispose();
    _noteCtrl.dispose();

    _nameFocus.dispose();
    _urlFocus.dispose();
    _idFocus.dispose();
    _passFocus.dispose();

    super.dispose();
  }
  void _dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadCalendarColorPrefs();
    }
  }

  Future<void> _loadCalendarColorPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    setState(() {
      _deadlineColorValue = prefs.getInt(_kDeadlineColorKey) ?? Colors.red.value;
      _interviewColorValue = prefs.getInt(_kInterviewColorKey) ?? Colors.blue.value;
      _testColorValue = prefs.getInt(_kTestColorKey) ?? Colors.teal.value;
      _gdColorValue = prefs.getInt(_kGdColorKey) ?? Colors.deepOrange.value;
      _eventColorValue = prefs.getInt(_kEventColorKey) ?? Colors.green.value;
      _otherColorValue = prefs.getInt(_kOtherColorKey) ?? Colors.grey.value;
    });
  }

  int _currentGlobalCompanyCount() {
    final box = HiveService.companyBox();
    final currentEditingKey = widget.editing?.key;

    if (currentEditingKey == null) {
      return box.length + 1;
    }
    return box.length;
  }

  int _currentGlobalScheduleCount() {
    final box = HiveService.companyBox();
    final currentEditingKey = widget.editing?.key;
    var total = 0;

    for (final entry in box.toMap().entries) {
      final key = entry.key;
      final company = entry.value;
      if (key == currentEditingKey) {
        total += _schedules.length;
      } else {
        total += company.schedules.length;
      }
    }

    if (currentEditingKey == null) {
      total += _schedules.length;
    }

    return total;
  }

  int _currentGlobalEsCount() {
    final box = HiveService.companyBox();
    final currentEditingKey = widget.editing?.key;
    var total = 0;

    int localEsCount() {
      return _esSummer.length + _esWinter.length + _esEarly.length + _esMain.length;
    }

    for (final entry in box.toMap().entries) {
      final key = entry.key;
      final company = entry.value;

      if (key == currentEditingKey) {
        total += localEsCount();
      } else {
        total += company.esQasSummer.length;
        total += company.esQasWinter.length;
        total += company.esQasEarly.length;
        total += company.esQasMain.length;
      }
    }

    if (currentEditingKey == null) {
      total += localEsCount();
    }

    return total;
  }

  Future<void> _tryShowStoreReviewPrompt() async {
    final prefs = await SharedPreferences.getInstance();

    final companyCount = _currentGlobalCompanyCount();
    final scheduleCount = _currentGlobalScheduleCount();
    final esCount = _currentGlobalEsCount();

    final baseConditionMet =
        companyCount >= 3 &&
            scheduleCount >= 3 &&
            esCount >= 1;
    if (!baseConditionMet) return;

    final nextScheduleTrigger =
        prefs.getInt(_kReviewPromptNextScheduleCountKey) ?? 3;
    if (scheduleCount < nextScheduleTrigger) return;

    final inAppReview = InAppReview.instance;
    final isAvailable = await inAppReview.isAvailable();
    if (!isAvailable) return;

    await inAppReview.requestReview();

    await prefs.setInt(
      _kReviewPromptNextScheduleCountKey,
      scheduleCount + 5,
    );
  }

  Future<void> _deleteCompany() async {
    if (!_isEdit) return;

    final c = widget.editing!;
    final companyName = c.name;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('企業を削除'),
        content: Text('「$companyName」を削除しますか？\nこの操作は元に戻せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await c.delete();

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('「$companyName」を削除しました'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('削除に失敗しました: $e')),
      );
    }
  }

  Future<T?> _openPickerSheet<T>({
    required String title,
    required List<_PickerOption<T>> options,
    required T? currentValue,
    required String Function(T? v) labelOf,
  }) async {
    return showModalBottomSheet<T?>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        T? temp = currentValue;

        return StatefulBuilder(
          builder: (ctx, setModalState) {
            void safeSetModalState(VoidCallback fn) {
              if (!ctx.mounted) return;
              setModalState(fn);
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 8,
                  bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(ctx)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(ctx).size.height * 0.55,
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: options.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final opt = options[i];
                          final selected =
                              (temp == opt.value) ||
                                  (temp == null && opt.value == null);
                          return ListTile(
                            dense: true,
                            title: Text(
                              opt.label,
                              style: const TextStyle(fontSize: 13),
                            ),
                            trailing: selected ? const Icon(Icons.check) : null,
                            onTap: () => safeSetModalState(() => temp = opt.value),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, null),
                          child: const Text('キャンセル'),
                        ),
                        const Spacer(),
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx, temp),
                          child: Text(
                            '適用（${labelOf(temp)}）',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
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

  Widget _pickerRow({
    required String label,
    required String valueText,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          isDense: true,
          labelStyle: TextStyle(fontSize: 12),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ).copyWith(labelText: label),
        child: Row(
          children: [
            Expanded(
              child: Text(
                valueText,
                style: const TextStyle(fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onTap != null) const Icon(Icons.unfold_more, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _suffixActionIcon({
    required String tooltip,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon, size: 18),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(
        minWidth: 32,
        minHeight: 32,
      ),
      onPressed: onPressed,
    );
  }

  Widget _smallTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    FocusNode? nextFocus,
    required String label,
    bool obscureText = false,
    TextInputType? keyboardType,
    List<Widget>? suffixActions,
    bool required = false,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      obscureText: obscureText,
      maxLines: 1,
      textInputAction:
      nextFocus == null ? TextInputAction.done : TextInputAction.next,
      style: const TextStyle(fontSize: 13),
      onTapOutside: (_) => _dismissKeyboard(),
      onSubmitted: (_) {
        if (nextFocus != null) {
          nextFocus.requestFocus();
        } else {
          _dismissKeyboard();
        }
      },
      decoration: InputDecoration(
        label: RichText(
          text: TextSpan(
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black87,
            ),
            children: [
              TextSpan(text: label),
              if (required)
                const TextSpan(
                  text: ' *',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ),
        border: const OutlineInputBorder(),
        isDense: true,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        suffixIconConstraints: const BoxConstraints(
          minWidth: 0,
          minHeight: 0,
        ),
        suffixIcon: suffixActions == null
            ? null
            : Row(
          mainAxisSize: MainAxisSize.min,
          children: suffixActions,
        ),
      ),
    );
  }

  void _onCompanyInfoChanged() {
    if (mounted) {
      setState(() {});
    }
    if (!_isEdit) return;
    _autoSaveDebounced();
  }

  void _autoSaveDebounced() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      if (!mounted) return;
      await _saveEdit(auto: true);
    });
  }

  Future<void> _copyToClipboard(String text, String label) async {
    if (text.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$labelをコピーしました')),
    );
  }

  Future<void> _openUrlIfPossible(String url) async {
    final raw = url.trim();
    if (raw.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('URLが未入力です')),
      );
      return;
    }

    final normalized =
    raw.startsWith('http://') || raw.startsWith('https://')
        ? raw
        : 'https://$raw';

    final uri = Uri.tryParse(normalized);
    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('URLの形式が正しくありません')),
      );
      return;
    }

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('URLを開けませんでした')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('URLを開けませんでした')),
      );
    }
  }

  String _dtText(DateTime dt) => dt.toLocal().toString().substring(0, 16);

  DateTime _snapToMinuteInterval(DateTime dt, int minuteInterval) {
    final m = dt.minute;
    final snapped = (m ~/ minuteInterval) * minuteInterval;
    return DateTime(dt.year, dt.month, dt.day, dt.hour, snapped);
  }

  Future<DateTime?> _pickDateTime(DateTime? current) async {
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
                      style: Theme.of(ctx)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
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
                    onDateTimeChanged: (v) {
                      temp = _snapToMinuteInterval(v, interval);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveCreate() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('企業名を入力してください。')),
      );
      return;
    }
    if (_saving) return;
    setState(() => _saving = true);

    try {
      final box = HiveService.companyBox();
      final now = DateTime.now();

      final c = Company(
        name: name,
        mypageUrl:
        _mypageUrlCtrl.text.trim().isEmpty ? null : _mypageUrlCtrl.text.trim(),
        mypageid:
        _mypageidCtrl.text.trim().isEmpty ? null : _mypageidCtrl.text.trim(),
        mypagePassword:
        _passwordCtrl.text.trim().isEmpty ? null : _passwordCtrl.text,
        industry: _industry,
        createdAt: now,
        updatedAt: now,
        desireLevel: _desire,
      );

      await box.add(c);
      await _tryShowStoreReviewPrompt();

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存に失敗しました: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveEdit({required bool auto}) async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      if (!auto && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('企業名を入力してください。')),
        );
      }
      return;
    }
    if (_saving) return;
    setState(() => _saving = true);

    try {
      final now = DateTime.now();
      final c = widget.editing!;

      c.name = name;
      c.mypageUrl =
      _mypageUrlCtrl.text.trim().isEmpty ? null : _mypageUrlCtrl.text.trim();
      c.mypageid =
      _mypageidCtrl.text.trim().isEmpty ? null : _mypageidCtrl.text.trim();
      c.mypagePassword =
      _passwordCtrl.text.trim().isEmpty ? null : _passwordCtrl.text;
      c.industry = _industry;

      c.desireLevel = _desire;
      c.track = _track;
      c.phase = _phase;
      c.note = _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim();

      c.schedules = _schedules;

      c.esQasSummer = _esSummer;
      c.esQasWinter = _esWinter;
      c.esQasEarly = _esEarly;
      c.esQasMain = _esMain;

      c.updatedAt = now;

      await c.save();

      if (!auto && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('保存しました')),
        );
      }
    } catch (e) {
      if (mounted && !auto) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存に失敗しました: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<_EsBulkResult?> _openEsBulkEditor({
    required EsCategory initialCategory,
    List<EsQa>? initialItems,
    EsCategory? fromCategoryWhenEditingOne,
    int? editingIndexInFromCategory,
  }) async {
    return showModalBottomSheet<_EsBulkResult?>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _BottomSheetScaffold(
          child: _EsBulkEditorSheet(
            initialCategory: initialCategory,
            categoryLabel: _esCategoryLabel,
            openCategoryPicker: () async {
              final picked = await _openPickerSheet<EsCategory>(
                title: 'カテゴリを選択',
                currentValue: null,
                labelOf: (v) => v == null ? '未選択' : (_esCategoryLabel[v] ?? v.name),
                options: [
                  ...EsCategory.values.map(
                        (c) => _PickerOption(
                      value: c,
                      label: _esCategoryLabel[c] ?? c.name,
                    ),
                  ),
                ],
              );
              return picked;
            },
            initialItems: initialItems ?? const [],
            fromCategoryWhenEditingOne: fromCategoryWhenEditingOne,
            editingIndexInFromCategory: editingIndexInFromCategory,
          ),
        );
      },
    );
  }

  Future<void> _onAddEs() async {
    final res = await _openEsBulkEditor(
      initialCategory: EsCategory.summer,
      initialItems: const [],
    );
    if (!mounted) return;
    if (res == null) return;

    setState(() {
      _applyEsBulkResult(res);
    });
    if (_isEdit) {
      await _saveEdit(auto: true);
    }

    await _tryShowStoreReviewPrompt();
  }

  void _applyEsBulkResult(_EsBulkResult res) {
    if (res.fromCategoryWhenEditingOne != null &&
        res.editingIndexInFromCategory != null) {
      final from = res.fromCategoryWhenEditingOne!;
      final idx = res.editingIndexInFromCategory!;
      final list = _listByCategory(from);
      if (idx >= 0 && idx < list.length) {
        list.removeAt(idx);
      }
    }

    final cleaned = res.items
        .map((e) => EsQa(question: e.question.trim(), answer: e.answer.trim()))
        .where(
          (e) => e.question.trim().isNotEmpty || e.answer.trim().isNotEmpty,
    )
        .toList();

    _listByCategory(res.category).addAll(cleaned);
  }

  void _applyEsBulkResultReplaceAll({
    required EsCategory fromCategory,
    required _EsBulkResult res,
  }) {
    final cleaned = res.items
        .map((e) => EsQa(question: e.question.trim(), answer: e.answer.trim()))
        .where(
          (e) => e.question.trim().isNotEmpty || e.answer.trim().isNotEmpty,
    )
        .toList();

    if (res.category == fromCategory) {
      final fromList = _listByCategory(fromCategory);
      fromList
        ..clear()
        ..addAll(cleaned);
      return;
    }

    final fromList = _listByCategory(fromCategory);
    final toList = _listByCategory(res.category);

    fromList.clear();
    toList
      ..clear()
      ..addAll(cleaned);
  }

  List<EsQa> _listByCategory(EsCategory c) {
    switch (c) {
      case EsCategory.summer:
        return _esSummer;
      case EsCategory.winter:
        return _esWinter;
      case EsCategory.early:
        return _esEarly;
      case EsCategory.main:
        return _esMain;
    }
  }

  Future<ScheduleItem?> _openScheduleSheet({ScheduleItem? initial}) async {
    return showModalBottomSheet<ScheduleItem?>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _BottomSheetScaffold(
          child: _ScheduleEditorSheet(
            title: initial == null ? '予定を追加' : '予定を編集',
            initialType: initial?.type ?? ScheduleType.event,
            initialDt: initial?.dateTime,
            initialNote: initial?.note ?? '',
            dtText: _dtText,
            scheduleTypeLabel: _scheduleTypeLabel,
            pickDateTime: _pickDateTime,
            pickType: (current) async {
              final picked = await _openPickerSheet<ScheduleType>(
                title: '種類を選択',
                currentValue: current,
                labelOf: (v) => v == null ? '未選択' : (_scheduleTypeLabel[v] ?? v.name),
                options: ScheduleType.values
                    .map(
                      (t) => _PickerOption(
                    value: t,
                    label: _scheduleTypeLabel[t] ?? t.name,
                  ),
                )
                    .toList(),
              );
              return picked ?? current;
            },
          ),
        );
      },
    );
  }

  Future<void> _addSchedule() async {
    final created = await _openScheduleSheet(initial: null);
    if (!mounted) return;
    if (created == null) return;

    setState(() {
      _schedules.add(created);
      _schedules.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    });

    if (_isEdit) {
      await _saveEdit(auto: true);
    }
    await _tryShowStoreReviewPrompt();
  }

  Future<void> _editSchedule(ScheduleItem item) async {
    final edited = await _openScheduleSheet(initial: item);
    if (!mounted) return;
    if (edited == null) return;

    final idx = _schedules.indexOf(item);
    if (idx < 0) return;

    setState(() {
      _schedules[idx] = edited;
      _schedules.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    });

    if (_isEdit) {
      await _saveEdit(auto: true);
    }

    await _tryShowStoreReviewPrompt();
  }

  Future<void> _deleteSchedule(ScheduleItem item) async {
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
    if (!mounted) return;
    if (ok != true) return;

    setState(() {
      _schedules.remove(item);
    });

    if (_isEdit) {
      await _saveEdit(auto: true);
    }

    await _tryShowStoreReviewPrompt();
  }

  Widget _buildCreateForm() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _dismissKeyboard,
      child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.all(16),
        children: [
          _smallTextField(
            controller: _nameCtrl,
            focusNode: _nameFocus,
            nextFocus: _urlFocus,
            label: '企業名',
            required: true,
          ),
          const SizedBox(height: 12),
          _smallTextField(
            controller: _mypageUrlCtrl,
            focusNode: _urlFocus,
            nextFocus: _idFocus,
            label: 'マイページURL',
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 12),
          _smallTextField(
            controller: _mypageidCtrl,
            focusNode: _idFocus,
            nextFocus: _passFocus,
            label: 'マイページID',
          ),
          const SizedBox(height: 12),
          _smallTextField(
            controller: _passwordCtrl,
            focusNode: _passFocus,
            label: 'パスワード',
            obscureText: true,
          ),
          const SizedBox(height: 12),
          _pickerRow(
            label: '業界',
            valueText: (_industry == null || _industry!.trim().isEmpty)
                ? '未選択'
                : _industry!,
            onTap: () async {
              _dismissKeyboard();
              final picked = await _openPickerSheet<String>(
                title: '業界を選択',
                currentValue: _industry,
                labelOf: (v) => (v == null || v.trim().isEmpty) ? '未選択' : v,
                options: [
                  const _PickerOption<String>(value: null, label: '未選択'),
                  ..._industryOptions.map((s) => _PickerOption<String>(value: s, label: s)),
                ],
              );
              if (!mounted) return;
              setState(() => _industry = picked);
            },
          ),
          const SizedBox(height: 12),
          _pickerRow(
            label: '志望度',
            valueText: _desire == null ? '未選択' : (_desireLabel[_desire!] ?? _desire!.name),
            onTap: () async {
              _dismissKeyboard();
              final picked = await _openPickerSheet<DesireLevel>(
                title: '志望度を選択',
                currentValue: _desire,
                labelOf: (v) => v == null ? '未選択' : (_desireLabel[v] ?? v.name),
                options: [
                  const _PickerOption<DesireLevel>(value: null, label: '未選択'),
                  ...DesireLevel.values.map(
                        (d) => _PickerOption(value: d, label: _desireLabel[d] ?? d.name),
                  ),
                ],
              );
              if (!mounted) return;
              setState(() => _desire = picked);
            },
          ),
          const SizedBox(height: 24),
          if (_saving) const LinearProgressIndicator(),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _saving
                ? null
                : () {
              _dismissKeyboard();
              _saveCreate();
            },
            child: const Text('保存して登録'),
          ),
        ],
      ),
    );
  }

  Widget _buildCompanyInfoTab() {
    final hasUrl = _mypageUrlCtrl.text.trim().isNotEmpty;
    final hasId = _mypageidCtrl.text.trim().isNotEmpty;
    final hasPassword = _passwordCtrl.text.trim().isNotEmpty;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _dismissKeyboard,
      child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.all(16),
        children: [
          _smallTextField(
            controller: _nameCtrl,
            focusNode: _nameFocus,
            nextFocus: _urlFocus,
            label: '会社名',
          ),
          const SizedBox(height: 12),
          _smallTextField(
            controller: _mypageUrlCtrl,
            focusNode: _urlFocus,
            nextFocus: _idFocus,
            label: 'マイページURL',
            keyboardType: TextInputType.url,
            suffixActions: [
              _suffixActionIcon(
                tooltip: '開く',
                icon: Icons.open_in_new,
                onPressed: hasUrl ? () => _openUrlIfPossible(_mypageUrlCtrl.text) : null,
              ),
              _suffixActionIcon(
                tooltip: 'コピー',
                icon: Icons.copy,
                onPressed: hasUrl ? () => _copyToClipboard(_mypageUrlCtrl.text, 'URL') : null,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _smallTextField(
            controller: _mypageidCtrl,
            focusNode: _idFocus,
            nextFocus: _passFocus,
            label: 'マイページID',
            suffixActions: [
              _suffixActionIcon(
                tooltip: 'コピー',
                icon: Icons.copy,
                onPressed: hasId ? () => _copyToClipboard(_mypageidCtrl.text, 'ID') : null,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _smallTextField(
            controller: _passwordCtrl,
            focusNode: _passFocus,
            label: 'パスワード',
            obscureText: true,
            suffixActions: [
              _suffixActionIcon(
                tooltip: 'コピー',
                icon: Icons.copy,
                onPressed: hasPassword
                    ? () => _copyToClipboard(_passwordCtrl.text, 'パスワード')
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _pickerRow(
            label: '業界',
            valueText: (_industry == null || _industry!.trim().isEmpty)
                ? '未選択'
                : _industry!,
            onTap: () async {
              _dismissKeyboard();
              final picked = await _openPickerSheet<String>(
                title: '業界を選択',
                currentValue: _industry,
                labelOf: (v) => (v == null || v.trim().isEmpty) ? '未選択' : v,
                options: [
                  const _PickerOption<String>(value: null, label: '未選択'),
                  ..._industryOptions.map((s) => _PickerOption<String>(value: s, label: s)),
                ],
              );
              if (!mounted) return;
              setState(() {
                _industry = picked;
                _autoSaveDebounced();
              });
            },
          ),
          const SizedBox(height: 12),
          _pickerRow(
            label: '志望度',
            valueText: _desire == null ? '未選択' : (_desireLabel[_desire!] ?? _desire!.name),
            onTap: () async {
              _dismissKeyboard();
              final picked = await _openPickerSheet<DesireLevel>(
                title: '志望度を選択',
                currentValue: _desire,
                labelOf: (v) => v == null ? '未選択' : (_desireLabel[v] ?? v.name),
                options: [
                  const _PickerOption<DesireLevel>(value: null, label: '未選択'),
                  ...DesireLevel.values.map(
                        (d) => _PickerOption(value: d, label: _desireLabel[d] ?? d.name),
                  ),
                ],
              );
              if (!mounted) return;
              setState(() {
                _desire = picked;
                _autoSaveDebounced();
              });
            },
          ),
          const SizedBox(height: 12),
          _pickerRow(
            label: '選考区分',
            valueText: _trackLabel[_track] ?? '未選択',
            onTap: () async {
              _dismissKeyboard();
              final picked = await _openPickerSheet<SelectionTrack>(
                title: '選考区分を選択',
                currentValue: _track,
                labelOf: (v) => v == null ? '未選択' : (_trackLabel[v] ?? v.name),
                options: SelectionTrack.values
                    .map((t) => _PickerOption(value: t, label: _trackLabel[t] ?? t.name))
                    .toList(),
              );
              if (!mounted) return;
              setState(() {
                if (picked != null) _track = picked;
                _autoSaveDebounced();
              });
            },
          ),
          const SizedBox(height: 12),
          _pickerRow(
            label: 'フェーズ',
            valueText: _phaseLabel[_phase] ?? '未選択',
            onTap: () async {
              _dismissKeyboard();
              final picked = await _openPickerSheet<SelectionPhase>(
                title: 'フェーズを選択',
                currentValue: _phase,
                labelOf: (v) => v == null ? '未選択' : (_phaseLabel[v] ?? v.name),
                options: SelectionPhase.values
                    .map((p) => _PickerOption(value: p, label: _phaseLabel[p] ?? p.name))
                    .toList(),
              );
              if (!mounted) return;
              setState(() {
                if (picked != null) _phase = picked;
                _autoSaveDebounced();
              });
            },
          ),
          const SizedBox(height: 12),
          if (_saving) const LinearProgressIndicator(),
        ],
      ),
    );
  }

  Widget _buildCompanyMemoTab() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _dismissKeyboard,
      child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '企業メモ',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteCtrl,
            maxLines: null,
            minLines: 14,
            onTapOutside: (_) => _dismissKeyboard(),
            style: const TextStyle(fontSize: 13, height: 1.45),
            decoration: const InputDecoration(
              hintText: 'この企業について自由にメモできます',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
              isDense: true,
              labelStyle: TextStyle(fontSize: 12),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          if (_saving) const LinearProgressIndicator(),
        ],
      ),
    );
  }

  Widget _buildEsTab() {
    final ordered = <(EsCategory, List<EsQa>)>[
      (EsCategory.summer, _esSummer),
      (EsCategory.winter, _esWinter),
      (EsCategory.early, _esEarly),
      (EsCategory.main, _esMain),
    ];

    final visible = ordered.where((e) => e.$2.isNotEmpty).toList();

    return Container(
      color: Colors.white,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text('ES', style: Theme.of(context).textTheme.titleMedium),
              ),
              FilledButton.icon(
                onPressed: _onAddEs,
                icon: const Icon(Icons.add),
                label: const Text('追加'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...visible.map((entry) {
            final cat = entry.$1;
            final list = entry.$2;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _EsCategoryCard(
                cardColor: Colors.white,
                categoryLabel: _esCategoryLabel[cat] ?? cat.name,
                items: list,
                onCopyAnswer: (a) => _copyToClipboard(a, '回答'),
                onEditCategory: () async {
                  final res = await _openEsBulkEditor(
                    initialCategory: cat,
                    initialItems: List<EsQa>.from(list),
                  );
                  if (!mounted) return;
                  if (res == null) return;

                  setState(() {
                    _applyEsBulkResultReplaceAll(fromCategory: cat, res: res);
                  });
                  if (_isEdit) {
                    await _saveEdit(auto: true);
                  }

                  await _tryShowStoreReviewPrompt();
                },
                onDeleteCategory: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text('確認'),
                      content: Text('「${_esCategoryLabel[cat]}」のESをすべて削除しますか？'),
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
                  if (!mounted) return;
                  if (ok != true) return;

                  setState(() => list.clear());
                  if (_isEdit) {
                    await _saveEdit(auto: true);
                  }

                  await _tryShowStoreReviewPrompt();
                },
              ),
            );
          }),
          if (_saving) const LinearProgressIndicator(),
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  DateTime _startOfWeek(DateTime d) {
    final dd = _dateOnly(d);
    final diff = (dd.weekday + 6) % 7;
    return dd.subtract(Duration(days: diff));
  }

  DateTime _endOfWeek(DateTime d) => _startOfWeek(d).add(const Duration(days: 7));

  _EventType _eventTypeFromSchedule(ScheduleType t) {
    switch (t) {
      case ScheduleType.esDeadline:
        return _EventType.deadline;
      case ScheduleType.interview1:
      case ScheduleType.interview2:
      case ScheduleType.interview3:
      case ScheduleType.interview4:
      case ScheduleType.finalInterview:
        return _EventType.interview;
      case ScheduleType.webTest:
        return _EventType.test;
      case ScheduleType.gd:
        return _EventType.gd;
      case ScheduleType.event:
        return _EventType.event;
      case ScheduleType.other:
        return _EventType.other;
    }
  }

  Color _colorForEventType(_EventType t) {
    switch (t) {
      case _EventType.deadline:
        return _deadlineColor;
      case _EventType.interview:
        return _interviewColor;
      case _EventType.test:
        return _testColor;
      case _EventType.gd:
        return _gdColor;
      case _EventType.event:
        return _eventColor;
      case _EventType.other:
        return _otherColor;
    }
  }

  IconData _iconForEventType(_EventType t) {
    switch (t) {
      case _EventType.deadline:
        return Icons.flag;
      case _EventType.interview:
        return Icons.record_voice_over;
      case _EventType.test:
        return Icons.edit;
      case _EventType.gd:
        return Icons.groups;
      case _EventType.event:
        return Icons.event_available;
      case _EventType.other:
        return Icons.more_horiz;
    }
  }

  Widget _sectionHeader(String title, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const Spacer(),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _scheduleRow(ScheduleItem item) {
    final t = _eventTypeFromSchedule(item.type);
    final color = _colorForEventType(t);
    final icon = _iconForEventType(t);
    final label = _scheduleTypeLabel[item.type] ?? item.type.name;
    final note = (item.note ?? '').trim();

    return Card(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: color.withOpacity(0.35)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon, size: 14, color: color),
                            const SizedBox(width: 6),
                            Text(
                              label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: color,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        _dtText(item.dateTime),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  if (note.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      note,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.color
                            ?.withOpacity(0.70),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'edit') {
                  await _editSchedule(item);
                } else if (v == 'delete') {
                  await _deleteSchedule(item);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('編集')),
                PopupMenuItem(value: 'delete', child: Text('削除')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleTab() {
    final now = DateTime.now();
    final today = _dateOnly(now);
    final weekStart = _startOfWeek(now);
    final weekEnd = _endOfWeek(now);

    final sorted = List<ScheduleItem>.from(_schedules)
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    final todayList = <ScheduleItem>[];
    final weekList = <ScheduleItem>[];
    final futureList = <ScheduleItem>[];
    final pastList = <ScheduleItem>[];

    for (final s in sorted) {
      final d = _dateOnly(s.dateTime.toLocal());

      if (d.isBefore(today)) {
        pastList.add(s);
        continue;
      }

      if (_isSameDay(d, today)) {
        todayList.add(s);
        continue;
      }

      if (!d.isBefore(weekStart) && d.isBefore(weekEnd)) {
        weekList.add(s);
        continue;
      }

      futureList.add(s);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text('予定', style: Theme.of(context).textTheme.titleMedium),
            ),
            FilledButton.icon(
              onPressed: _addSchedule,
              icon: const Icon(Icons.add),
              label: const Text('追加'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        _sectionHeader('今日'),
        if (todayList.isEmpty) const _EmptyHint(text: '今日の予定はありません。'),
        ...todayList.map(_scheduleRow),
        _sectionHeader('今週'),
        if (weekList.isEmpty) const _EmptyHint(text: '今週の予定はありません。'),
        ...weekList.map(_scheduleRow),
        _sectionHeader('それ以降'),
        if (futureList.isEmpty) const _EmptyHint(text: '今後の予定はありません。'),
        ...futureList.map(_scheduleRow),
        _sectionHeader(
          '過去の予定(${pastList.length})',
          trailing: TextButton.icon(
            onPressed: () => setState(() => _pastExpanded = !_pastExpanded),
            icon: Icon(_pastExpanded ? Icons.expand_less : Icons.expand_more),
            label: Text(_pastExpanded ? '閉じる' : '開く'),
          ),
        ),
        if (_pastExpanded) ...[
          if (pastList.isEmpty) const _EmptyHint(text: '過去の予定はありません。'),
          ...pastList.reversed.map(_scheduleRow),
        ],
        const SizedBox(height: 12),
        if (_saving) const LinearProgressIndicator(),
        const SizedBox(height: 60),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final titleText = _isEdit
        ? (_nameCtrl.text.trim().isNotEmpty ? _nameCtrl.text.trim() : '企業')
        : '企業を追加';

    return AdScaffold(
      appBar: AppBar(
        title: Text(titleText),
        actions: _isEdit
            ? [
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'delete') {
                await _deleteCompany();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem<String>(
                value: 'delete',
                child: Text('企業を削除'),
              ),
            ],
          ),
        ]
            : null,
        bottom: _isCreate
            ? null
            : TabBar(
          controller: _topTabCtrl,
          tabs: const [
            Tab(text: '企業情報'),
            Tab(text: 'ES'),
            Tab(text: '予定'),
            Tab(text: '企業メモ'),
          ],
        ),
      ),
      body: _isCreate
          ? _buildCreateForm()
          : TabBarView(
        controller: _topTabCtrl,
        children: [
          _buildCompanyInfoTab(),
          _buildEsTab(),
          _buildScheduleTab(),
          _buildCompanyMemoTab(),
        ],
      ),
    );
  }
}

class _PickerOption<T> {
  final T? value;
  final String label;
  const _PickerOption({required this.value, required this.label});
}

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

class _EsCategoryCard extends StatelessWidget {
  final Color? cardColor;
  final String categoryLabel;
  final List<EsQa> items;
  final Future<void> Function() onEditCategory;
  final Future<void> Function() onDeleteCategory;
  final Future<void> Function(String answer) onCopyAnswer;

  const _EsCategoryCard({
    this.cardColor,
    required this.categoryLabel,
    required this.items,
    required this.onEditCategory,
    required this.onDeleteCategory,
    required this.onCopyAnswer,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: cardColor,
      surfaceTintColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    categoryLabel,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'edit') {
                      await onEditCategory();
                    } else if (v == 'delete') {
                      await onDeleteCategory();
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('編集')),
                    PopupMenuItem(value: 'delete', child: Text('このカテゴリを削除')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1),
            for (int i = 0; i < items.length; i++) ...[
              const SizedBox(height: 10),
              _QaLine(
                tag: 'Q',
                tagColor: Colors.blue,
                text: items[i].question.trim().isEmpty
                    ? '（未入力）'
                    : items[i].question.trim(),
                trailing: const SizedBox.shrink(),
              ),
              const SizedBox(height: 8),
              _QaLine(
                tag: 'A',
                tagColor: Colors.red,
                text: items[i].answer.trim().isEmpty
                    ? '（未入力）'
                    : items[i].answer.trim(),
                trailing: IconButton(
                  tooltip: '回答をコピー',
                  iconSize: 18,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: () => onCopyAnswer(items[i].answer),
                  icon: const Icon(Icons.copy),
                ),
              ),
              if (i != items.length - 1)
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Divider(height: 1),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _QaLine extends StatelessWidget {
  final String tag;
  final Color tagColor;
  final String text;
  final Widget trailing;

  const _QaLine({
    required this.tag,
    required this.tagColor,
    required this.text,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: tagColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            tag,
            style: TextStyle(
              color: tagColor,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 13, height: 1.35),
          ),
        ),
        const SizedBox(width: 8),
        trailing,
      ],
    );
  }
}

class _EsBulkResult {
  final EsCategory category;
  final List<EsQa> items;
  final EsCategory? fromCategoryWhenEditingOne;
  final int? editingIndexInFromCategory;

  _EsBulkResult({
    required this.category,
    required this.items,
    this.fromCategoryWhenEditingOne,
    this.editingIndexInFromCategory,
  });
}

class _EsBulkEditorSheet extends StatefulWidget {
  final EsCategory initialCategory;
  final Map<EsCategory, String> categoryLabel;
  final Future<EsCategory?> Function() openCategoryPicker;
  final List<EsQa> initialItems;
  final EsCategory? fromCategoryWhenEditingOne;
  final int? editingIndexInFromCategory;

  const _EsBulkEditorSheet({
    required this.initialCategory,
    required this.categoryLabel,
    required this.openCategoryPicker,
    required this.initialItems,
    this.fromCategoryWhenEditingOne,
    this.editingIndexInFromCategory,
  });

  @override
  State<_EsBulkEditorSheet> createState() => _EsBulkEditorSheetState();
}



class _EsBulkEditorSheetState extends State<_EsBulkEditorSheet> {
  late EsCategory _category;
  late List<_QaRow> _rows;
  bool _dirty = false;

  void _dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  @override
  void initState() {
    super.initState();
    _category = widget.initialCategory;
    final initial = widget.initialItems.isEmpty
        ? [EsQa(question: '', answer: '')]
        : widget.initialItems;
    _rows = initial
        .map((e) => _QaRow(q: e.question, a: e.answer, onDirty: _markDirty))
        .toList();
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  void _markDirty() {
    if (_dirty) return;
    setState(() => _dirty = true);
  }

  Future<bool> _confirmDiscard() async {
    _dismissKeyboard();
    if (!_dirty) return true;
    final res = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('確認'),
        content: const Text('変更が保存されていません。破棄して閉じますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('破棄する'),
          ),
        ],
      ),
    );
    return res ?? false;
  }

  void _addRow() {
    setState(() {
      _rows.add(_QaRow(q: '', a: '', onDirty: _markDirty));
      _dirty = true;
    });
  }

  void _removeRow(int i) {
    if (_rows.length <= 1) return;
    setState(() {
      _rows[i].dispose();
      _rows.removeAt(i);
      _dirty = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initialItems.isNotEmpty;
    final catText = widget.categoryLabel[_category] ?? _category.name;

    return SafeArea(
      child: WillPopScope(
        onWillPop: _confirmDiscard,
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.92,
          minChildSize: 0.60,
          maxChildSize: 0.98,
          builder: (ctx, controller) {
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _dismissKeyboard,
              child: Material(
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
                            onPressed: () async {
                              _dismissKeyboard();
                              final ok = await _confirmDiscard();
                              if (!ok) return;
                              if (!mounted) return;
                              Navigator.pop(context, null);
                            },
                            child: const Text('閉じる'),
                          ),
                          const Spacer(),
                          Text(
                            isEdit ? 'ESを編集' : 'ESを追加',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () async {
                              _dismissKeyboard();
                              final items = _rows
                                  .map((r) => EsQa(
                                question: r.qCtrl.text,
                                answer: r.aCtrl.text,
                              ))
                                  .toList();

                              await InterstitialAdManager.showIfAllowed();

                              if (!mounted) return;
                              Navigator.pop(
                                context,
                                _EsBulkResult(
                                  category: _category,
                                  items: items,
                                  fromCategoryWhenEditingOne:
                                  widget.fromCategoryWhenEditingOne,
                                  editingIndexInFromCategory:
                                  widget.editingIndexInFromCategory,
                                ),
                              );
                            },
                            child: const Text('保存'),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        controller: controller,
                        keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: EdgeInsets.fromLTRB(
                          16,
                          8,
                          16,
                          24 + MediaQuery.of(context).viewInsets.bottom,
                        ),
                        children: [
                          InkWell(
                            onTap: () async {
                              _dismissKeyboard();
                              final picked = await widget.openCategoryPicker();
                              if (picked == null || !mounted) return;
                              setState(() {
                                _category = picked;
                                _dirty = true;
                              });
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'カテゴリ',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              child: Row(
                                children: [
                                  Expanded(child: Text(catText)),
                                  const Icon(Icons.unfold_more),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          for (int i = 0; i < _rows.length; i++) ...[
                            _EsEditorBlock(
                              index: i,
                              row: _rows[i],
                              onDelete: () => _removeRow(i),
                              canDelete: _rows.length > 1,
                            ),
                            const SizedBox(height: 12),
                          ],
                          OutlinedButton.icon(
                            onPressed: () {
                              _dismissKeyboard();
                              _addRow();
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('設問を追加'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _QaRow {
  final TextEditingController qCtrl;
  final TextEditingController aCtrl;
  final VoidCallback onDirty;

  _QaRow({
    required String q,
    required String a,
    required this.onDirty,
  })  : qCtrl = TextEditingController(text: q),
        aCtrl = TextEditingController(text: a) {
    qCtrl.addListener(onDirty);
    aCtrl.addListener(onDirty);
  }

  void dispose() {
    qCtrl.dispose();
    aCtrl.dispose();
  }
}

class _EsEditorBlock extends StatelessWidget {
  final int index;
  final _QaRow row;
  final VoidCallback onDelete;
  final bool canDelete;

  const _EsEditorBlock({
    required this.index,
    required this.row,
    required this.onDelete,
    required this.canDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      surfaceTintColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  '設問 ${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                if (canDelete)
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
                    tooltip: '削除',
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: row.qCtrl,
              maxLines: null,
              onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
              decoration: const InputDecoration(
                labelText: '質問',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: row.aCtrl,
              maxLines: null,
              onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
              decoration: const InputDecoration(
                labelText: '回答',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
class _ScheduleEditorSheet extends StatefulWidget {
  final String title;
  final ScheduleType initialType;
  final DateTime? initialDt;
  final String initialNote;
  final Future<DateTime?> Function(DateTime? current) pickDateTime;
  final Future<ScheduleType> Function(ScheduleType current) pickType;
  final String Function(DateTime dt) dtText;
  final Map<ScheduleType, String> scheduleTypeLabel;

  const _ScheduleEditorSheet({
    required this.title,
    required this.initialType,
    required this.initialDt,
    required this.initialNote,
    required this.pickDateTime,
    required this.pickType,
    required this.dtText,
    required this.scheduleTypeLabel,
  });

  @override
  State<_ScheduleEditorSheet> createState() => _ScheduleEditorSheetState();
}

class _ScheduleEditorSheetState extends State<_ScheduleEditorSheet> {
  late ScheduleType _type;
  DateTime? _dt;
  late final TextEditingController _noteCtrl;
  bool _dirty = false;

  void _dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    _dt = widget.initialDt;
    _noteCtrl = TextEditingController(text: widget.initialNote);
    _noteCtrl.addListener(_markDirty);
  }

  void _markDirty() {
    if (_dirty) return;
    setState(() => _dirty = true);
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<bool> _confirmDiscard() async {
    _dismissKeyboard();
    if (!_dirty) return true;
    final res = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('確認'),
        content: const Text('変更が保存されていません。破棄して閉じますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('破棄する'),
          ),
        ],
      ),
    );
    return res ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final typeText = widget.scheduleTypeLabel[_type] ?? _type.name;

    return SafeArea(
      child: WillPopScope(
        onWillPop: _confirmDiscard,
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.82,
          minChildSize: 0.55,
          maxChildSize: 0.98,
          builder: (ctx, controller) {
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _dismissKeyboard,
              child: Material(
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
                            onPressed: () async {
                              _dismissKeyboard();
                              final ok = await _confirmDiscard();
                              if (!ok) return;
                              if (!mounted) return;
                              Navigator.pop(context, null);
                            },
                            child: const Text('キャンセル'),
                          ),
                          const Spacer(),
                          Text(
                            widget.title,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () async {
                              _dismissKeyboard();
                              if (_dt == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('日時を選択してください')),
                                );
                                return;
                              }

                              await InterstitialAdManager.showIfAllowed();

                              if (!mounted) return;
                              Navigator.pop(
                                context,
                                ScheduleItem(
                                  type: _type,
                                  dateTime: _dt!,
                                  note: _noteCtrl.text.trim().isEmpty
                                      ? null
                                      : _noteCtrl.text.trim(),
                                ),
                              );
                            },
                            child: const Text('保存'),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        controller: controller,
                        keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: EdgeInsets.fromLTRB(
                          16,
                          8,
                          16,
                          24 + MediaQuery.of(context).viewInsets.bottom,
                        ),
                        children: [
                          InkWell(
                            onTap: () async {
                              _dismissKeyboard();
                              final picked = await widget.pickType(_type);
                              if (!mounted) return;
                              setState(() {
                                _type = picked;
                                _dirty = true;
                              });
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: '種類',
                                border: OutlineInputBorder(),
                              ),
                              child: Row(
                                children: [
                                  Expanded(child: Text(typeText)),
                                  const Icon(Icons.unfold_more),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          InkWell(
                            onTap: () async {
                              _dismissKeyboard();
                              final picked = await widget.pickDateTime(_dt);
                              if (!mounted || picked == null) return;
                              setState(() {
                                _dt = picked;
                                _dirty = true;
                              });
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: '日時',
                                border: OutlineInputBorder(),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _dt == null ? '未選択' : widget.dtText(_dt!),
                                    ),
                                  ),
                                  const Icon(Icons.calendar_today, size: 18),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _noteCtrl,
                            maxLines: 5,
                            onTapOutside: (_) => _dismissKeyboard(),
                            decoration: const InputDecoration(
                              labelText: 'メモ',
                              border: OutlineInputBorder(),
                              alignLabelWithHint: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String text;
  const _EmptyHint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 10),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.65),
        ),
      ),
    );
  }
}
