import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/ad_scaffold.dart';

class AgentPage extends StatefulWidget {
  const AgentPage({super.key});

  @override
  State<AgentPage> createState() => _AgentPageState();
}

class _AgentPageState extends State<AgentPage>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();

  late Future<QuerySnapshot<Map<String, dynamic>>> _newsFuture;
  late Future<QuerySnapshot<Map<String, dynamic>>> _agentServicesFuture;

  String _selectedNewsCategory = 'すべて';
  String _selectedServiceCategory = 'すべて';
  String _searchText = '';

  @override
  bool get wantKeepAlive => true;

  static const List<String> _newsCategories = [
    'すべて',
    '就活',
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

  @override
  void initState() {
    super.initState();
    _newsFuture = _fetchNews();
    _agentServicesFuture = _fetchAgentServices();
  }

  Future<QuerySnapshot<Map<String, dynamic>>> _fetchNews() {
    return FirebaseFirestore.instance
        .collection('news')
        .orderBy('publishedAt', descending: true)
        .limit(200)
        .get();
  }

  Future<QuerySnapshot<Map<String, dynamic>>> _fetchAgentServices() {
    return FirebaseFirestore.instance
        .collection('agent_services')
        .where('isActive', isEqualTo: true)
        .orderBy('sortOrder')
        .get();
  }

  Future<void> _refreshNews() async {
    setState(() {
      _newsFuture = _fetchNews();
    });
    await _newsFuture;
  }

  Future<void> _refreshAgentServices() async {
    setState(() {
      _agentServicesFuture = _fetchAgentServices();
    });
    await _agentServicesFuture;
  }

  List<JobNewsItem> _filterNews(List<JobNewsItem> newsList) {
    return newsList.where((news) {
      final matchesCategory =
          _selectedNewsCategory == 'すべて' ||
              news.category == _selectedNewsCategory;

      final keyword = _searchText.trim().toLowerCase();

      final matchesSearch =
          keyword.isEmpty ||
              news.title.toLowerCase().contains(keyword) ||
              news.summary.toLowerCase().contains(keyword) ||
              news.category.toLowerCase().contains(keyword) ||
              news.source.toLowerCase().contains(keyword);

      return matchesCategory && matchesSearch;
    }).toList();
  }

  List<AgentServiceItem> _filterServices(List<AgentServiceItem> services) {
    return services.where((service) {
      return _selectedServiceCategory == 'すべて' ||
          service.tags.contains(_selectedServiceCategory);
    }).toList();
  }

  List<String> _buildServiceCategories(List<AgentServiceItem> services) {
    final tagSet = <String>{};

    for (final service in services) {
      for (final tag in service.tags) {
        final trimmedTag = tag.trim();
        if (trimmedTag.isNotEmpty) {
          tagSet.add(trimmedTag);
        }
      }
    }

    return [
      'すべて',
      ...tagSet,
    ];
  }

  List<String> _readServiceTags(Map<String, dynamic> data) {
    final tags = data['tags'];

    if (tags is List) {
      final parsedTags = tags
          .map((tag) => tag.toString().trim())
          .where((tag) => tag.isNotEmpty)
          .toList();

      if (parsedTags.isNotEmpty) {
        return parsedTags;
      }
    }

    final tag1 = (data['tag1'] ?? '').toString().trim();
    final tag2 = (data['tag2'] ?? '').toString().trim();
    final tag3 = (data['tag3'] ?? '').toString().trim();

    final tagFields = [
      tag1,
      tag2,
      tag3,
    ].where((tag) => tag.isNotEmpty).toList();

    if (tagFields.isNotEmpty) {
      return tagFields;
    }

    final oldTag = (data['tag'] ?? data['category'] ?? 'その他')
        .toString()
        .trim();

    if (oldTag.isNotEmpty) {
      return [oldTag];
    }

    return ['その他'];
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return DefaultTabController(
      length: 2,
      child: AdScaffold(
        body: SafeArea(
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TabBar(
                  indicator: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(13),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  dividerColor: Colors.transparent,
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: const Color(0xFF167A7A),
                  unselectedLabelColor: Colors.grey.shade600,
                  labelStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  tabs: const [
                    Tab(text: '就活ニュース'),
                    Tab(text: '就活サービス'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildNewsTab(),
                    _buildAgentTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNewsTab() {
    return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
      future: _newsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: const [_LoadingBox()],
          );
        }

        if (snapshot.hasError) {
          return RefreshIndicator(
            onRefresh: _refreshNews,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                _ErrorBox(message: 'ニュース取得に失敗しました'),
              ],
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        final newsList = docs.map((doc) {
          final data = doc.data();

          return JobNewsItem(
            title: (data['title'] ?? '').toString(),
            summary: (data['summary'] ??
                data['description'] ??
                '概要はありません')
                .toString(),
            category: (data['category'] ?? 'その他').toString(),
            date: _formatTimestamp(data['publishedAt'] ?? data['createdAt']),
            source: (data['source'] ?? '不明').toString(),
            url: (data['url'] ?? '').toString(),
            imageUrl: (data['imageUrl'] ?? '').toString(),
          );
        }).toList();

        final filteredNews = _filterNews(newsList);

        return RefreshIndicator(
          onRefresh: _refreshNews,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              Row(
                children: [
                  const Icon(Icons.article_outlined, size: 22),
                  const SizedBox(width: 8),
                  const Text(
                    '就活ニュース',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${filteredNews.length}件',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _SearchBox(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchText = value;
                  });
                },
                onClear: () {
                  setState(() {
                    _searchController.clear();
                    _searchText = '';
                  });
                },
              ),
              const SizedBox(height: 12),
              _CategoryChips(
                categories: _newsCategories,
                selectedCategory: _selectedNewsCategory,
                onSelected: (category) {
                  setState(() {
                    _selectedNewsCategory = category;
                  });
                },
              ),
              const SizedBox(height: 16),
              if (filteredNews.isEmpty)
                const _EmptyNewsBox()
              else
                ...filteredNews.map(
                      (news) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _NewsCard(news: news),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAgentTab() {
    return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
      future: _agentServicesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: const [_LoadingBox()],
          );
        }

        if (snapshot.hasError) {
          return RefreshIndicator(
            onRefresh: _refreshAgentServices,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                _ErrorBox(message: '就活サービスの取得に失敗しました'),
              ],
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        final services = docs.map((doc) {
          final data = doc.data();

          return AgentServiceItem(
            title: (data['title'] ?? '').toString(),
            description: (data['description'] ?? '').toString(),
            tags: _readServiceTags(data),
            buttonText: (data['buttonText'] ?? '詳しく見る').toString(),
            subText: (data['subText'] ?? '').toString(),
            url: (data['url'] ?? '').toString(),
            imageUrl: (data['imageUrl'] ?? '').toString(),
            imageAspectRatio: _toDouble(
              data['imageAspectRatio'],
              300 / 250,
            ),
          );
        }).toList();

        final serviceCategories = _buildServiceCategories(services);

        if (!serviceCategories.contains(_selectedServiceCategory)) {
          _selectedServiceCategory = 'すべて';
        }

        final filteredServices = _filterServices(services);

        return RefreshIndicator(
          onRefresh: _refreshAgentServices,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              Row(
                children: [
                  const Icon(Icons.support_agent_outlined, size: 22),
                  const SizedBox(width: 8),
                  const Text(
                    '就活サービス',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  const _PrHeaderBadge(),
                ],
              ),
              const SizedBox(height: 14),
              _CategoryChips(
                categories: serviceCategories,
                selectedCategory: _selectedServiceCategory,
                onSelected: (category) {
                  setState(() {
                    _selectedServiceCategory = category;
                  });
                },
              ),
              const SizedBox(height: 16),
              if (filteredServices.isEmpty)
                const _EmptyAgentBox()
              else
                ...filteredServices.map(
                      (agent) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _AgentServiceCard(agent: agent),
                  ),
                ),
              const SizedBox(height: 12),
              const _AgentNoticeBox(),
            ],
          ),
        );
      },
    );
  }
}

class JobNewsItem {
  final String title;
  final String summary;
  final String category;
  final String date;
  final String source;
  final String url;
  final String imageUrl;

  const JobNewsItem({
    required this.title,
    required this.summary,
    required this.category,
    required this.date,
    required this.source,
    required this.url,
    required this.imageUrl,
  });
}

class AgentServiceItem {
  final String title;
  final String description;
  final List<String> tags;
  final String buttonText;
  final String subText;
  final String url;
  final String imageUrl;
  final double imageAspectRatio;

  const AgentServiceItem({
    required this.title,
    required this.description,
    required this.tags,
    required this.buttonText,
    required this.subText,
    required this.url,
    required this.imageUrl,
    required this.imageAspectRatio,
  });
}

class _CategoryChips extends StatelessWidget {
  final List<String> categories;
  final String selectedCategory;
  final ValueChanged<String> onSelected;

  const _CategoryChips({
    required this.categories,
    required this.selectedCategory,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: categories.map((category) {
          final selected = selectedCategory == category;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(category),
              selected: selected,
              onSelected: (_) => onSelected(category),
              showCheckmark: false,
              selectedColor: const Color(0xFFDDF6F6),
              backgroundColor: Colors.grey.shade100,
              side: BorderSide(
                color: selected
                    ? const Color(0xFF2CA6A4)
                    : Colors.grey.shade300,
              ),
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                color:
                selected ? const Color(0xFF167A7A) : Colors.grey.shade700,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SearchBox extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchBox({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'キーワードで検索',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
          onPressed: onClear,
          icon: const Icon(Icons.close),
        ),
        filled: true,
        fillColor: Colors.grey.shade100,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFF2CA6A4),
            width: 1.4,
          ),
        ),
      ),
    );
  }
}

class _NewsCard extends StatelessWidget {
  final JobNewsItem news;

  const _NewsCard({required this.news});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: news.url.trim().isEmpty ? null : () => _openUrl(context, news.url),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: _cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (news.imageUrl.trim().isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    news.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _CategoryBadge(text: news.category),
                if (news.date.isNotEmpty)
                  Text(
                    news.date,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              news.title,
              style: const TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.bold,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              news.summary,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    news.source,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _LinkText(text: 'サイトへ'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AgentServiceCard extends StatelessWidget {
  final AgentServiceItem agent;

  const _AgentServiceCard({required this.agent});

  @override
  Widget build(BuildContext context) {
    final hasImage = agent.imageUrl.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasImage) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: agent.imageAspectRatio,
                child: Image.network(
                  agent.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              const _PrCardBadge(),
              ...agent.tags.map((tag) {
                return _AgentTag(text: tag);
              }),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            agent.title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              height: 1.35,
            ),
          ),
          if (agent.subText.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              agent.subText,
              style: const TextStyle(
                fontSize: 12,
                height: 1.35,
                color: Color(0xFFEA580C),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
          if (agent.description.trim().isNotEmpty) ...[
            const SizedBox(height: 7),
            Text(
              agent.description,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: Colors.grey.shade800,
              ),
            ),
          ],
          const SizedBox(height: 12),

          InkWell(
            onTap: agent.url.trim().isEmpty
                ? null
                : () => _openUrl(context, agent.url),
            borderRadius: BorderRadius.circular(99),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 13,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF167A7A),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    agent.buttonText,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkText extends StatelessWidget {
  final String text;

  const _LinkText({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).primaryColor,
          ),
        ),
        const SizedBox(width: 3),
        Icon(
          Icons.chevron_right,
          size: 18,
          color: Theme.of(context).primaryColor,
        ),
      ],
    );
  }
}

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: Colors.grey.shade200),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.04),
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
    ],
  );
}

class _CategoryBadge extends StatelessWidget {
  final String text;

  const _CategoryBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Color(0xFF2563EB),
        ),
      ),
    );
  }
}

class _AgentTag extends StatelessWidget {
  final String text;

  const _AgentTag({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEDD5),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Color(0xFFEA580C),
        ),
      ),
    );
  }
}

class _PrHeaderBadge extends StatelessWidget {
  const _PrHeaderBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'PR',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade700,
        ),
      ),
    );
  }
}

class _PrCardBadge extends StatelessWidget {
  const _PrCardBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        'PR',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade700,
        ),
      ),
    );
  }
}

class _LoadingBox extends StatelessWidget {
  const _LoadingBox();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;

  const _ErrorBox({
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EmptyNewsBox extends StatelessWidget {
  const _EmptyNewsBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: Text(
          '該当するニュースがありません',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _EmptyAgentBox extends StatelessWidget {
  const _EmptyAgentBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: Text(
          '掲載中の就活サービスがありません',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _AgentNoticeBox extends StatelessWidget {
  const _AgentNoticeBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        '※ このページには広告・プロモーションが含まれます。サービスをタップすると外部サイトで開きます。',
        style: TextStyle(
          fontSize: 12,
          height: 1.45,
          color: Colors.grey.shade700,
        ),
      ),
    );
  }
}

String _formatTimestamp(dynamic timestamp) {
  if (timestamp == null) return '';

  try {
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
    }

    if (timestamp is String) {
      final date = DateTime.tryParse(timestamp);
      if (date == null) return '';
      return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
    }

    return '';
  } catch (_) {
    return '';
  }
}

double _toDouble(dynamic value, double defaultValue) {
  if (value == null) return defaultValue;

  if (value is int) {
    return value.toDouble();
  }

  if (value is double) {
    return value;
  }

  if (value is num) {
    return value.toDouble();
  }

  if (value is String) {
    return double.tryParse(value) ?? defaultValue;
  }

  return defaultValue;
}

Future<void> _openUrl(BuildContext context, String url) async {
  if (url.trim().isEmpty) return;

  final uri = Uri.tryParse(url);

  if (uri == null || !uri.hasScheme) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('URLが正しくありません')),
    );
    return;
  }

  if (!await canLaunchUrl(uri)) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ページを開けませんでした')),
    );
    return;
  }

  await launchUrl(
    uri,
    mode: LaunchMode.externalApplication,
  );
}