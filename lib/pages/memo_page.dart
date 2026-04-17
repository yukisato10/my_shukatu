import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/ad_config.dart';
import '../db/hive_service.dart';
import '../widgets/banner_ad_widget.dart';

class MemoPage extends StatefulWidget {
  const MemoPage({super.key});

  @override
  State<MemoPage> createState() => _MemoPageState();
}

class _MemoPageState extends State<MemoPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late final _box = HiveService.profileBox();

  // 固定項目
  final _intro = TextEditingController();
  final _gakuchika = TextEditingController();
  final _research = TextEditingController();
  final _strengthWeakness = TextEditingController();
  final _intern = TextEditingController();
  final _circle = TextEditingController();
  final _cert = TextEditingController();

  Timer? _debounce;

  static const _kIntro = 'intro';
  static const _kGakuchika = 'gakuchika';
  static const _kResearch = 'research';
  static const _kStrengthWeakness = 'strengthWeakness';
  static const _kIntern = 'intern';
  static const _kCircle = 'circle';
  static const _kCert = 'cert';
  static const _kCustomItems = 'customProfileItemsV1';

  final List<_CustomProfileItem> _customItems = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _intro.text = (_box.get(_kIntro) ?? '') as String;
    _gakuchika.text = (_box.get(_kGakuchika) ?? '') as String;
    _research.text = (_box.get(_kResearch) ?? '') as String;
    _strengthWeakness.text = (_box.get(_kStrengthWeakness) ?? '') as String;
    _intern.text = (_box.get(_kIntern) ?? '') as String;
    _circle.text = (_box.get(_kCircle) ?? '') as String;
    _cert.text = (_box.get(_kCert) ?? '') as String;

    final raw = (_box.get(_kCustomItems) ?? '') as String;
    if (raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List;
        _customItems.clear();
        for (final e in list) {
          final map = Map<String, dynamic>.from(e as Map);
          _customItems.add(
            _CustomProfileItem(
              id: (map['id'] ?? '').toString(),
              titleController: TextEditingController(
                text: (map['title'] ?? '').toString(),
              ),
              contentController: TextEditingController(
                text: (map['content'] ?? '').toString(),
              ),
            ),
          );
        }
      } catch (_) {
        _customItems.clear();
      }
    }
  }

  void _scheduleSave() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _save);
  }

  Future<void> _save() async {
    await _box.put(_kIntro, _intro.text);
    await _box.put(_kGakuchika, _gakuchika.text);
    await _box.put(_kResearch, _research.text);
    await _box.put(_kStrengthWeakness, _strengthWeakness.text);
    await _box.put(_kIntern, _intern.text);
    await _box.put(_kCircle, _circle.text);
    await _box.put(_kCert, _cert.text);

    final customList = _customItems
        .map(
          (e) => {
        'id': e.id,
        'title': e.titleController.text,
        'content': e.contentController.text,
      },
    )
        .toList();

    await _box.put(_kCustomItems, jsonEncode(customList));
  }

  Future<void> _copy(String label, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label をコピーしました'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  int _countText(String text) => text.characters.length;

  void _addCustomItem() {
    _customItems.add(
      _CustomProfileItem(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        titleController: TextEditingController(text: ''),
        contentController: TextEditingController(text: ''),
      ),
    );
    _scheduleSave();
    setState(() {});
  }

  void _removeCustomItem(_CustomProfileItem item) {
    item.dispose();
    _customItems.remove(item);
    _scheduleSave();
    setState(() {});
  }

  Widget _expandItem({
    required String title,
    required IconData icon,
    required TextEditingController controller,
  }) {
    final cs = Theme.of(context).colorScheme;
    final count = _countText(controller.text);

    return Card(
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ExpansionTile(
        leading: Icon(icon, size: 20, color: cs.primary),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
        ),
        subtitle: Text(
          '$count文字',
          style: TextStyle(
            fontSize: 12,
            color: cs.onSurfaceVariant,
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              tooltip: 'コピー',
              onPressed: () => _copy(title, controller.text),
              icon: const Icon(Icons.copy, size: 18),
              visualDensity: VisualDensity.compact,
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withOpacity(0.35),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Text(
              controller.text.trim().isEmpty ? '未入力' : controller.text.trim(),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openEditSheet() async {
    final cs = Theme.of(context).colorScheme;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, modalSetState) {
            void refreshAll() {
              modalSetState(() {});
              if (mounted) setState(() {});
            }

            Widget field({
              required String title,
              required IconData icon,
              required TextEditingController controller,
            }) {
              return Card(
                elevation: 0,
                surfaceTintColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(icon, size: 18, color: cs.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Text(
                            '${_countText(controller.text)}文字',
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: controller,
                        minLines: 3,
                        maxLines: 10,
                        textInputAction: TextInputAction.newline,
                        onChanged: (_) {
                          _scheduleSave();
                          refreshAll();
                        },
                        decoration: InputDecoration(
                          hintText: '$title を入力',
                          isDense: true,
                          filled: true,
                          fillColor:
                          cs.surfaceContainerHighest.withOpacity(0.35),
                          contentPadding: const EdgeInsets.fromLTRB(
                            10,
                            10,
                            10,
                            10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: cs.outlineVariant),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: cs.outlineVariant),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: cs.primary, width: 1.4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            Widget customField(_CustomProfileItem item) {
              final titleCount = _countText(item.titleController.text);
              final contentCount = _countText(item.contentController.text);

              return Card(
                elevation: 0,
                surfaceTintColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.note_alt, size: 18, color: cs.primary),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              '追加項目',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: '削除',
                            onPressed: () {
                              _removeCustomItem(item);
                              modalSetState(() {});
                            },
                            icon: const Icon(Icons.delete_outline, size: 20),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: item.titleController,
                        onChanged: (_) {
                          _scheduleSave();
                          refreshAll();
                        },
                        decoration: InputDecoration(
                          labelText: '項目名',
                          hintText: '例：自己PR、志望業界、逆質問',
                          suffixText: '$titleCount文字',
                          isDense: true,
                          filled: true,
                          fillColor:
                          cs.surfaceContainerHighest.withOpacity(0.35),
                          contentPadding: const EdgeInsets.fromLTRB(
                            10,
                            10,
                            10,
                            10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: cs.outlineVariant),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: cs.outlineVariant),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: cs.primary, width: 1.4),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: item.contentController,
                        minLines: 3,
                        maxLines: 10,
                        textInputAction: TextInputAction.newline,
                        onChanged: (_) {
                          _scheduleSave();
                          refreshAll();
                        },
                        decoration: InputDecoration(
                          labelText: '内容',
                          hintText: '内容を入力',
                          alignLabelWithHint: true,
                          isDense: true,
                          filled: true,
                          fillColor:
                          cs.surfaceContainerHighest.withOpacity(0.35),
                          contentPadding: const EdgeInsets.fromLTRB(
                            10,
                            10,
                            10,
                            10,
                          ),
                          suffixText: '$contentCount文字',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: cs.outlineVariant),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: cs.outlineVariant),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: cs.primary, width: 1.4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            '編集',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            _addCustomItem();
                            modalSetState(() {});
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('項目追加'),
                        ),
                        const SizedBox(width: 4),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('保存'),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(10, 6, 10, 12),
                      children: [
                        field(title: '自己紹介', icon: Icons.person, controller: _intro),
                        field(
                          title: 'ガクチカ',
                          icon: Icons.rocket_launch,
                          controller: _gakuchika,
                        ),
                        field(
                          title: '研究内容',
                          icon: Icons.science,
                          controller: _research,
                        ),
                        field(
                          title: '強み ・ 弱み',
                          icon: Icons.balance,
                          controller: _strengthWeakness,
                        ),
                        field(
                          title: 'インターンシップ経験',
                          icon: Icons.work,
                          controller: _intern,
                        ),
                        field(
                          title: 'サークル ・ 部活動',
                          icon: Icons.groups,
                          controller: _circle,
                        ),
                        field(title: '資格', icon: Icons.verified, controller: _cert),
                        if (_customItems.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              '追加した項目',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          ..._customItems.map(customField),
                        ],
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _debounce?.cancel();

    _intro.dispose();
    _gakuchika.dispose();
    _research.dispose();
    _strengthWeakness.dispose();
    _intern.dispose();
    _circle.dispose();
    _cert.dispose();

    for (final item in _customItems) {
      item.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'プロフィール',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            tooltip: '編集',
            onPressed: _openEditSheet,
            icon: const Icon(Icons.edit),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
          children: [
            _expandItem(title: '自己紹介', icon: Icons.person, controller: _intro),
            _expandItem(
              title: 'ガクチカ',
              icon: Icons.rocket_launch,
              controller: _gakuchika,
            ),
            _expandItem(
              title: '研究内容',
              icon: Icons.science,
              controller: _research,
            ),
            _expandItem(
              title: '強み ・ 弱み',
              icon: Icons.balance,
              controller: _strengthWeakness,
            ),
            _expandItem(
              title: 'インターンシップ経験',
              icon: Icons.work,
              controller: _intern,
            ),
            _expandItem(
              title: 'サークル ・ 部活動',
              icon: Icons.groups,
              controller: _circle,
            ),
            _expandItem(title: '資格', icon: Icons.verified, controller: _cert),

            if (_customItems.isNotEmpty) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Text(
                  '追加項目',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              ..._customItems.map(
                    (item) => _expandItem(
                  title: item.titleController.text.trim().isEmpty
                      ? '無題の項目'
                      : item.titleController.text.trim(),
                  icon: Icons.note_alt,
                  controller: item.contentController,
                ),
              ),
            ],

            const SizedBox(height: 8),
          ],
        ),
      ),
      bottomNavigationBar: AdConfig.adsEnabled && AdConfig.bannerEnabled
          ? BannerAdWidget(
        adUnitId: AdConfig.bannerUnitId,
      )
          : null,
    );
  }
}

class _CustomProfileItem {
  final String id;
  final TextEditingController titleController;
  final TextEditingController contentController;

  _CustomProfileItem({
    required this.id,
    required this.titleController,
    required this.contentController,
  });

  void dispose() {
    titleController.dispose();
    contentController.dispose();
  }
}