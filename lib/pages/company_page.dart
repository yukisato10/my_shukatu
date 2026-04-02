// company_page.dart（フルコード：現代的カードUI＋表示設定BottomSheet＋業界絞り込み＋長押し削除）
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
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

  // 例：選考過程の並び（上ほど優先）
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

  // ★未選択(null)を最後に送る：高→中→低→未選択
  static int _desireRank(dynamic desireLevel) {
    if (desireLevel == null) return 3;

    final name = desireLevel.toString();
    if (name.contains('high')) return 0;
    if (name.contains('mid')) return 1;
    if (name.contains('low')) return 2;
    return 3; // 想定外は未選択扱い
  }

  static String _desireLabel(dynamic desireLevel) {
    if (desireLevel == null) return '未選択';

    final name = desireLevel.toString();
    if (name.contains('high')) return '高';
    if (name.contains('mid')) return '中';
    if (name.contains('low')) return '低';
    return '未選択';
  }

  List<Company> _filtered(List<Company> items) {
    final f = _industryFilter;
    if (f == null || f.trim().isEmpty || f == '全業界') return items;
    return items.where((c) => (c.industry ?? '').trim() == f).toList();
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
        final ar = _desireRank((a as dynamic).desireLevel);
        final br = _desireRank((b as dynamic).desireLevel);
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
        return '志望度：${_desireLabel((c as dynamic).desireLevel)}';
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

  // =====================
  // ★業界ピッカー（BottomSheet）
  // =====================
  Future<String?> _pickIndustrySheet({
    required List<String> industries,
    required String? current, // null = 全業界
  }) async {
    return showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        String? temp = current; // null=全業界
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
                        itemCount: industries.length + 1, // +1 = 全業界
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
    String? tempIndustry = _industryFilter; // null=全業界

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

    if (!mounted) return;
    if (res == null) return;

    setState(() {
      _sortMode = res.sortMode;
      _industryFilter = res.industry; // null=全業界
    });
  }

  @override
  Widget build(BuildContext context) {
    final box = HiveService.companyBox();

    return AdScaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          '企業管理',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            tooltip: '表示設定（並び替え・絞り込み）',
            icon: const Icon(Icons.tune),
            onPressed: () => _openSortFilterSheet(box),
          ),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: box.listenable(),
        builder: (context, Box<Company> b, _) {
          final all = b.values.toList();
          final list = _filtered(all)..sort(_compare);

          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.business_outlined, size: 42),
                    const SizedBox(height: 10),
                    Text(
                      '企業がありません',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '右下の＋から企業を追加してください。',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.color
                            ?.withOpacity(0.75),
                      ),
                    ),
                    // const SizedBox(height: 14),
                    // FilledButton.icon(
                    //   onPressed: () async {
                    //     await Navigator.push(
                    //       context,
                    //       MaterialPageRoute(
                    //         builder: (_) => const CompanyFormPage(),
                    //       ),
                    //     );
                    //   },
                    //   icon: const Icon(Icons.add),
                    //   label: const Text('企業を追加'),
                    // ),
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
      floatingActionButton: FloatingActionButton(
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
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _companyTile(Company c) {
    final industryStr =
    (c.industry == null || c.industry!.trim().isEmpty) ? '業界未設定' : c.industry!.trim();
    final phaseStr = _phaseLabel(c.phase);
    final desireStr = _desireLabel((c as dynamic).desireLevel);

    Color desireColor() {
      switch (desireStr) {
        case '高':
          return Colors.red;
        case '中':
          return Colors.orange;
        case '低':
          return Colors.blueGrey;
        default:
          return Colors.grey;
      }
    }

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => CompanyFormPage(editing: c)),
        );
      },
      onLongPress: () => _deleteCompany(c),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).dividerColor.withOpacity(0.35),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    c.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: desireColor().withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '志望度 $desireStr',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: desireColor(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              industryStr,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.color
                    ?.withOpacity(0.75),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withOpacity(0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    phaseStr,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '更新: ${c.updatedAt.toLocal().toString().substring(0, 10)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.color
                        ?.withOpacity(0.65),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SortFilterResult {
  final CompanySortMode sortMode;
  final String? industry; // null=全業界
  const _SortFilterResult({
    required this.sortMode,
    required this.industry,
  });
}
