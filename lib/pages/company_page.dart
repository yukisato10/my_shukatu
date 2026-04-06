import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/ad_scaffold.dart';
import '../db/hive_service.dart';
import '../models/company.dart';
import 'company_form_page.dart';

enum CompanySortMode {
  updatedAt,
  industry,
  desire,
  phase,
}

class CompanyPage extends StatefulWidget {
  const CompanyPage({super.key});

  @override
  State<CompanyPage> createState() => _CompanyPageState();
}

class _CompanyPageState extends State<CompanyPage> {
  String? _industryFilter; // null = 全業界
  CompanySortMode _sortMode = CompanySortMode.updatedAt;

  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  bool _searchMode = false;

  static const List<SelectionPhase> _phaseOrderTop = [
    SelectionPhase.offer,
    SelectionPhase.finalInterview,
    SelectionPhase.interview4,
    SelectionPhase.interview3,
    SelectionPhase.interview2,
    SelectionPhase.interview1,
    SelectionPhase.gd,
    SelectionPhase.webTest,
    SelectionPhase.es,
    SelectionPhase.entry,
    SelectionPhase.notApplied,
    SelectionPhase.declined,
    SelectionPhase.rejected,
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  static int _phaseRank(SelectionPhase p) {
    final idx = _phaseOrderTop.indexOf(p);
    return idx >= 0 ? idx : 999;
  }

  static String _phaseLabel(SelectionPhase p) {
    const m = {
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
    return m[p] ?? p.name;
  }

  static int _desireRank(DesireLevel? desireLevel) {
    switch (desireLevel) {
      case DesireLevel.high:
        return 0;
      case DesireLevel.mid:
        return 1;
      case DesireLevel.low:
        return 2;
      case null:
        return 3;
    }
  }

  static String _desireLabel(DesireLevel? desireLevel) {
    switch (desireLevel) {
      case DesireLevel.high:
        return '高';
      case DesireLevel.mid:
        return '中';
      case DesireLevel.low:
        return '低';
      case null:
        return '未選択';
    }
  }

  List<Company> _filtered(List<Company> items) {
    final f = _industryFilter;
    final q = _searchCtrl.text.trim().toLowerCase();

    return items.where((c) {
      final industryOk = (f == null || f.trim().isEmpty || f == '全業界')
          ? true
          : (c.industry ?? '').trim() == f;

      if (!industryOk) return false;

      if (q.isEmpty) return true;

      final name = c.name.toLowerCase();
      final industry = (c.industry ?? '').toLowerCase();
      final phase = _phaseLabel(c.phase).toLowerCase();
      final desire = _desireLabel(c.desireLevel).toLowerCase();
      final url = (c.mypageUrl ?? '').toLowerCase();
      final id = (c.mypageid ?? '').toLowerCase();
      final pass = (c.mypagePassword ?? '').toLowerCase();

      return name.contains(q) ||
          industry.contains(q) ||
          phase.contains(q) ||
          desire.contains(q) ||
          url.contains(q) ||
          id.contains(q) ||
          pass.contains(q);
    }).toList();
  }

  int _compare(Company a, Company b) {
    switch (_sortMode) {
      case CompanySortMode.updatedAt:
        return b.updatedAt.compareTo(a.updatedAt);

      case CompanySortMode.industry:
        final ai = (a.industry ?? '業界未設定').trim();
        final bi = (b.industry ?? '業界未設定').trim();
        final c1 = ai.compareTo(bi);
        if (c1 != 0) return c1;
        return a.name.compareTo(b.name);

      case CompanySortMode.desire:
        final ar = _desireRank(a.desireLevel);
        final br = _desireRank(b.desireLevel);
        final c1 = ar.compareTo(br);
        if (c1 != 0) return c1;

        final c2 = _phaseRank(a.phase).compareTo(_phaseRank(b.phase));
        if (c2 != 0) return c2;

        final c3 = b.updatedAt.compareTo(a.updatedAt);
        if (c3 != 0) return c3;

        return a.name.compareTo(b.name);

      case CompanySortMode.phase:
        final c1 = _phaseRank(a.phase).compareTo(_phaseRank(b.phase));
        if (c1 != 0) return c1;

        final c2 = b.updatedAt.compareTo(a.updatedAt);
        if (c2 != 0) return c2;

        return a.name.compareTo(b.name);
    }
  }

  String _sectionKey(Company c) {
    switch (_sortMode) {
      case CompanySortMode.updatedAt:
        return '';
      case CompanySortMode.industry:
        final s = (c.industry ?? '').trim();
        return s.isEmpty ? '業界未設定' : s;
      case CompanySortMode.desire:
        return '志望度：${_desireLabel(c.desireLevel)}';
      case CompanySortMode.phase:
        return _phaseLabel(c.phase);
    }
  }

  String _sortLabel(CompanySortMode m) {
    switch (m) {
      case CompanySortMode.updatedAt:
        return '更新順';
      case CompanySortMode.industry:
        return '業界順';
      case CompanySortMode.desire:
        return '志望度順';
      case CompanySortMode.phase:
        return '選考過程順';
    }
  }

  String _normalizeUrl(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return '';
    if (text.startsWith('http://') || text.startsWith('https://')) {
      return text;
    }
    return 'https://$text';
  }

  Future<void> _openMyPage(String url) async {
    final normalized = _normalizeUrl(url);
    if (normalized.isEmpty) return;

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

  Future<void> _copyText(String text, String label) async {
    if (text.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$labelをコピーしました'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _deleteCompany(Company c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('企業を削除'),
        content: Text('「${c.name}」を削除しますか？\nこの操作は元に戻せません。'),
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

    final companyName = c.name;
    await c.delete();

    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('「$companyName」を削除しました'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<String?> _pickIndustrySheet({
    required List<String> industries,
    required String? current,
  }) async {
    return showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        String? temp = current;
        return StatefulBuilder(
          builder: (ctx, setS) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  16 + MediaQuery.of(ctx).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          '業界で絞り込み',
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
                        itemCount: industries.length + 1,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final val = (i == 0) ? null : industries[i - 1];
                          final label = (i == 0) ? '全業界' : industries[i - 1];
                          final selected = temp == val;

                          return ListTile(
                            dense: true,
                            title: Text(label, style: const TextStyle(fontSize: 13)),
                            trailing: selected ? const Icon(Icons.check) : null,
                            onTap: () => setS(() => temp = val),
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

  Future<void> _openSortFilterSheet(Box<Company> box) async {
    final industries = box.values
        .map((e) => (e.industry ?? '').trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    CompanySortMode tempSort = _sortMode;
    String? tempIndustry = _industryFilter;

    final res = await showModalBottomSheet<_SortFilterResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            String industrySubtitle() {
              final v = tempIndustry;
              if (v == null || v.trim().isEmpty || v == '全業界') return '全業界';
              return v;
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
                      '表示設定',
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('並び替え', style: Theme.of(ctx).textTheme.titleSmall),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: CompanySortMode.values.map((m) {
                        final selected = tempSort == m;
                        return ChoiceChip(
                          label: Text(_sortLabel(m)),
                          selected: selected,
                          onSelected: (_) => setModalState(() => tempSort = m),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    Text('業界で絞り込み', style: Theme.of(ctx).textTheme.titleSmall),
                    const SizedBox(height: 6),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('業界'),
                      subtitle: Text(
                        industrySubtitle(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        final picked = await _pickIndustrySheet(
                          industries: industries,
                          current: (tempIndustry == null ||
                              tempIndustry == '全業界' ||
                              (tempIndustry?.trim().isEmpty ?? true))
                              ? null
                              : tempIndustry,
                        );
                        if (!mounted) return;
                        setModalState(() => tempIndustry = picked);
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            setModalState(() {
                              tempSort = CompanySortMode.updatedAt;
                              tempIndustry = null;
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
                          onPressed: () {
                            Navigator.pop(
                              ctx,
                              _SortFilterResult(
                                sortMode: tempSort,
                                industry: tempIndustry,
                              ),
                            );
                          },
                          child: const Text('適用'),
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

    if (!mounted || res == null) return;

    setState(() {
      _sortMode = res.sortMode;
      _industryFilter = res.industry;
    });
  }

  void _enterSearchMode() {
    setState(() {
      _searchMode = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocus.requestFocus();
      }
    });
  }

  void _exitSearchMode() {
    setState(() {
      _searchMode = false;
      _searchCtrl.clear();
    });
    _searchFocus.unfocus();
  }

  PreferredSizeWidget _buildAppBar(Box<Company> box) {
    if (_searchMode) {
      return AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: _exitSearchMode,
        ),
        titleSpacing: 0,
        title: Container(
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(14),
          ),
          child: TextField(
            controller: _searchCtrl,
            focusNode: _searchFocus,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: '企業名 ・ 業界 で検索',
              border: InputBorder.none,
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _searchCtrl.text.isEmpty
                  ? null
                  : IconButton(
                tooltip: 'クリア',
                onPressed: () {
                  _searchCtrl.clear();
                  setState(() {});
                },
                icon: const Icon(Icons.close_rounded, size: 18),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
      );
    }

    return AppBar(
      centerTitle: true,
      elevation: 0,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      title: const Text(
        '企業管理',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 18,
          color: Colors.black,
        ),
      ),
      actions: [
        IconButton(
          tooltip: '企業検索',
          icon: const Icon(Icons.search_rounded),
          onPressed: _enterSearchMode,
        ),
        IconButton(
          tooltip: '表示設定',
          icon: const Icon(Icons.tune_rounded),
          onPressed: () => _openSortFilterSheet(box),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final box = HiveService.companyBox();

    return AdScaffold(
      appBar: _buildAppBar(box),
      body: Container(
        color: const Color(0xFFF7F8FA),
        child: ValueListenableBuilder(
          valueListenable: box.listenable(),
          builder: (context, Box<Company> b, _) {
            final all = b.values.toList();
            final list = _filtered(all)..sort(_compare);

            if (list.isEmpty) {
              final isSearch = _searchCtrl.text.trim().isNotEmpty;

              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSearch ? Icons.search_off_rounded : Icons.business_outlined,
                        size: 42,
                        color: Colors.black.withOpacity(0.55),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        isSearch ? '検索結果がありません' : '企業がありません',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isSearch ? '検索条件を変えてください。' : '右下の＋から企業を追加してください。',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.black.withOpacity(0.55),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (_sortMode == CompanySortMode.updatedAt) {
              return _buildFlatList(list);
            }
            return _buildSectionedList(list);
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        elevation: 1,
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CompanyFormPage()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildFlatList(List<Company> list) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: list.length,
      itemBuilder: (context, i) => _companyTile(list[i]),
    );
  }

  Widget _buildSectionedList(List<Company> list) {
    final rows = <Widget>[];
    String? currentKey;

    for (final c in list) {
      final key = _sectionKey(c);
      if (currentKey != key) {
        currentKey = key;
        rows.add(_sectionHeader(key));
      }
      rows.add(_companyTile(c));
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: rows,
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w800,
          color: Colors.black.withOpacity(0.72),
        ),
      ),
    );
  }

  Widget _modernTag({
    required String text,
    required Color fg,
    required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          height: 1,
          fontWeight: FontWeight.w800,
          color: fg,
        ),
      ),
    );
  }

  Widget _primaryActionButton({
    required String label,
    required IconData icon,
    required bool enabled,
    required VoidCallback? onTap,
  }) {
    final primary = Theme.of(context).colorScheme.primary;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      height: 38,
      decoration: BoxDecoration(
        color: enabled ? primary.withOpacity(0.10) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 17,
                color: enabled ? primary : Colors.grey,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: enabled ? primary : Colors.grey,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniActionButton({
    required IconData icon,
    required String tooltip,
    required bool enabled,
    required VoidCallback? onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: enabled ? const Color(0xFFF5F7FA) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Icon(
              icon,
              size: 18,
              color: enabled ? const Color(0xFF4B5563) : Colors.grey.shade400,
            ),
          ),
        ),
      ),
    );
  }

  Widget _companyTile(Company c) {
    final industryStr =
    (c.industry == null || c.industry!.trim().isEmpty) ? '業界未設定' : c.industry!.trim();
    final phaseStr = _phaseLabel(c.phase);
    final desireStr = _desireLabel(c.desireLevel);

    final mypageUrl = (c.mypageUrl ?? '').trim();
    final mypageId = (c.mypageid ?? '').trim();
    final mypagePassword = (c.mypagePassword ?? '').trim();

    Color desireColor() {
      switch (c.desireLevel) {
        case DesireLevel.high:
          return const Color(0xFFFF6B6B);
        case DesireLevel.mid:
          return const Color(0xFFFFB84D);
        case DesireLevel.low:
          return const Color(0xFF7A8CA5);
        case null:
          return const Color(0xFF9AA3AF);
      }
    }

    final primaryColor = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => CompanyFormPage(editing: c)),
            );
          },
          onLongPress: () => _deleteCompany(c),
          child: Ink(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: Colors.black.withOpacity(0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// 上段
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              industryStr,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.black.withOpacity(0.55),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _modernTag(
                        text: '志望度 $desireStr',
                        fg: desireColor(),
                        bg: desireColor().withOpacity(0.12),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  /// 下段
                  Row(
                    children: [
                      _modernTag(
                        text: phaseStr,
                        fg: primaryColor,
                        bg: primaryColor.withOpacity(0.10),
                      ),
                      const Spacer(),

                      SizedBox(
                        width: 110, // ← ここで幅を固定
                        child: _primaryActionButton(
                          label: 'マイページ',
                          icon: Icons.open_in_new_rounded,
                          enabled: mypageUrl.isNotEmpty,
                          onTap: mypageUrl.isEmpty ? null : () => _openMyPage(mypageUrl),
                        ),
                      ),
                      const SizedBox(width: 6),

                      _miniActionButton(
                        icon: Icons.badge_outlined,
                        tooltip: 'IDコピー',
                        enabled: mypageId.isNotEmpty,
                        onTap: mypageId.isEmpty ? null : () => _copyText(mypageId, 'ID'),
                      ),
                      const SizedBox(width: 6),

                      _miniActionButton(
                        icon: Icons.key_rounded,
                        tooltip: 'PWコピー',
                        enabled: mypagePassword.isNotEmpty,
                        onTap: mypagePassword.isEmpty
                            ? null
                            : () => _copyText(mypagePassword, 'パスワード'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SortFilterResult {
  final CompanySortMode sortMode;
  final String? industry;

  const _SortFilterResult({
    required this.sortMode,
    required this.industry,
  });
}
