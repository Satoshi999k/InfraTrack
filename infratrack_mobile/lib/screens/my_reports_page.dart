part of '../main.dart';

typedef _ReportDetails = ({
  String title,
  String reportId,
  String description,
  String location,
  String category,
  String severity,
  String assignedTeam,
  String resolutionNote,
  int progressPercentage,
  List<Map<String, dynamic>> progressUpdates,
  List<Map<String, dynamic>> statusHistory,
  String coordinates,
  String age,
  String image,
  String status,
  Color color,
  IconData icon,
});

_ReportDetails _reportDetailsFromApi(Map<String, dynamic> item) {
  final status = item['status'] as String? ?? 'Reported';
  final category = normalizeReportCategory(
    item['category'] as String? ?? 'Roads',
  );
  final color = status == 'Resolved'
      ? green
      : status == 'In progress' || status == 'Scheduled for repair'
      ? teal
      : clay;
  return (
    title: item['title'] as String? ?? 'Infrastructure report',
    reportId: item['public_id']?.toString() ?? item['id']?.toString() ?? '',
    description: item['description']?.toString() ?? '',
    location: item['location']?.toString() ?? 'Mati City',
    category: category,
    severity: item['severity']?.toString() ?? 'Medium',
    assignedTeam: item['assigned_team']?.toString() ?? '',
    resolutionNote: item['resolution_note']?.toString() ?? '',
    progressPercentage: (int.tryParse('${item['progress_percentage']}') ?? 0)
        .clamp(0, 100),
    progressUpdates: (item['progress_updates'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((update) => Map<String, dynamic>.from(update))
        .toList(),
    statusHistory: (item['status_history'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((event) => Map<String, dynamic>.from(event))
        .toList(),
    coordinates: item['latitude'] == null || item['longitude'] == null
        ? ''
        : 'Lat ${item['latitude']}, Lon ${item['longitude']}',
    age: item['created_at']?.toString() ?? '',
    image: publicMediaUrl(item['media_url'] as String?) ?? '',
    status: status,
    color: color,
    icon: switch (category) {
      'Streetlights' => Icons.lightbulb_outline,
      'Public Buildings' => Icons.apartment_rounded,
      'Electric Poles' => Icons.electric_bolt_rounded,
      'Drainage' => Icons.water_damage_outlined,
      'Roads' => Icons.add_road_rounded,
      _ => Icons.construction,
    },
  );
}

bool _canReplyToIssue(
  Map<String, dynamic> issue,
  List<Map<String, dynamic>> ownedReports,
) {
  final role = ApiService.currentUser?['role']?.toString().toLowerCase();
  if (const {'admin', 'lgu', 'barangay_staff'}.contains(role)) return true;
  if (role != 'resident') return false;
  final issueId = (issue['public_id'] ?? issue['id']).toString();
  return ownedReports.any(
    (report) => (report['public_id'] ?? report['id']).toString() == issueId,
  );
}

String _formatReportDate(String value) {
  final date = DateTime.tryParse(value);
  if (date == null) return value;
  const months = [
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
  ];
  final hour = date.hour == 0
      ? 12
      : date.hour > 12
      ? date.hour - 12
      : date.hour;
  final minute = date.minute.toString().padLeft(2, '0');
  final period = date.hour >= 12 ? 'PM' : 'AM';
  return '${months[date.month - 1]} ${date.day}, ${date.year} · $hour:$minute $period';
}

class MyReportsPage extends StatefulWidget {
  const MyReportsPage({super.key});
  @override
  State<MyReportsPage> createState() => _MyReportsPageState();
}

class _MyReportsPageState extends State<MyReportsPage> {
  String filter = 'All';
  List<Map<String, dynamic>> _serverReports = [];
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    try {
      final items = await ApiService.reports();
      if (mounted) {
        setState(() {
          _serverReports = items;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _loadError = error.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final reports = _serverReports.map(_reportDetailsFromApi).toList();
    final resolvedCount = _serverReports
        .where((item) => item['status'] == 'Resolved')
        .length;
    final openCount = _serverReports
        .where(
          (item) =>
              !['Resolved', 'Rejected', 'Archived'].contains(item['status']),
        )
        .length;
    final visible = filter == 'All'
        ? reports
        : reports.where((item) => item.status == filter).toList();
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: PageEntrance(
          child: RefreshIndicator(
            color: teal,
            backgroundColor: Colors.white,
            onRefresh: _loadReports,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _MyReportsHeaderDelegate(
                    filter: filter,
                    totalCount: _serverReports.length,
                    openCount: openCount,
                    resolvedCount: resolvedCount,
                    visibleCount: visible.length,
                    onBack: () => Navigator.pop(context),
                    onFilterChanged: (value) => setState(() => filter = value),
                  ),
                ),
                if (_loading)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        const ReportFeedSkeleton(count: 4),
                      ]),
                    ),
                  )
                else if (_loadError != null)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
                    sliver: SliverToBoxAdapter(
                      child: LoadErrorPanel(
                        message: _loadError!,
                        onRetry: _loadReports,
                      ),
                    ),
                  )
                else if (_serverReports.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyReports(
                      icon: Icons.assignment_outlined,
                      title: ApiService.isSignedIn
                          ? 'No reports yet'
                          : 'Your reports are waiting',
                      message: ApiService.isSignedIn
                          ? 'You have not submitted any reports yet.'
                          : 'Sign in to see your reports.',
                    ),
                  )
                else if (visible.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: const _EmptyReports(
                      icon: Icons.filter_alt_off_outlined,
                      title: 'No reports match this filter',
                      message: 'Try another status filter to see your reports.',
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) =>
                            _MyReportCard(report: visible[index]),
                        childCount: visible.length,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyReports extends StatelessWidget {
  const _EmptyReports({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: inkSoft.withValues(alpha: .5)),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: navy,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: inkSoft, fontSize: 13, height: 1.5),
          ),
        ],
      ),
    ),
  );
}

class _MyReportsHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _MyReportsHeaderDelegate({
    required this.filter,
    required this.totalCount,
    required this.openCount,
    required this.resolvedCount,
    required this.visibleCount,
    required this.onBack,
    required this.onFilterChanged,
  });

  static const double _extent = 300;

  final String filter;
  final int totalCount;
  final int openCount;
  final int resolvedCount;
  final int visibleCount;
  final VoidCallback onBack;
  final ValueChanged<String> onFilterChanged;

  static const _filters = [
    ('All', Icons.filter_list_rounded),
    ('Reported', Icons.assignment_outlined),
    ('Verified by inspector', Icons.verified_outlined),
    ('In progress', Icons.autorenew_rounded),
    ('Scheduled for repair', Icons.calendar_month_outlined),
    ('Resolved', Icons.check_circle_outline_rounded),
  ];

  @override
  double get minExtent => _extent;

  @override
  double get maxExtent => _extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => Material(
    color: Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF0D2430)
        : sand,
    elevation: overlapsContent ? 3 : 0,
    shadowColor: navy.withValues(alpha: .12),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Material(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF173F4D)
                    : Colors.white.withValues(alpha: .72),
                shape: const CircleBorder(),
                child: IconButton(
                  onPressed: onBack,
                  tooltip: 'Back',
                  icon: Icon(
                    Icons.arrow_back,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFFEAF6F4)
                        : navy,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ACTIVITY CENTER',
                      style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF75D5CF)
                            : teal,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                    Text(
                      'My reports',
                      style: infraHeading(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFFEAF6F4)
                            : navy,
                        fontSize: 24,
                        weight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: EdgeInsets.only(left: 4, top: 2, bottom: 18),
            child: Text(
              'Your contribution to a safer, better Mati City.',
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFFB2C9CC)
                    : inkSoft,
                fontSize: 12,
                height: 1.3,
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _ReportSummary(
                  number: '$totalCount',
                  label: 'Total',
                  color: navy,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ReportSummary(
                  number: '$openCount',
                  label: 'Open',
                  color: clay,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ReportSummary(
                  number: '$resolvedCount',
                  label: 'Resolved',
                  color: green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 9),
            child: Text(
              'FILTER BY STATUS',
              style: TextStyle(
                color: inkSoft,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            clipBehavior: Clip.none,
            child: Row(
              children: _filters
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        avatar: Icon(
                          item.$2,
                          size: 16,
                          color: filter == item.$1
                              ? Theme.of(context).colorScheme.onPrimary
                              : (Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFFB2C9CC)
                                    : inkSoft),
                        ),
                        label: Text(item.$1),
                        selected: filter == item.$1,
                        showCheckmark: false,
                        onSelected: (_) => onFilterChanged(item.$1),
                        selectedColor: Theme.of(context).colorScheme.primary,
                        backgroundColor:
                            Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF173F4D)
                            : Colors.transparent,
                        side: BorderSide(
                          color: filter == item.$1
                              ? (infraAppearance.value.highContrast
                                    ? Theme.of(context).colorScheme.onPrimary
                                    : Theme.of(context).colorScheme.primary)
                              : (infraAppearance.value.highContrast
                                    ? Theme.of(context).colorScheme.outline
                                    : Theme.of(context).brightness ==
                                          Brightness.dark
                                    ? const Color(0xFF345A63)
                                    : line),
                          width: infraAppearance.value.highContrast ? 2 : 1,
                        ),
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: const VisualDensity(
                          horizontal: -2,
                          vertical: -2,
                        ),
                        labelStyle: TextStyle(
                          color: filter == item.$1
                              ? Theme.of(context).colorScheme.onPrimary
                              : infraMutedTextColor(context),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'RECENT REPORTS',
                style: infraHeading(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFFEAF6F4)
                      : navy,
                  fontSize: 13,
                  weight: FontWeight.w800,
                ),
              ),
              Text(
                '$visibleCount shown',
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFFB2C9CC)
                      : inkSoft,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  @override
  bool shouldRebuild(covariant _MyReportsHeaderDelegate oldDelegate) =>
      filter != oldDelegate.filter ||
      totalCount != oldDelegate.totalCount ||
      openCount != oldDelegate.openCount ||
      resolvedCount != oldDelegate.resolvedCount ||
      visibleCount != oldDelegate.visibleCount;
}

class _ReportSummary extends StatelessWidget {
  const _ReportSummary({
    required this.number,
    required this.label,
    required this.color,
  });
  final String number, label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 14),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .76),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.white.withValues(alpha: .9)),
      boxShadow: [
        BoxShadow(
          color: navy.withValues(alpha: .06),
          blurRadius: 14,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: Column(
      children: [
        Text(
          number,
          style: infraHeading(
            color: color,
            fontSize: 22,
            weight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(label, style: const TextStyle(color: inkSoft, fontSize: 10)),
      ],
    ),
  );
}

class _MyReportCard extends StatelessWidget {
  const _MyReportCard({required this.report});
  final ({
    String title,
    String reportId,
    String description,
    String location,
    String category,
    String severity,
    String assignedTeam,
    String resolutionNote,
    int progressPercentage,
    List<Map<String, dynamic>> progressUpdates,
    List<Map<String, dynamic>> statusHistory,
    String coordinates,
    String age,
    String image,
    String status,
    Color color,
    IconData icon,
  })
  report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = infraMutedTextColor(context);
    final dark = theme.brightness == Brightness.dark;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: theme.colorScheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: theme.colorScheme.outline),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MyReportDetailsPage(report: report, canReply: true),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 72,
                  height: 82,
                  child: report.image.isEmpty
                      ? _ReportThumbnailPlaceholder(report: report)
                      : Image.network(
                          report.image,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              _ReportThumbnailPlaceholder(report: report),
                        ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Icon(report.icon, color: teal, size: 14),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  report.category,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: dark
                                        ? const Color(0xFF75D5CF)
                                        : teal,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        StatusPill(label: report.status, color: report.color),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      report.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: infraHeading(
                        color: theme.colorScheme.onSurface,
                        fontSize: 13,
                        weight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: muted,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            report.location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: muted,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Icon(Icons.schedule_rounded, size: 13, color: muted),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Filed ${_formatReportDate(report.age)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: muted, fontSize: 9.5),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 12,
                          color: inkSoft,
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
    );
  }
}

class _ReportThumbnailPlaceholder extends StatelessWidget {
  const _ReportThumbnailPlaceholder({required this.report});

  final ({
    String title,
    String reportId,
    String description,
    String location,
    String category,
    String severity,
    String assignedTeam,
    String resolutionNote,
    int progressPercentage,
    List<Map<String, dynamic>> progressUpdates,
    List<Map<String, dynamic>> statusHistory,
    String coordinates,
    String age,
    String image,
    String status,
    Color color,
    IconData icon,
  })
  report;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: report.color.withValues(alpha: .11),
    child: Center(child: Icon(report.icon, color: report.color, size: 26)),
  );
}

class MyReportDetailsPage extends StatelessWidget {
  const MyReportDetailsPage({
    super.key,
    required this.report,
    this.canReply = false,
  });

  final ({
    String title,
    String reportId,
    String description,
    String location,
    String category,
    String severity,
    String assignedTeam,
    String resolutionNote,
    int progressPercentage,
    List<Map<String, dynamic>> progressUpdates,
    List<Map<String, dynamic>> statusHistory,
    String coordinates,
    String age,
    String image,
    String status,
    Color color,
    IconData icon,
  })
  report;
  final bool canReply;

  bool get resolved => report.status == 'Resolved';

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    body: SafeArea(
      child: PageEntrance(
        child: AppScroll(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _DetailsBackButton(onPressed: () => Navigator.pop(context)),
                  const SizedBox(width: 12),
                  Text(
                    'Issue details',
                    style: infraHeading(
                      color: navy,
                      fontSize: 22,
                      weight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _DetailsHero(report: report),
              const SizedBox(height: 16),
              Text(
                report.title,
                style: infraHeading(
                  color: navy,
                  fontSize: 20,
                  weight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 7),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 15,
                    color: inkSoft,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _locationFor(report),
                      style: const TextStyle(color: inkSoft, fontSize: 11),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (report.coordinates.isNotEmpty) ...[
                Text(
                  'GPS coordinates · ${report.coordinates}',
                  style: infraMono(fontSize: 9, color: inkSoft),
                ),
                const SizedBox(height: 6),
              ],
              Text(
                'Report ID: ${report.reportId} ? Filed ${_formatReportDate(report.age)}',
                style: infraMono(fontSize: 9, color: inkSoft),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _DetailMetaChip(icon: report.icon, label: report.category),
                  _DetailMetaChip(
                    icon: Icons.warning_amber_outlined,
                    label: report.severity,
                  ),
                  _DetailMetaChip(icon: report.icon, label: report.status),
                ],
              ),
              if (report.status == 'Resolved') ...[
                const SizedBox(height: 18),
                _ReportRatingSection(reportId: report.reportId),
              ],
              if (report.status == 'In progress') ...[
                const SizedBox(height: 18),
                _ReportProgressCard(
                  progressPercentage: report.progressPercentage,
                  updates: report.progressUpdates,
                  statusHistory: report.statusHistory,
                ),
              ],
              if (report.status != 'Archived') ...[
                const SizedBox(height: 18),
                _ReportDiscussionSection(
                  reportId: report.reportId,
                  status: report.status,
                  canReply: canReply,
                ),
              ],
              const SizedBox(height: 18),
              const Divider(color: line),
              const SizedBox(height: 14),
              Text(
                'Description',
                style: infraHeading(
                  color: navy,
                  fontSize: 16,
                  weight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                report.description.isEmpty
                    ? 'No description was provided.'
                    : report.description,
                style: const TextStyle(color: inkSoft, height: 1.45),
              ),
              if (report.assignedTeam.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Assigned to ${report.assignedTeam}',
                  style: const TextStyle(
                    color: navy,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              if (resolved && report.resolutionNote.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Resolution note',
                  style: infraHeading(
                    color: navy,
                    fontSize: 16,
                    weight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  report.resolutionNote,
                  style: const TextStyle(color: inkSoft, height: 1.45),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

String _locationFor(
  ({
    String title,
    String reportId,
    String description,
    String location,
    String category,
    String severity,
    String assignedTeam,
    String resolutionNote,
    int progressPercentage,
    List<Map<String, dynamic>> progressUpdates,
    List<Map<String, dynamic>> statusHistory,
    String coordinates,
    String age,
    String image,
    String status,
    Color color,
    IconData icon,
  })
  report,
) => report.location;

class _ReportDiscussionSection extends StatefulWidget {
  const _ReportDiscussionSection({
    required this.reportId,
    required this.status,
    required this.canReply,
  });

  final String reportId;
  final String status;
  final bool canReply;

  @override
  State<_ReportDiscussionSection> createState() =>
      _ReportDiscussionSectionState();
}

class _ReportDiscussionSectionState extends State<_ReportDiscussionSection> {
  final _replyController = TextEditingController();
  final _threadController = ScrollController();
  List<Map<String, dynamic>> _comments = [];
  bool _loading = true;
  bool _sending = false;
  bool _expanded = false;
  String? _loadError;
  String? _replyError;

  bool get _repliesOpen =>
      !{'Resolved', 'Rejected', 'Archived'}.contains(widget.status);

  @override
  void initState() {
    super.initState();
    _loadDiscussion();
  }

  @override
  void dispose() {
    _replyController.dispose();
    _threadController.dispose();
    super.dispose();
  }

  Future<void> _loadDiscussion() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final comments = await ApiService.reportDiscussion(widget.reportId);
      if (!mounted) return;
      setState(() => _comments = comments);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendReply() async {
    final message = _replyController.text.trim();
    if (message.isEmpty) {
      setState(() => _replyError = 'Write a reply before sending.');
      return;
    }
    if (message.length > reportCommentMaxLength) {
      setState(
        () => _replyError =
            'Replies must be $reportCommentMaxLength characters or fewer.',
      );
      return;
    }

    setState(() {
      _sending = true;
      _replyError = null;
    });
    try {
      final comment = await ApiService.postReportDiscussionReply(
        reportId: widget.reportId,
        message: message,
      );
      if (!mounted) return;
      setState(() {
        _comments = [..._comments, comment];
        _replyController.clear();
        _expanded = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _replyError = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _toggleExpanded() {
    final expand = !_expanded;
    setState(() => _expanded = expand);
    if (expand) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_threadController.hasClients) {
          _threadController.animateTo(
            _threadController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleComments = _expanded || _comments.length <= 2
        ? _comments
        : _comments.skip(_comments.length - 2).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: line),
        boxShadow: [
          BoxShadow(
            color: navy.withValues(alpha: .035),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: teal.withValues(alpha: .11),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.forum_outlined,
                  color: Theme.of(context).colorScheme.primary,
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'OFFICIAL FOLLOW-UP',
                      style: TextStyle(
                        color: inkSoft,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .8,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${_comments.length} ${_comments.length == 1 ? 'reply' : 'replies'}',
                      style: const TextStyle(
                        color: navy,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary
                      .withValues(alpha: .09),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Semi-public',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              IconButton(
                tooltip: 'Refresh follow-up',
                style: IconButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.primary,
                ),
                visualDensity: VisualDensity.compact,
                onPressed: _loading ? null : _loadDiscussion,
                icon: _loading
                    ? SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      )
                    : Icon(
                        Icons.refresh_rounded,
                        color: Theme.of(context).colorScheme.primary,
                        size: 19,
                      ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          const Text(
            'Visible to the community. Only you and the response team can reply.',
            style: TextStyle(color: inkSoft, fontSize: 10, height: 1.45),
          ),
          if (_loadError != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: clay.withValues(alpha: .07),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.cloud_off_outlined, color: clay, size: 17),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _loadError!,
                      style: const TextStyle(
                        color: inkSoft,
                        fontSize: 10,
                        height: 1.4,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _loading ? null : _loadDiscussion,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ],
          if (_loading && _comments.isEmpty && _loadError == null) ...[
            const SizedBox(height: 20),
            Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ] else if (_comments.isEmpty && _loadError == null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                color: sand,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                widget.canReply
                    ? 'No follow-up replies yet. You can ask a question or share a helpful update below.'
                    : 'No follow-up replies yet.',
                style: TextStyle(color: inkSoft, fontSize: 10, height: 1.5),
              ),
            ),
          ] else if (_comments.isNotEmpty) ...[
            const SizedBox(height: 4),
            if (_expanded)
              SizedBox(
                height: 260,
                child: ListView(
                  controller: _threadController,
                  padding: EdgeInsets.zero,
                  children: [
                    for (final comment in visibleComments)
                      _ReportDiscussionReply(comment: comment),
                  ],
                ),
              )
            else
              for (final comment in visibleComments)
                _ReportDiscussionReply(comment: comment),
            if (_comments.length > 2) ...[
              Align(
                alignment: Alignment.center,
                child: TextButton.icon(
                  onPressed: _toggleExpanded,
                  icon: Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 19,
                  ),
                  label: Text(
                    _expanded
                        ? 'Show latest replies'
                        : 'View all ${_comments.length} replies',
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.primary,
                    textStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ],
          const SizedBox(height: 12),
          const Divider(height: 1, color: line),
          const SizedBox(height: 12),
          if (_repliesOpen && widget.canReply) ...[
            TextField(
              controller: _replyController,
              enabled: !_sending,
              minLines: 2,
              maxLines: 4,
              maxLength: reportCommentMaxLength,
              onChanged: (_) {
                if (_replyError != null) setState(() => _replyError = null);
              },
              decoration: InputDecoration(
                labelText: 'Reply to the follow-up',
                hintText: 'Ask a question or share an update…',
                alignLabelWithHint: true,
                counterStyle: const TextStyle(fontSize: 9, color: inkSoft),
                filled: true,
                fillColor: sand.withValues(alpha: .55),
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(13),
                  borderSide: const BorderSide(color: line),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(13),
                  borderSide: const BorderSide(color: line),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(13),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: infraAppearance.value.highContrast ? 3 : 1.5,
                  ),
                ),
              ),
            ),
            if (_replyError != null) ...[
              const SizedBox(height: 4),
              Text(
                _replyError!,
                style: const TextStyle(color: clay, fontSize: 10),
              ),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _sending ? null : _sendReply,
                icon: _sending
                    ? const SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded, size: 15),
                label: Text(_sending ? 'Sending…' : 'Send reply'),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ] else ...[
            Row(
              children: [
                const Icon(Icons.lock_outline, color: inkSoft, size: 15),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    _repliesOpen
                        ? 'Only the reporter and authorized staff can reply. Everyone can read this follow-up.'
                        : 'Replies are closed for ${widget.status.toLowerCase()} reports. You can still read the follow-up.',
                    style: const TextStyle(
                      color: inkSoft,
                      fontSize: 10,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ReportDiscussionReply extends StatelessWidget {
  const _ReportDiscussionReply({required this.comment});

  final Map<String, dynamic> comment;

  @override
  Widget build(BuildContext context) {
    final isResident = comment['author_role'] == 'resident';
    final createdAt = comment['created_at']?.toString() ?? '';
    final body = comment['body']?.toString() ?? '';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isResident ? sand : teal.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: isResident ? line : teal.withValues(alpha: .13),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isResident ? Icons.person_outline : Icons.support_agent,
                color: isResident ? inkSoft : teal,
                size: 15,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  comment['author_name']?.toString() ??
                      (isResident ? 'Resident' : 'Response team'),
                  style: const TextStyle(
                    color: navy,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (createdAt.isNotEmpty)
                Text(
                  _formatReportDate(createdAt),
                  textAlign: TextAlign.right,
                  style: const TextStyle(color: inkSoft, fontSize: 8.5),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: const TextStyle(color: ink, fontSize: 11, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _ReportRatingSection extends StatefulWidget {
  const _ReportRatingSection({required this.reportId});

  final String reportId;

  @override
  State<_ReportRatingSection> createState() => _ReportRatingSectionState();
}

class _ReportRatingSectionState extends State<_ReportRatingSection> {
  final _feedbackController = TextEditingController();
  Map<String, dynamic>? _savedRating;
  int? _selectedRating;
  bool _loading = true;
  bool _submitting = false;
  String? _error;
  String? _validationError;

  static const _ratingLabels = [
    'Needs improvement',
    'Fair',
    'Good',
    'Very good',
    'Excellent',
  ];

  @override
  void initState() {
    super.initState();
    _loadRating();
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _loadRating() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rating = await ApiService.reportRating(widget.reportId);
      if (!mounted) return;
      setState(() => _savedRating = rating);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitRating() async {
    final rating = _selectedRating;
    if (rating == null) {
      setState(() => _validationError = 'Choose a star rating to continue.');
      return;
    }
    setState(() {
      _submitting = true;
      _validationError = null;
      _error = null;
    });
    try {
      final saved = await ApiService.submitReportRating(
        reportId: widget.reportId,
        rating: rating,
        comment: _feedbackController.text.trim(),
      );
      if (!mounted) return;
      setState(() => _savedRating = saved);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _stars(int rating, {bool interactive = false}) => Row(
    mainAxisAlignment: interactive
        ? MainAxisAlignment.center
        : MainAxisAlignment.start,
    children: [
      for (var star = 1; star <= 5; star++)
        if (interactive)
          Semantics(
            button: true,
            selected: _selectedRating == star,
            label: '$star ${star == 1 ? 'star' : 'stars'}',
            child: IconButton(
              tooltip: '$star ${star == 1 ? 'star' : 'stars'}',
              onPressed: _submitting
                  ? null
                  : () => setState(() {
                      _selectedRating = star;
                      _validationError = null;
                    }),
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 43, minHeight: 43),
              padding: const EdgeInsets.all(4),
              icon: Icon(
                star <= (_selectedRating ?? 0)
                    ? Icons.star_rounded
                    : Icons.star_outline_rounded,
                size: 32,
                color: star <= (_selectedRating ?? 0) ? amber : line,
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(right: 2),
            child: Icon(
              star <= rating ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 19,
              color: star <= rating ? amber : line,
            ),
          ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final savedValue = int.tryParse('${_savedRating?['rating']}') ?? 0;
    final selectedLabel = _selectedRating == null
        ? 'Tap a star to rate the completed work'
        : _ratingLabels[_selectedRating! - 1];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: line),
        boxShadow: [
          BoxShadow(
            color: navy.withValues(alpha: .035),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: amber.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.rate_review_outlined,
                  color: amber,
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _savedRating == null ? 'HOW DID WE DO?' : 'YOUR FEEDBACK',
                      style: const TextStyle(
                        color: inkSoft,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .8,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _savedRating == null
                          ? 'Rate the completed work'
                          : 'Thank you for helping Mati improve',
                      style: const TextStyle(
                        color: navy,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          const Text(
            'Your rating helps the city team improve future repairs. You can rate each completed report once.',
            style: TextStyle(color: inkSoft, fontSize: 10, height: 1.45),
          ),
          if (_loading && _savedRating == null) ...[
            const SizedBox(height: 18),
            const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: amber),
              ),
            ),
            const SizedBox(height: 18),
          ] else if (_error != null && _savedRating == null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: clay.withValues(alpha: .07),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cloud_off_outlined, color: clay, size: 17),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: inkSoft,
                        fontSize: 10,
                        height: 1.4,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _loading ? null : _loadRating,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ] else if (_savedRating != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                _stars(savedValue),
                const SizedBox(width: 8),
                Text(
                  _ratingLabels[(savedValue.clamp(1, 5)) - 1],
                  style: const TextStyle(
                    color: navy,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            if ((_savedRating?['comment']?.toString() ?? '').trim().isNotEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: sand,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _savedRating!['comment'].toString(),
                  style: const TextStyle(
                    color: ink,
                    fontSize: 11,
                    height: 1.45,
                  ),
                ),
              ),
          ] else ...[
            const SizedBox(height: 8),
            _stars(0, interactive: true),
            Center(
              child: Text(
                selectedLabel,
                style: const TextStyle(
                  color: inkSoft,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _feedbackController,
              enabled: !_submitting,
              minLines: 2,
              maxLines: 4,
              maxLength: reportRatingCommentMaxLength,
              decoration: InputDecoration(
                labelText: 'Optional feedback',
                hintText: 'Tell us what went well or could be better',
                alignLabelWithHint: true,
                counterStyle: const TextStyle(fontSize: 9, color: inkSoft),
                filled: true,
                fillColor: sand.withValues(alpha: .55),
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(13),
                  borderSide: const BorderSide(color: line),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(13),
                  borderSide: const BorderSide(color: line),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(13),
                  borderSide: const BorderSide(color: amber, width: 1.5),
                ),
              ),
            ),
            if (_validationError != null) ...[
              const SizedBox(height: 3),
              Text(
                _validationError!,
                style: const TextStyle(color: clay, fontSize: 10),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 3),
              Text(_error!, style: const TextStyle(color: clay, fontSize: 10)),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _submitting ? null : _submitRating,
                icon: _submitting
                    ? const SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.star_rounded, size: 16),
                label: Text(_submitting ? 'Saving…' : 'Submit rating'),
                style: FilledButton.styleFrom(
                  backgroundColor: amber,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReportProgressCard extends StatelessWidget {
  const _ReportProgressCard({
    required this.progressPercentage,
    required this.updates,
    required this.statusHistory,
  });

  final int progressPercentage;
  final List<Map<String, dynamic>> updates;
  final List<Map<String, dynamic>> statusHistory;

  bool get _wasInspected =>
      statusHistory.any((event) => event['status'] == 'Verified by inspector');

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: line),
      boxShadow: [
        BoxShadow(
          color: navy.withValues(alpha: .035),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: teal.withValues(alpha: .11),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.handyman_outlined, color: teal, size: 19),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CITY TEAM PROGRESS',
                    style: TextStyle(
                      color: inkSoft,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .9,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Work is underway',
                    style: TextStyle(
                      color: navy,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '$progressPercentage%',
              style: infraHeading(
                color: teal,
                fontSize: 19,
                weight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 17),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progressPercentage / 100,
            minHeight: 6,
            color: teal,
            backgroundColor: teal.withValues(alpha: .12),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _ReportProgressStage(label: 'Reported', complete: true),
            _ReportProgressConnector(complete: true),
            _ReportProgressStage(label: 'Inspected', complete: _wasInspected),
            _ReportProgressConnector(complete: _wasInspected),
            const _ReportProgressStage(
              label: 'In progress',
              complete: true,
              active: true,
            ),
            const _ReportProgressConnector(complete: false),
            const _ReportProgressStage(label: 'Resolved', complete: false),
          ],
        ),
        const SizedBox(height: 16),
        const Divider(height: 1, color: line),
        const SizedBox(height: 13),
        Row(
          children: [
            const Icon(Icons.notes_rounded, size: 16, color: teal),
            const SizedBox(width: 7),
            Text(
              updates.isEmpty ? 'Progress update' : 'Updates from city team',
              style: const TextStyle(
                color: navy,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (updates.isEmpty)
          const Text(
            'The city team has not posted a progress note yet. Check back for updates.',
            style: TextStyle(color: inkSoft, fontSize: 11, height: 1.45),
          )
        else
          for (final update in updates)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: _ReportProgressUpdate(update: update),
            ),
      ],
    ),
  );
}

class _ReportProgressStage extends StatelessWidget {
  const _ReportProgressStage({
    required this.label,
    required this.complete,
    this.active = false,
  });

  final String label;
  final bool complete;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = complete ? teal : line;
    return SizedBox(
      width: 54,
      child: Column(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: complete ? color : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: color, width: active ? 2 : 1.4),
            ),
            child: Icon(
              active
                  ? Icons.handyman_outlined
                  : complete
                  ? Icons.check_rounded
                  : Icons.circle_outlined,
              size: active ? 12 : 13,
              color: complete ? Colors.white : inkSoft,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: TextStyle(
              color: active
                  ? navy
                  : complete
                  ? inkSoft
                  : inkSoft,
              fontSize: 8,
              height: 1.15,
              fontWeight: active ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportProgressConnector extends StatelessWidget {
  const _ReportProgressConnector({required this.complete});

  final bool complete;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      height: 2,
      margin: const EdgeInsets.only(bottom: 19),
      color: complete ? teal.withValues(alpha: .55) : line,
    ),
  );
}

class _ReportProgressUpdate extends StatelessWidget {
  const _ReportProgressUpdate({required this.update});

  final Map<String, dynamic> update;

  @override
  Widget build(BuildContext context) {
    final note = update['note']?.toString().trim() ?? '';
    final createdAt = update['created_at']?.toString() ?? '';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: sand.withValues(alpha: .75),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (createdAt.isNotEmpty)
            Text(
              _formatReportDate(createdAt),
              style: const TextStyle(
                color: inkSoft,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          if (createdAt.isNotEmpty) const SizedBox(height: 4),
          Text(
            note,
            style: const TextStyle(color: ink, fontSize: 11, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _DetailsBackButton extends StatelessWidget {
  const _DetailsBackButton({required this.onPressed});
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white.withValues(alpha: .78),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: IconButton(
      onPressed: onPressed,
      icon: const Icon(Icons.arrow_back, color: navy),
    ),
  );
}

class _DetailMetaChip extends StatelessWidget {
  const _DetailMetaChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .68),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.white.withValues(alpha: .9)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: teal),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(color: inkSoft, fontSize: 10)),
      ],
    ),
  );
}

class _DetailsHero extends StatelessWidget {
  const _DetailsHero({required this.report});
  final ({
    String title,
    String reportId,
    String description,
    String location,
    String category,
    String severity,
    String assignedTeam,
    String resolutionNote,
    int progressPercentage,
    List<Map<String, dynamic>> progressUpdates,
    List<Map<String, dynamic>> statusHistory,
    String coordinates,
    String age,
    String image,
    String status,
    Color color,
    IconData icon,
  })
  report;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(22),
    child: SizedBox(
      height: 210,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (report.image.isEmpty)
            Container(
              color: report.color.withValues(alpha: .18),
              child: Icon(report.icon, size: 58, color: report.color),
            )
          else
            Image.network(
              report.image,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                color: report.color.withValues(alpha: .18),
                child: Icon(report.icon, size: 58, color: report.color),
              ),
            ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.transparent, Color(0xCC092732)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: StatusPill(label: report.status, color: report.color),
          ),
          Positioned(
            left: 16,
            bottom: 14,
            child: Row(
              children: [
                Icon(report.icon, color: Colors.white, size: 16),
                const SizedBox(width: 6),
                const Text(
                  'COMMUNITY REPORT',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .8,
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
