part of '../main.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.onOpenNews});

  final VoidCallback? onOpenNews;

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
                          builder: (_) => NotificationsPage(
                            onCityUpdateSelected: widget.onOpenNews,
                          ),
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
                  _TrakoWelcomeCard(
                    firstName: _firstName,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ChatbotPage(),
                      ),
                    ),
                  ),
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
                          label: 'Public Buildings',
                          icon: Icons.apartment_rounded,
                          selected: _activeFilter == 'Public Buildings',
                          onTap: () => setState(
                            () => _activeFilter = 'Public Buildings',
                          ),
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
                          label: 'Streetlights',
                          icon: Icons.lightbulb_outline_rounded,
                          selected: _activeFilter == 'Streetlights',
                          onTap: () =>
                              setState(() => _activeFilter = 'Streetlights'),
                        ),
                        const SizedBox(width: 8),
                        _ReportFilter(
                          label: 'Electric Poles',
                          icon: Icons.electric_bolt_rounded,
                          selected: _activeFilter == 'Electric Poles',
                          onTap: () =>
                              setState(() => _activeFilter = 'Electric Poles'),
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
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => MyReportDetailsPage(
                              report: _reportDetailsFromApi(report),
                              canReply: _canReplyToIssue(report, _myReports),
                            ),
                          ),
                        ),
                      ),
                ],
              ),
      ),
    );
  }

  List<Map<String, dynamic>> get _nearbyReports => _issues.where((report) {
    final category = normalizeReportCategory(report['category'] as String?);
    final userBarangay = _normalizedBarangay(
      ApiService.currentUser?['barangay']?.toString(),
    );
    final location = report['location']?.toString() ?? '';
    final normalizedLocation = _normalizedBarangay(location);
    final locationForMatching =
        normalizedLocation == 'mati city' || normalizedLocation == 'mati'
        ? report['reporter_barangay']?.toString() ?? ''
        : location;
    final status = (report['status'] as String? ?? '').trim().toLowerCase();
    final isApprovedOrInProgress = const {
      'approved',
      'verified by inspector',
      'in progress',
    }.contains(status);
    return userBarangay.isNotEmpty &&
        _locationMatchesBarangay(locationForMatching, userBarangay) &&
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
    switch (normalizeReportCategory(report['category'] as String?)
        .toLowerCase()) {
      case 'drainage':
        return amber;
      case 'streetlights':
        return green;
      case 'public buildings':
        return teal;
      case 'electric poles':
        return navy;
      default:
        return red;
    }
  }

  IconData _reportIcon(Map<String, dynamic> report) {
    switch (normalizeReportCategory(report['category'] as String?)
        .toLowerCase()) {
      case 'drainage':
        return Icons.water_damage_outlined;
      case 'streetlights':
        return Icons.lightbulb_outline;
      case 'public buildings':
        return Icons.apartment_rounded;
      case 'electric poles':
        return Icons.electric_bolt_rounded;
      case 'roads':
        return Icons.add_road_rounded;
      default:
        return Icons.construction;
    }
  }

  void _openMap(BuildContext context) {
    final shell = context.findAncestorStateOfType<_MainShellState>();
    shell?.setState(() => shell.index = 1);
  }
}

class ReportIssueCallout extends StatelessWidget {
  const ReportIssueCallout({super.key, required this.onTap});

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

class _TrakoWelcomeCard extends StatelessWidget {
  const _TrakoWelcomeCard({required this.firstName, required this.onTap});

  final String firstName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const ValueKey('home-trako-welcome'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Image.asset(
                'assets/chatbot_character/chatbot_face/mascot.png',
                key: const ValueKey('home-trako-mascot'),
                width: 132,
                height: 154,
                fit: BoxFit.contain,
                alignment: Alignment.bottomCenter,
                semanticLabel: 'Trako, your InfraTrack assistant',
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 17),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: -2,
                        top: 34,
                        child: CustomPaint(
                          size: const Size(16, 20),
                          painter: _TrakoBubbleTailPainter(
                            color: theme.colorScheme.surface,
                          ),
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.fromLTRB(15, 13, 13, 12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: navy.withValues(alpha: .08),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Trako',
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              "Hi $firstName! Need help with a report or city update? I'm here to help.",
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                                fontSize: 12,
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Chat with Trako',
                                  style: TextStyle(
                                    color: theme.colorScheme.primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 14,
                                  color: theme.colorScheme.primary,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrakoBubbleTailPainter extends CustomPainter {
  const _TrakoBubbleTailPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = ui.Path()
      ..moveTo(size.width, 0)
      ..lineTo(0, size.height / 2)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_TrakoBubbleTailPainter oldDelegate) =>
      oldDelegate.color != color;
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline_rounded, color: teal, size: 22),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              'All clear for this category. New community reports will show up here.',
              style: TextStyle(
                color: infraMutedTextColor(context),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
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
        Icon(
          icon,
          size: 14,
          color: selected
              ? Theme.of(context).colorScheme.onPrimary
              : infraMutedTextColor(context),
        ),
        const SizedBox(width: 5),
        Text(label),
      ],
    ),
    selected: selected,
    onSelected: (_) => onTap(),
    showCheckmark: false,
    backgroundColor: Colors.white,
    selectedColor: Theme.of(context).colorScheme.primary,
    labelStyle: TextStyle(
      color: selected
          ? Theme.of(context).colorScheme.onPrimary
          : infraMutedTextColor(context),
      fontSize: 11.5,
      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
    ),
    side: BorderSide(
      color: selected
          ? Theme.of(context).colorScheme.primary
          : (Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF54757A)
                : const Color(0xFFA8B8B9)),
      width: infraAppearance.value.highContrast ? 2 : 1.25,
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
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface
                .withValues(alpha: dark ? .92 : .78),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Theme.of(context).colorScheme.outline),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(13),
            leading: CircleAvatar(
              backgroundColor: teal.withValues(alpha: dark ? .2 : .12),
              child: Icon(
                Icons.sync,
                color: dark ? const Color(0xFF75D5CF) : teal,
              ),
            ),
            title: Text(
              'REPORT UPDATE${createdAt.isEmpty ? '' : ' · $createdAt'}',
              style: TextStyle(
                color: dark ? const Color(0xFF75D5CF) : teal,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${issue['title'] ?? 'Infrastructure report'} · ${issue['status'] ?? 'Reported'}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            trailing: Icon(
              Icons.chevron_right,
              color: infraMutedTextColor(context),
            ),
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
