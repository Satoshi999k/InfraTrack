part of '../main.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _featuredController = PageController();
  Timer? _featuredTimer;
  int _featuredIndex = 0;
  String _activeFilter = 'All';
  List<Map<String, dynamic>> _issues = [];
  List<Map<String, dynamic>> _myReports = [];
  List<Map<String, dynamic>> _notifications = [];
  Map<String, dynamic>? _overview;
  bool _loadingIssues = true;
  String? _loadError;

  Future<void> refresh() => _loadDashboardData();

  String get _firstName {
    final name = ApiService.currentUser?['name']?.toString().trim() ?? '';
    return name.isEmpty ? 'neighbor' : name.split(RegExp(r'\s+')).first;
  }

  void _handleNotificationRead() {
    final notificationId = ApiService.lastReadNotificationId?.toString();
    if (notificationId == null || !mounted) return;
    setState(() {
      _notifications = _notifications.map((item) {
        if (item['id'].toString() != notificationId ||
            item['read_at'] != null) {
          return item;
        }
        return {...item, 'read_at': DateTime.now().toIso8601String()};
      }).toList();
    });
  }

  List<({String image, String title, String subtitle})>
  get _featuredStories => _issues.take(5).map((issue) {
    final mediaUrl = publicMediaUrl(issue['media_url'] as String?);
    return (
      image: mediaUrl ?? '',
      title: issue['title'] as String? ?? 'Infrastructure report',
      subtitle:
          '${issue['status'] ?? 'Reported'} · ${issue['location'] ?? 'Mati City'}',
    );
  }).toList();

  @override
  void initState() {
    super.initState();
    ApiService.notificationReadRevision.addListener(_handleNotificationRead);
    _loadDashboardData();
    _featuredTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted ||
          !_featuredController.hasClients ||
          _featuredStories.isEmpty) {
        return;
      }
      _featuredController.animateToPage(
        (_featuredIndex + 1) % _featuredStories.length,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  Future<void> _loadDashboardData() async {
    final notificationRevision = ApiService.notificationReadRevision.value;
    try {
      final results = await Future.wait([
        ApiService.issues(homeUpdatesOnly: true),
        ApiService.reports(),
        ApiService.overview(),
        ApiService.notifications(),
      ]);
      if (!mounted) return;
      setState(() {
        _issues = results[0] as List<Map<String, dynamic>>;
        _myReports = results[1] as List<Map<String, dynamic>>;
        _overview = results[2] as Map<String, dynamic>;
        if (notificationRevision == ApiService.notificationReadRevision.value) {
          _notifications = results[3] as List<Map<String, dynamic>>;
        }
        _loadingIssues = false;
        _loadError = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingIssues = false;
          _loadError = 'Could not connect to the InfraTrack server.';
        });
      }
    }
  }

  @override
  void dispose() {
    ApiService.notificationReadRevision.removeListener(_handleNotificationRead);
    _featuredTimer?.cancel();
    _featuredController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageEntrance(
      child: AppScroll(
        onRefresh: _loadDashboardData,
        child: _loadingIssues
            ? const _HomeDashboardSkeleton()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppHeader(
                    eyebrow: 'MATI CITY · DAVAO ORIENTAL',
                    title: 'Welcome, $_firstName',
                    subtitle: 'Let’s make our community better, together.',
                    trailing: IconButton(
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: .62),
                        foregroundColor: navy,
                      ),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const NotificationsPage(),
                        ),
                      ),
                      tooltip: 'Notifications',
                      icon: Badge(
                        isLabelVisible: _notifications.any(
                          (item) => item['read_at'] == null,
                        ),
                        label: Text(
                          '${_notifications.where((item) => item['read_at'] == null).length}',
                        ),
                        child: const Icon(Icons.notifications_outlined),
                      ),
                    ),
                  ),
                  _ReportIssueCallout(onTap: () => _openReport(context)),
                  const SizedBox(height: 16),
                  if (_featuredStories.isNotEmpty)
                    _FeaturedBanner(
                      stories: _featuredStories,
                      controller: _featuredController,
                      currentIndex: _featuredIndex,
                      onPageChanged: (index) =>
                          setState(() => _featuredIndex = index),
                    )
                  else
                    const _CommunityEmptyCard(),
                  const SizedBox(height: 18),
                  if (_issues.isNotEmpty) _HeroUpdate(issue: _issues.first),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _HomeMetricCard(
                          number:
                              '${_myReports.where((issue) => !['Resolved', 'Rejected', 'Archived'].contains(issue['status'])).length}',
                          label: 'Your open reports',
                          icon: Icons.assignment_outlined,
                          dark: true,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _HomeMetricCard(
                          number:
                              '${(_overview?['summary'] as Map?)?['resolved'] ?? '—'}',
                          label: 'Community resolved',
                          icon: Icons.task_alt_rounded,
                        ),
                      ),
                    ],
                  ),
                  SectionTitle(
                    title: 'Reports near you',
                    action: 'See map',
                    onActionTap: () => _openMap(context),
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Row(
                      children: [
                        _ReportFilter(
                          label: 'All',
                          icon: Icons.apps_rounded,
                          selected: _activeFilter == 'All',
                          onTap: () => setState(() => _activeFilter = 'All'),
                        ),
                        const SizedBox(width: 8),
                        _ReportFilter(
                          label: 'Roads',
                          icon: Icons.add_road_rounded,
                          selected: _activeFilter == 'Roads',
                          onTap: () => setState(() => _activeFilter = 'Roads'),
                        ),
                        const SizedBox(width: 8),
                        _ReportFilter(
                          label: 'Water',
                          icon: Icons.water_drop_outlined,
                          selected: _activeFilter == 'Water',
                          onTap: () => setState(() => _activeFilter = 'Water'),
                        ),
                        const SizedBox(width: 8),
                        _ReportFilter(
                          label: 'Drainage',
                          icon: Icons.water_damage_outlined,
                          selected: _activeFilter == 'Drainage',
                          onTap: () =>
                              setState(() => _activeFilter = 'Drainage'),
                        ),
                        const SizedBox(width: 8),
                        _ReportFilter(
                          label: 'Lighting',
                          icon: Icons.lightbulb_outline_rounded,
                          selected: _activeFilter == 'Lighting',
                          onTap: () =>
                              setState(() => _activeFilter = 'Lighting'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_loadError != null)
                    LoadErrorPanel(
                      message: _loadError!,
                      onRetry: _loadDashboardData,
                    )
                  else if (_nearbyReports.isEmpty)
                    const _NoNearbyReports()
                  else
                    for (final report in _nearbyReports)
                      ReportCard(
                        title:
                            report['title'] as String? ??
                            'Infrastructure report',
                        location: report['location'] as String? ?? 'Mati City',
                        status: report['status'] as String? ?? 'Reported',
                        color: _reportColor(report),
                        icon: _reportIcon(report),
                        onTap: null,
                      ),
                ],
              ),
      ),
    );
  }

  List<Map<String, dynamic>> get _nearbyReports => _issues.where((report) {
    final category = report['category'] as String? ?? '';
    final userBarangay = _normalizedBarangay(
      ApiService.currentUser?['barangay']?.toString(),
    );
    final location = report['location']?.toString() ?? '';
    final status = (report['status'] as String? ?? '').trim().toLowerCase();
    final isApprovedOrInProgress = const {
      'approved',
      'verified by inspector',
      'in progress',
    }.contains(status);
    return userBarangay.isNotEmpty &&
        _locationMatchesBarangay(location, userBarangay) &&
        isApprovedOrInProgress &&
        (_activeFilter == 'All' || category == _activeFilter);
  }).toList();

  String _normalizedBarangay(String? value) {
    return (value ?? '').trim().toLowerCase().replaceFirst(
      RegExp(r'^(?:brgy\.?|barangay)\s*'),
      '',
    );
  }

  bool _locationMatchesBarangay(String location, String barangay) {
    if (_normalizedBarangay(location) == barangay) return true;
    final escapedBarangay = RegExp.escape(barangay);
    return RegExp(
      '(?:^|[^a-z0-9])(?:brgy\\.?|barangay)\\s*$escapedBarangay(?:\$|[^a-z0-9])',
    ).hasMatch(location.toLowerCase());
  }

  Color _reportColor(Map<String, dynamic> report) {
    switch ((report['category'] as String? ?? '').toLowerCase()) {
      case 'water':
        return teal;
      case 'drainage':
        return amber;
      case 'lighting':
        return green;
      default:
        return red;
    }
  }

  IconData _reportIcon(Map<String, dynamic> report) {
    switch ((report['category'] as String? ?? '').toLowerCase()) {
      case 'water':
        return Icons.water_drop;
      case 'drainage':
        return Icons.water_damage_outlined;
      case 'lighting':
        return Icons.lightbulb_outline;
      default:
        return Icons.construction;
    }
  }

  void _openMap(BuildContext context) {
    final shell = context.findAncestorStateOfType<_MainShellState>();
    shell?.setState(() => shell.index = 1);
  }

  void _openReport(BuildContext context) {
    final shell = context.findAncestorStateOfType<_MainShellState>();
    shell?.setState(() => shell.index = 2);
  }
}

class _ReportIssueCallout extends StatelessWidget {
  const _ReportIssueCallout({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: navy,
    borderRadius: BorderRadius.circular(20),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 15, 13, 15),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Icon(
                Icons.add_location_alt_outlined,
                color: Color(0xFF8BE0D4),
                size: 24,
              ),
            ),
            const SizedBox(width: 13),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Spot an infrastructure issue?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Let the community know. We’ll take it from here.',
                    maxLines: 2,
                    style: TextStyle(
                      color: Color(0xFFB9CBD1),
                      fontSize: 10.5,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_rounded,
              color: Colors.white.withValues(alpha: .86),
              size: 21,
            ),
          ],
        ),
      ),
    ),
  );
}

class _HomeMetricCard extends StatelessWidget {
  const _HomeMetricCard({
    required this.number,
    required this.label,
    required this.icon,
    this.dark = false,
  });

  final String number;
  final String label;
  final IconData icon;
  final bool dark;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 105),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: dark ? navy : Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: dark ? navy : line.withValues(alpha: .8)),
      boxShadow: [
        BoxShadow(
          color: navy.withValues(alpha: .045),
          blurRadius: 16,
          offset: const Offset(0, 5),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, size: 17, color: dark ? const Color(0xFF8BE0D4) : teal),
            const Spacer(),
            Text(
              number,
              style: infraHeading(
                color: dark ? Colors.white : navy,
                fontSize: 25,
                weight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 11),
        Text(
          label,
          style: TextStyle(
            color: dark ? const Color(0xFFB9CBD1) : inkSoft,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class _HomeDashboardSkeleton extends StatelessWidget {
  const _HomeDashboardSkeleton();

  @override
  Widget build(BuildContext context) => SkeletonShimmer(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBlock(height: 10, width: 170, radius: 5),
                  SizedBox(height: 9),
                  SkeletonBlock(height: 25, width: 230, radius: 7),
                  SizedBox(height: 7),
                  SkeletonBlock(height: 10, width: 205, radius: 5),
                ],
              ),
            ),
            SkeletonBlock(height: 48, width: 48, radius: 24),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          height: 78,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.all(15),
          child: const Row(
            children: [
              SkeletonBlock(height: 46, width: 46, radius: 15),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SkeletonBlock(height: 13, width: 180, radius: 7),
                    SizedBox(height: 8),
                    SkeletonBlock(height: 10, width: 205, radius: 6),
                  ],
                ),
              ),
              SkeletonBlock(height: 20, width: 20, radius: 10),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const SkeletonBlock(height: 178, width: double.infinity, radius: 20),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 98,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                height: 98,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const SkeletonBlock(height: 20, width: 158, radius: 8),
        const SizedBox(height: 13),
        const Row(
          children: [
            SkeletonBlock(height: 34, width: 66, radius: 17),
            SizedBox(width: 8),
            SkeletonBlock(height: 34, width: 83, radius: 17),
            SizedBox(width: 8),
            SkeletonBlock(height: 34, width: 78, radius: 17),
            SizedBox(width: 8),
            SkeletonBlock(height: 34, width: 92, radius: 17),
          ],
        ),
        const SizedBox(height: 13),
        const ReportFeedSkeleton(count: 3, animated: false),
      ],
    ),
  );
}

class _CommunityEmptyCard extends StatelessWidget {
  const _CommunityEmptyCard();

  @override
  Widget build(BuildContext context) => Container(
    height: 148,
    width: double.infinity,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [deepNavy, teal],
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
      ),
      borderRadius: BorderRadius.circular(20),
    ),
    child: const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.location_city_rounded, color: Colors.white70, size: 35),
        SizedBox(height: 10),
        Text(
          'Your community, in focus',
          style: TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Updates from Mati will appear here.',
          style: TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ],
    ),
  );
}

class _NoNearbyReports extends StatelessWidget {
  const _NoNearbyReports();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 20),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .76),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: line),
    ),
    child: const Row(
      children: [
        Icon(Icons.check_circle_outline_rounded, color: teal, size: 22),
        SizedBox(width: 11),
        Expanded(
          child: Text(
            'All clear for this category. New community reports will show up here.',
            style: TextStyle(color: inkSoft, fontSize: 12, height: 1.4),
          ),
        ),
      ],
    ),
  );
}

class _ReportFilter extends StatelessWidget {
  const _ReportFilter({
    required this.label,
    required this.icon,
    this.selected = false,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => FilterChip(
    label: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: selected ? Colors.white : inkSoft),
        const SizedBox(width: 5),
        Text(label),
      ],
    ),
    selected: selected,
    onSelected: (_) => onTap(),
    showCheckmark: false,
    backgroundColor: Colors.white.withValues(alpha: .56),
    selectedColor: navy.withValues(alpha: .94),
    labelStyle: TextStyle(
      color: selected ? Colors.white : inkSoft,
      fontSize: 11.5,
      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
    ),
    side: BorderSide(
      color: selected ? navy : Colors.white.withValues(alpha: .9),
    ),
    shape: const StadiumBorder(),
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
  );
}

class _HeroUpdate extends StatelessWidget {
  const _HeroUpdate({required this.issue});
  final Map<String, dynamic> issue;

  @override
  Widget build(BuildContext context) {
    final createdAt = issue['created_at']?.toString() ?? '';
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .58),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: .9)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(13),
            leading: const CircleAvatar(
              backgroundColor: Color(0xB8E4F2F0),
              child: Icon(Icons.sync, color: teal),
            ),
            title: Text(
              'REPORT UPDATE${createdAt.isEmpty ? '' : ' · $createdAt'}',
              style: const TextStyle(
                color: teal,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${issue['title'] ?? 'Infrastructure report'} · ${issue['status'] ?? 'Reported'}',
                style: const TextStyle(fontWeight: FontWeight.w700, color: ink),
              ),
            ),
            trailing: const Icon(Icons.chevron_right, color: inkSoft),
          ),
        ),
      ),
    );
  }
}

class _FeaturedBanner extends StatelessWidget {
  const _FeaturedBanner({
    required this.stories,
    required this.controller,
    required this.currentIndex,
    required this.onPageChanged,
  });

  final List<({String image, String title, String subtitle})> stories;
  final PageController controller;
  final int currentIndex;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(22),
    child: SizedBox(
      height: 178,
      width: double.infinity,
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
                    errorBuilder: (_, _, _) => Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(colors: [deepNavy, teal]),
                      ),
                      child: const Icon(
                        Icons.location_city,
                        color: Colors.white54,
                        size: 54,
                      ),
                    ),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.transparent, Color(0xE6092732)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const Text(
                          'COMMUNITY INFRASTRUCTURE UPDATE',
                          style: TextStyle(
                            color: Color(0xFFB9E0E2),
                            fontSize: 9,
                            letterSpacing: 1.1,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          story.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: infraHeading(
                            color: Colors.white,
                            fontSize: 19,
                            weight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            const Icon(
                              Icons.verified_outlined,
                              color: Color(0xFF5FD9C7),
                              size: 15,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              story.subtitle,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
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
            right: 16,
            bottom: 14,
            child: Row(
              children: [
                for (var index = 0; index < stories.length; index++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: index == currentIndex ? 16 : 5,
                    height: 5,
                    margin: const EdgeInsets.only(left: 5),
                    decoration: BoxDecoration(
                      color: index == currentIndex
                          ? Colors.white
                          : Colors.white54,
                      borderRadius: BorderRadius.circular(8),
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
