part of '../main.dart';

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
    final reports = _serverReports.map((item) {
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
        progressPercentage:
            (int.tryParse('${item['progress_percentage']}') ?? 0).clamp(0, 100),
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
    }).toList();
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
      backgroundColor: sand,
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
    color: sand,
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
                color: Colors.white.withValues(alpha: .72),
                shape: const CircleBorder(),
                child: IconButton(
                  onPressed: onBack,
                  tooltip: 'Back',
                  icon: const Icon(Icons.arrow_back, color: navy),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ACTIVITY CENTER',
                      style: TextStyle(
                        color: teal,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                    Text(
                      'My reports',
                      style: infraHeading(
                        color: navy,
                        fontSize: 24,
                        weight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.only(left: 4, top: 2, bottom: 18),
            child: Text(
              'Your contribution to a safer, better Mati City.',
              style: TextStyle(color: inkSoft, fontSize: 12, height: 1.3),
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
                          color: filter == item.$1 ? Colors.white : inkSoft,
                        ),
                        label: Text(item.$1),
                        selected: filter == item.$1,
                        showCheckmark: false,
                        onSelected: (_) => onFilterChanged(item.$1),
                        selectedColor: navy.withValues(alpha: .94),
                        backgroundColor: Colors.transparent,
                        side: BorderSide(
                          color: filter == item.$1 ? navy : line,
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
                          color: filter == item.$1 ? Colors.white : inkSoft,
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
                  color: navy,
                  fontSize: 13,
                  weight: FontWeight.w800,
                ),
              ),
              Text(
                '$visibleCount shown',
                style: const TextStyle(color: inkSoft, fontSize: 10),
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
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    color: Colors.white,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: const BorderSide(color: line),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => MyReportDetailsPage(report: report)),
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
                                style: const TextStyle(
                                  color: teal,
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
                      color: ink,
                      fontSize: 13,
                      weight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: inkSoft,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          report.location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: inkSoft,
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
                      const Icon(
                        Icons.schedule_rounded,
                        size: 13,
                        color: inkSoft,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Filed ${_formatReportDate(report.age)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: inkSoft, fontSize: 9.5),
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
  const MyReportDetailsPage({super.key, required this.report});

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

  bool get resolved => report.status == 'Resolved';

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: sand,
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
              if (report.status == 'In progress') ...[
                const SizedBox(height: 18),
                _ReportProgressCard(
                  progressPercentage: report.progressPercentage,
                  updates: report.progressUpdates,
                  statusHistory: report.statusHistory,
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
