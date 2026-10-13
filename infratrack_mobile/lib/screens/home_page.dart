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
    try {
      final results = await Future.wait([
        ApiService.issues(),
        ApiService.reports(),
        ApiService.overview(),
        ApiService.notifications(),
      ]);
      if (!mounted) return;
      setState(() {
        _issues = results[0] as List<Map<String, dynamic>>;
        _myReports = results[1] as List<Map<String, dynamic>>;
        _overview = results[2] as Map<String, dynamic>;
        _notifications = results[3] as List<Map<String, dynamic>>;
        _loadingIssues = false;
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
    _featuredTimer?.cancel();
    _featuredController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageEntrance(
      child: AppScroll(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppHeader(
              eyebrow: 'MATI CITY · DAVAO ORIENTAL',
              title:
                  'Welcome, ${ApiService.currentUser?['name'] ?? 'neighbor'}',
              trailing: IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: .62),
                  foregroundColor: navy,
                ),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const NotificationsPage()),
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
            if (_featuredStories.isNotEmpty)
              _FeaturedBanner(
                stories: _featuredStories,
                controller: _featuredController,
                currentIndex: _featuredIndex,
                onPageChanged: (index) =>
                    setState(() => _featuredIndex = index),
              )
            else
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'Community reports will appear here.',
                  style: TextStyle(color: inkSoft),
                ),
              ),
            const SizedBox(height: 18),
            if (_issues.isNotEmpty) _HeroUpdate(issue: _issues.first),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    number:
                        '${_myReports.where((issue) => !['Resolved', 'Rejected', 'Archived'].contains(issue['status'])).length}',
                    label: 'Your open reports',
                    dark: true,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StatCard(
                    number:
                        '${(_overview?['summary'] as Map?)?['resolved'] ?? '—'}',
                    label: 'Resolved reports',
                  ),
                ),
              ],
            ),
            SectionTitle(
              title: 'Nearby reports',
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
                    selected: _activeFilter == 'All',
                    onTap: () => setState(() => _activeFilter = 'All'),
                  ),
                  const SizedBox(width: 8),
                  _ReportFilter(
                    label: 'Roads',
                    selected: _activeFilter == 'Roads',
                    onTap: () => setState(() => _activeFilter = 'Roads'),
                  ),
                  const SizedBox(width: 8),
                  _ReportFilter(
                    label: 'Water',
                    selected: _activeFilter == 'Water',
                    onTap: () => setState(() => _activeFilter = 'Water'),
                  ),
                  const SizedBox(width: 8),
                  _ReportFilter(
                    label: 'Drainage',
                    selected: _activeFilter == 'Drainage',
                    onTap: () => setState(() => _activeFilter = 'Drainage'),
                  ),
                  const SizedBox(width: 8),
                  _ReportFilter(
                    label: 'Lighting',
                    selected: _activeFilter == 'Lighting',
                    onTap: () => setState(() => _activeFilter = 'Lighting'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (_loadingIssues)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: CircularProgressIndicator(color: teal)),
              )
            else if (_loadError != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(_loadError!, style: const TextStyle(color: clay)),
              )
            else if (_nearbyReports.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'No infrastructure reports found.',
                  style: TextStyle(color: inkSoft),
                ),
              )
            else
              for (final report in _nearbyReports)
                ReportCard(
                  title: report['title'] as String? ?? 'Infrastructure report',
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

  List<Map<String, dynamic>> get _nearbyReports => _issues
      .where((report) {
        final category = report['category'] as String? ?? '';
        final userBarangay = _normalizedBarangay(
          ApiService.currentUser?['barangay']?.toString(),
        );
        final reportBarangay = _normalizedBarangay(
          report['location']?.toString(),
        );
        return (userBarangay.isEmpty || reportBarangay == userBarangay) &&
            (_activeFilter == 'All' || category == _activeFilter);
      })
      .take(6)
      .toList();

  String _normalizedBarangay(String? value) {
    return (value ?? '').trim().toLowerCase().replaceFirst(
      RegExp(r'^(?:brgy\.?|barangay)\s*'),
      '',
    );
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
}

class _ReportFilter extends StatelessWidget {
  const _ReportFilter({
    required this.label,
    this.selected = false,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => FilterChip(
    label: Text(label),
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
