part of '../main.dart';

bool isRotatingAdvisoryMedia(String? mediaKind, String? mediaUrl) {
  if (mediaUrl == null || mediaUrl.trim().isEmpty) return false;
  final kind = (mediaKind ?? '').toLowerCase();
  final extension =
      Uri.tryParse(mediaUrl)?.path.split('.').last.toLowerCase() ?? '';
  const videoExtensions = {'mp4', 'mov', 'm4v', 'webm', 'mkv'};
  if (kind == 'video' || videoExtensions.contains(extension)) return false;
  if (kind == 'gif' || kind == 'photo' || kind == 'image') return true;
  return kind.isEmpty &&
      const {'gif', 'jpg', 'jpeg', 'png', 'webp', 'avif'}.contains(extension);
}

String _newsDate(String? value) {
  final date = DateTime.tryParse(value ?? '')?.toLocal();
  if (date == null) return '';
  final now = DateTime.now();
  final dateOnly = DateTime(date.year, date.month, date.day);
  final today = DateTime(now.year, now.month, now.day);
  final dayLabel = switch (today.difference(dateOnly).inDays) {
    0 => 'Today',
    1 => 'Yesterday',
    _ => '${_newsMonth(date.month)} ${date.day}',
  };
  final hour = date.hour == 0
      ? 12
      : date.hour > 12
      ? date.hour - 12
      : date.hour;
  final minute = date.minute.toString().padLeft(2, '0');
  return '$dayLabel  ·  $hour:$minute ${date.hour >= 12 ? 'PM' : 'AM'}';
}

String _newsMonth(int month) => const [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
][month - 1];

class NewsPage extends StatefulWidget {
  const NewsPage({super.key});

  @override
  State<NewsPage> createState() => _NewsPageState();
}

class _NewsPageState extends State<NewsPage> {
  static const _initialIssueLimit = 10;

  final _pageController = PageController();
  Timer? _rotationTimer;
  int _currentPage = 0;
  String _selectedReportCategory = 'All';
  String _selectedAdvisoryCategory = 'All';
  bool _showAllIssues = false;
  List<Map<String, dynamic>> _advisories = [];
  List<Map<String, dynamic>> _issues = [];
  bool _loading = true;
  String? _loadError;

  Future<void> refresh() => _loadNews();

  @override
  void initState() {
    super.initState();
    _loadNews();
    _rotationTimer = Timer.periodic(const Duration(seconds: 7), (_) {
      if (!mounted ||
          !_pageController.hasClients ||
          _stories.length < 2 ||
          WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
        return;
      }
      final shell = context.findAncestorStateOfType<_MainShellState>();
      if (shell != null && shell.index != 3) return;
      _pageController.animateToPage(
        (_currentPage + 1) % _stories.length,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _loadNews() async {
    try {
      final results = await Future.wait([
        ApiService.advisories(),
        ApiService.issues(verifiedOnly: true),
      ]);
      if (!mounted) return;
      setState(() {
        _advisories = results[0];
        _issues = results[1];
        _currentPage = 0;
        _loading = false;
        _loadError = null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageController.hasClients) _pageController.jumpToPage(0);
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = 'Could not load city updates from the server.';
        });
      }
    }
  }

  List<({String image, String title, String subtitle, String date})>
  get _stories => _advisories
      .map((advisory) {
        final mediaUrl = publicMediaUrl(advisory['media_url'] as String?);
        if (mediaUrl == null ||
            !isRotatingAdvisoryMedia(
              advisory['media_kind'] as String?,
              mediaUrl,
            )) {
          return null;
        }
        return (
          image: mediaUrl,
          title: advisory['title'] as String? ?? 'City advisory',
          subtitle: _advisoryType(advisory['type'] as String?),
          date: _newsDate(
            advisory['published_at']?.toString() ??
                advisory['created_at']?.toString(),
          ),
        );
      })
      .whereType<({String image, String title, String subtitle, String date})>()
      .toList();

  String _advisoryType(String? type) => switch (type?.toLowerCase()) {
    'alert' => 'Advertisement',
    'maint' => 'Maintenance advisory',
    _ => 'City announcement',
  };

  List<Map<String, dynamic>> get _visibleIssues => _issues.where((issue) {
    final status = (issue['status'] as String? ?? '').toLowerCase().trim();
    final category = issue['category'] as String? ?? '';
    if (!const {
      'verified by inspector',
      'approved',
      'in progress',
      'resolved',
    }.contains(status)) {
      return false;
    }
    return switch (_selectedReportCategory) {
      'Roads' => normalizeReportCategory(category) == 'Roads',
      'Public Buildings' =>
        normalizeReportCategory(category) == 'Public Buildings',
      'Streetlights' => normalizeReportCategory(category) == 'Streetlights',
      'Electric Poles' => normalizeReportCategory(category) == 'Electric Poles',
      'Drainage' => normalizeReportCategory(category) == 'Drainage',
      'Resolved' => status == 'resolved',
      _ => true,
    };
  }).toList();

  List<Map<String, dynamic>> get _visibleAdvisories =>
      _advisories.where((advisory) {
        final type = (advisory['type'] as String? ?? '').toLowerCase();
        return switch (_selectedAdvisoryCategory) {
          'Advertisement' => type == 'alert' || type == 'advertisement',
          'Maintenance' => type == 'maint',
          'Announcements' => type != 'alert' && type != 'maint',
          _ => true,
        };
      }).toList();

  @override
  void dispose() {
    _rotationTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PageEntrance(
    child: Builder(
      builder: (context) {
        final visibleIssues = _visibleIssues;
        final displayedIssues = _showAllIssues
            ? visibleIssues
            : visibleIssues.take(_initialIssueLimit).toList();
        return AppScroll(
          onRefresh: _loadNews,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppHeader(
                eyebrow: 'MATI CITY · COMMUNITY INFORMATION',
                title: 'City updates',
                subtitle:
                    'Local reports and official notices, all in one place.',
              ),
              if (!_loading && _stories.isNotEmpty)
                _NewsHeroCarousel(
                  stories: _stories,
                  controller: _pageController,
                  currentPage: _currentPage,
                  onPageChanged: (page) => setState(() => _currentPage = page),
                ),
              if (!_loading && _stories.isEmpty)
                const _NewsFeaturePlaceholder(),
              const SizedBox(height: 14),
              _NewsSectionHeading(
                eyebrow: 'COMMUNITY FEED',
                title: 'Report updates',
                count: _loading ? null : visibleIssues.length,
                icon: Icons.location_city_outlined,
              ),
              const SizedBox(height: 5),
              _NewsFilterBar(
                selectedCategory: _selectedReportCategory,
                categories: const [
                  'All',
                  'Roads',
                  'Public Buildings',
                  'Streetlights',
                  'Electric Poles',
                  'Drainage',
                  'Resolved',
                ],
                onCategorySelected: (category) => setState(() {
                  _selectedReportCategory = category;
                  _showAllIssues = false;
                }),
              ),
              const SizedBox(height: 18),
              if (_loading)
                const _NewsPageSkeleton()
              else if (_loadError != null)
                LoadErrorPanel(message: _loadError!, onRetry: _loadNews)
              else ...[
                if (visibleIssues.isEmpty)
                  _NewsEmptyState(
                    icon: Icons.inbox_outlined,
                    title: _issues.isEmpty
                        ? 'No verified report updates yet'
                        : 'No reports in this category',
                    message: _issues.isEmpty
                        ? 'Reports appear here after the city team verifies them.'
                        : 'Choose another category to see more local report updates.',
                  ),
                for (final issue in displayedIssues)
                  _ReportUpdateCard(
                    icon: _issueIcon(issue),
                    title: issue['title'] as String? ?? 'Infrastructure report',
                    body:
                        '${issue['status'] ?? 'Reported'} · ${issue['location'] ?? 'Mati City'}',
                    color: _issueColor(issue),
                    status: issue['status'] as String? ?? 'Reported',
                    location: issue['location'] as String? ?? 'Mati City',
                    date: _newsDate(issue['created_at']?.toString()),
                  ),
                if (!_showAllIssues &&
                    visibleIssues.length > _initialIssueLimit)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2, bottom: 18),
                      child: TextButton.icon(
                        key: const ValueKey('seeAllReportUpdates'),
                        onPressed: () => setState(() => _showAllIssues = true),
                        icon: const Icon(Icons.expand_more_rounded),
                        label: Text(
                          'See all previous reports (${visibleIssues.length - _initialIssueLimit})',
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: navy,
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                _NewsSectionHeading(
                  eyebrow: 'OFFICIAL BULLETINS',
                  title: 'City advisories',
                  count: _visibleAdvisories.length,
                  icon: Icons.campaign_outlined,
                ),
                const SizedBox(height: 5),
                _NewsFilterBar(
                  selectedCategory: _selectedAdvisoryCategory,
                  categories: const [
                    'All',
                    'Advertisement',
                    'Maintenance',
                    'Announcements',
                  ],
                  onCategorySelected: (category) =>
                      setState(() => _selectedAdvisoryCategory = category),
                  isAdvisory: true,
                ),
                const SizedBox(height: 12),
                if (_visibleAdvisories.isEmpty)
                  _NewsEmptyState(
                    icon: Icons.notifications_none_rounded,
                    title: _advisories.isEmpty
                        ? 'No current advisories'
                        : 'No advisories in this category',
                    message: _advisories.isEmpty
                        ? 'Official notices from the LGU will appear here when published.'
                        : 'Try another advisory type to see more official updates.',
                  )
                else
                  ..._visibleAdvisories.map(
                    (advisory) => _PublicAdvisoryCard(advisory: advisory),
                  ),
              ],
            ],
          ),
        );
      },
    ),
  );

  Color _issueColor(Map<String, dynamic> issue) {
    switch ((issue['severity'] as String? ?? '').toLowerCase()) {
      case 'critical':
        return red;
      case 'high':
        return clay;
      case 'medium':
        return amber;
      default:
        return teal;
    }
  }

  IconData _issueIcon(Map<String, dynamic> issue) {
    switch ((issue['category'] as String? ?? '').toLowerCase()) {
      case 'public buildings':
      case 'public building':
        return Icons.apartment_rounded;
      case 'drainage':
        return Icons.water_damage_outlined;
      case 'lighting':
      case 'streetlights':
        return Icons.lightbulb_outline;
      case 'electric poles':
      case 'electric pole':
        return Icons.electric_bolt_rounded;
      default:
        return Icons.construction;
    }
  }
}

class _NewsPageSkeleton extends StatelessWidget {
  const _NewsPageSkeleton();

  @override
  Widget build(BuildContext context) => SkeletonShimmer(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ReportFeedSkeleton(count: 3, animated: false),
        const SizedBox(height: 14),
        const Row(
          children: [
            SkeletonBlock(height: 38, width: 38, radius: 13),
            SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBlock(height: 9, width: 106, radius: 5),
                  SizedBox(height: 5),
                  SkeletonBlock(height: 17, width: 138, radius: 7),
                ],
              ),
            ),
            SkeletonBlock(height: 26, width: 30, radius: 13),
          ],
        ),
        const SizedBox(height: 13),
        const Row(
          children: [
            SkeletonBlock(height: 36, width: 72, radius: 18),
            SizedBox(width: 8),
            SkeletonBlock(height: 36, width: 98, radius: 18),
            SizedBox(width: 8),
            SkeletonBlock(height: 36, width: 112, radius: 18),
          ],
        ),
        const SizedBox(height: 13),
        const NewsFeedSkeleton(count: 2, animated: false),
      ],
    ),
  );
}

class _NewsSectionHeading extends StatelessWidget {
  const _NewsSectionHeading({
    required this.eyebrow,
    required this.title,
    required this.count,
    required this.icon,
  });

  final String eyebrow;
  final String title;
  final int? count;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: teal.withValues(alpha: .11),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(icon, color: teal, size: 20),
      ),
      const SizedBox(width: 11),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              eyebrow,
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF75D5CF)
                    : teal,
                fontSize: 8.5,
                letterSpacing: .9,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: infraHeading(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFFEAF6F4)
                    : navy,
                fontSize: 16,
                weight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
      Container(
        constraints: const BoxConstraints(minWidth: 30, minHeight: 26),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF173F4D)
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF345A63)
                : line,
          ),
        ),
        child: count == null
            ? const SkeletonBlock(height: 11, width: 11, radius: 6)
            : Text(
                '$count',
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFFEAF6F4)
                      : navy,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
      ),
    ],
  );
}

class _NewsFeaturePlaceholder extends StatelessWidget {
  const _NewsFeaturePlaceholder();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    height: 176,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [deepNavy, teal],
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
      ),
      borderRadius: BorderRadius.circular(20),
    ),
    child: const Row(
      children: [
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'YOUR COMMUNITY, IN FOCUS',
                style: TextStyle(
                  color: Color(0xFFB9E0E2),
                  fontSize: 9,
                  letterSpacing: .9,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Stay informed.\nMake a difference.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Updates from around Mati City.',
                style: TextStyle(color: Colors.white70, fontSize: 10.5),
              ),
            ],
          ),
        ),
        SizedBox(width: 10),
        Icon(Icons.location_city_rounded, color: Color(0x667FE0D2), size: 50),
      ],
    ),
  );
}

class _NewsEmptyState extends StatelessWidget {
  const _NewsEmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.fromLTRB(16, 17, 16, 17),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .82),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: line.withValues(alpha: .8)),
    ),
    child: Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: teal.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: teal, size: 21),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: infraHeading(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFFEAF6F4)
                      : navy,
                  fontSize: 13,
                  weight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                message,
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFFB2C9CC)
                      : inkSoft,
                  fontSize: 10.5,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ReportUpdateCard extends StatelessWidget {
  const _ReportUpdateCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.color,
    required this.date,
    this.status,
    this.location,
  });

  final IconData icon;
  final String title;
  final String body;
  final Color color;
  final String date;
  final String? status;
  final String? location;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: line.withValues(alpha: .8)),
      boxShadow: [
        BoxShadow(
          color: navy.withValues(alpha: .035),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .11),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: infraHeading(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFFEAF6F4)
                      : ink,
                  fontSize: 13,
                  weight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  StatusPill(label: status ?? body, color: color),
                  if (location != null) ...[
                    const SizedBox(width: 7),
                    const Icon(
                      Icons.location_on_outlined,
                      color: inkSoft,
                      size: 13,
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        location!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFFB2C9CC)
                              : inkSoft,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (date.isNotEmpty) ...[
                const SizedBox(height: 7),
                Row(
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      size: 12,
                      color: inkSoft,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      date,
                      style: const TextStyle(color: inkSoft, fontSize: 9.5),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

class _PublicAdvisoryCard extends StatelessWidget {
  const _PublicAdvisoryCard({required this.advisory});

  final Map<String, dynamic> advisory;

  @override
  Widget build(BuildContext context) {
    final type = (advisory['type'] as String? ?? 'gen').toLowerCase();
    final color = switch (type) {
      'alert' || 'advertisement' => clay,
      'maint' => teal,
      _ => navy,
    };
    final label = switch (type) {
      'alert' || 'advertisement' => 'ADVERTISEMENT',
      'maint' => 'MAINTENANCE',
      _ => 'CITY ANNOUNCEMENT',
    };
    final icon = switch (type) {
      'alert' || 'advertisement' => Icons.local_offer_outlined,
      'maint' => Icons.build_outlined,
      _ => Icons.campaign_outlined,
    };
    final mediaUrl = publicMediaUrl(advisory['media_url'] as String?);
    final mediaKind = advisory['media_kind'] as String?;
    final date = _newsDate(
      advisory['published_at']?.toString() ??
          advisory['created_at']?.toString(),
    );
    final audienceValue =
        advisory['barangay'] as String? ??
        advisory['audience'] as String? ??
        'Mati City-wide';
    final audience = audienceValue.toLowerCase() == 'all barangays'
        ? 'Mati City-wide'
        : audienceValue;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(19),
        side: const BorderSide(color: line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (mediaUrl != null) _AdvisoryMedia(url: mediaUrl, kind: mediaKind),
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 14, 15, 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: .1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, color: color, size: 13),
                          const SizedBox(width: 5),
                          Text(
                            label,
                            style: TextStyle(
                              color: color,
                              fontSize: 8.5,
                              letterSpacing: .55,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    if (mediaKind != null)
                      Icon(
                        mediaKind == 'video'
                            ? Icons.play_circle_outline_rounded
                            : Icons.photo_outlined,
                        color: inkSoft,
                        size: 17,
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  advisory['title'] as String? ?? 'City advisory',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: infraHeading(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFFEAF6F4)
                        : navy,
                    fontSize: 15,
                    weight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  advisory['message'] as String? ?? '',
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFFB2C9CC)
                        : inkSoft,
                    fontSize: 11.5,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: line),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      color: teal,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        audience,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFFB2C9CC)
                              : inkSoft,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (date.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.schedule_rounded,
                        color: inkSoft,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        date,
                        style: const TextStyle(color: inkSoft, fontSize: 9),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdvisoryMedia extends StatefulWidget {
  const _AdvisoryMedia({required this.url, required this.kind});

  final String url;
  final String? kind;

  @override
  State<_AdvisoryMedia> createState() => _AdvisoryMediaState();
}

class _AdvisoryMediaState extends State<_AdvisoryMedia> {
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    if (widget.kind == 'video') {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
        ..initialize().then((_) {
          if (mounted) setState(() {});
        });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.kind == 'gif') {
      return SizedBox(
        height: 170,
        width: double.infinity,
        child: ClipRect(
          child: Image.network(
            widget.url,
            width: double.infinity,
            height: 170,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            gaplessPlayback: true,
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              if (wasSynchronouslyLoaded || frame != null) return child;
              return const SkeletonShimmer(
                child: SkeletonBlock(
                  height: 170,
                  width: double.infinity,
                  radius: 0,
                ),
              );
            },
            errorBuilder: (_, _, _) => const ColoredBox(
              color: deepNavy,
              child: Center(
                child: Icon(Icons.broken_image_outlined, color: Colors.white),
              ),
            ),
          ),
        ),
      );
    }
    if (widget.kind != 'video') {
      return Image.network(
        widget.url,
        height: 170,
        width: double.infinity,
        fit: BoxFit.cover,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded || frame != null) return child;
          return const SkeletonShimmer(
            child: SkeletonBlock(
              height: 170,
              width: double.infinity,
              radius: 0,
            ),
          );
        },
        errorBuilder: (_, _, _) => const SizedBox(
          height: 170,
          child: ColoredBox(
            color: deepNavy,
            child: Center(
              child: Icon(Icons.broken_image_outlined, color: Colors.white),
            ),
          ),
        ),
      );
    }
    if (_controller == null || !_controller!.value.isInitialized) {
      return const SkeletonShimmer(
        child: SkeletonBlock(height: 150, width: double.infinity, radius: 0),
      );
    }
    return AspectRatio(
      aspectRatio: _controller!.value.aspectRatio,
      child: Stack(
        alignment: Alignment.center,
        children: [
          VideoPlayer(_controller!),
          IconButton.filled(
            onPressed: () => setState(
              () => _controller!.value.isPlaying
                  ? _controller!.pause()
                  : _controller!.play(),
            ),
            icon: Icon(
              _controller!.value.isPlaying ? Icons.pause : Icons.play_arrow,
            ),
          ),
        ],
      ),
    );
  }
}

class _NewsFilterBar extends StatelessWidget {
  const _NewsFilterBar({
    required this.selectedCategory,
    required this.categories,
    required this.onCategorySelected,
    this.isAdvisory = false,
  });

  final String selectedCategory;
  final List<String> categories;
  final ValueChanged<String> onCategorySelected;
  final bool isAdvisory;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    physics: const AlwaysScrollableScrollPhysics(),
    child: Padding(
      padding: const EdgeInsets.only(right: 20),
      child: Row(
        children: [
          for (var index = 0; index < categories.length; index++) ...[
            if (index > 0) const SizedBox(width: 10),
            _NewsFilterChip(
              label: categories[index],
              icon: switch (categories[index]) {
                'Roads' => Icons.add_road_rounded,
                'Public Buildings' => Icons.apartment_rounded,
                'Streetlights' => Icons.lightbulb_outline_rounded,
                'Electric Poles' => Icons.electric_bolt_rounded,
                'Drainage' => Icons.water_damage_outlined,
                'Resolved' => Icons.task_alt_rounded,
                'Advertisement' => Icons.local_offer_outlined,
                'Maintenance' => Icons.build_outlined,
                'Announcements' => Icons.campaign_outlined,
                _ => Icons.apps_rounded,
              },
              selected: selectedCategory == categories[index],
              onTap: () => onCategorySelected(categories[index]),
            ),
          ],
        ],
      ),
    ),
  );
}

class _NewsFilterChip extends StatelessWidget {
  const _NewsFilterChip({
    required this.label,
    this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: label,
    child: ExcludeSemantics(
      child: Material(
        color: selected
            ? Theme.of(context).colorScheme.primary
            : (Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF173F4D)
                  : Colors.white),
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : (Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF345A63)
                          : line),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    color: selected
                        ? Theme.of(context).colorScheme.onPrimary
                        : (Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFFB2C9CC)
                              : inkSoft),
                    size: 15,
                  ),
                  const SizedBox(width: 5),
                ],
                Text(
                  label,
                  style: TextStyle(
                    color: selected
                        ? Theme.of(context).colorScheme.onPrimary
                        : (Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFFB2C9CC)
                              : inkSoft),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _NewsHeroCarousel extends StatelessWidget {
  const _NewsHeroCarousel({
    required this.stories,
    required this.controller,
    required this.currentPage,
    required this.onPageChanged,
  });

  final List<({String image, String title, String subtitle, String date})>
  stories;
  final PageController controller;
  final int currentPage;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(18),
    child: SizedBox(
      height: 188,
      child: Stack(
        children: [
          PageView.builder(
            controller: controller,
            itemCount: stories.length,
            onPageChanged: onPageChanged,
            itemBuilder: (context, index) {
              final story = stories[index];
              return Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    story.image,
                    fit: BoxFit.cover,
                    frameBuilder:
                        (context, child, frame, wasSynchronouslyLoaded) {
                          if (wasSynchronouslyLoaded || frame != null) {
                            return child;
                          }
                          return const SkeletonShimmer(
                            child: SkeletonBlock(
                              height: 188,
                              width: double.infinity,
                              radius: 0,
                            ),
                          );
                        },
                    errorBuilder: (_, _, _) => const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [deepNavy, teal],
                          begin: Alignment.bottomLeft,
                          end: Alignment.topRight,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.location_city_rounded,
                          color: Colors.white70,
                          size: 42,
                        ),
                      ),
                    ),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.transparent, Color(0xD9092732)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'FEATURED CITY UPDATE',
                          style: TextStyle(
                            color: Color(0xFFB9E0E2),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          story.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: infraHeading(
                            color: Colors.white,
                            fontSize: 18,
                            weight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.campaign_outlined,
                              color: Color(0xFF8BE0D4),
                              size: 14,
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                story.subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10.5,
                                ),
                              ),
                            ),
                            if (story.date.isNotEmpty) ...[
                              const SizedBox(width: 9),
                              const Icon(
                                Icons.schedule_rounded,
                                color: Colors.white60,
                                size: 12,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                story.date,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 9,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          Positioned(
            bottom: 9,
            right: 16,
            child: Row(
              children: [
                for (var index = 0; index < stories.length; index++)
                  Semantics(
                    button: true,
                    label: 'Show featured update ${index + 1}',
                    child: GestureDetector(
                      onTap: () => controller.animateToPage(
                        index,
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeOutCubic,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(7),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: index == currentPage ? 18 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: index == currentPage
                                ? Colors.white
                                : Colors.white60,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
