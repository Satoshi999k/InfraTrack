part of '../main.dart';

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
      final category = item['category'] as String? ?? 'Roads';
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
        coordinates: item['latitude'] == null || item['longitude'] == null
            ? item['location']?.toString() ?? 'Mati City'
            : 'Lat ${item['latitude']}, Lon ${item['longitude']}',
        watchers: 'Report activity',
        age: item['created_at']?.toString() ?? '',
        image: publicMediaUrl(item['media_url'] as String?) ?? '',
        status: status,
        color: color,
        icon: category == 'Water'
            ? Icons.water_drop
            : category == 'Lighting'
            ? Icons.lightbulb_outline
            : Icons.construction,
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
          child: AppScroll(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Material(
                      color: Colors.white.withValues(alpha: .72),
                      shape: const CircleBorder(),
                      child: IconButton(
                        onPressed: () => Navigator.pop(context),
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
                        number: '${_serverReports.length}',
                        label: 'Total',
                        color: navy,
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: _ReportSummary(
                        number: '$openCount',
                        label: 'Open',
                        color: clay,
                      ),
                    ),
                    SizedBox(width: 8),
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
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      [
                            'All',
                            'Reported',
                            'Verified by inspector',
                            'In progress',
                            'Scheduled for repair',
                            'Resolved',
                          ]
                          .map(
                            (item) => FilterChip(
                              label: Text(item),
                              selected: filter == item,
                              showCheckmark: false,
                              onSelected: (_) => setState(() => filter = item),
                              selectedColor: navy.withValues(alpha: .94),
                              backgroundColor: Colors.transparent,
                              side: BorderSide(
                                color: filter == item ? navy : line,
                              ),
                              shape: const StadiumBorder(),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 2,
                              ),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              visualDensity: const VisualDensity(
                                horizontal: -2,
                                vertical: -2,
                              ),
                              labelStyle: TextStyle(
                                color: filter == item ? Colors.white : inkSoft,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )
                          .toList(),
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
                      '${visible.length} shown',
                      style: const TextStyle(color: inkSoft, fontSize: 10),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_loading)
                  const Center(child: CircularProgressIndicator())
                else if (_loadError != null)
                  Text(_loadError!, style: const TextStyle(color: clay))
                else if (visible.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      ApiService.isSignedIn
                          ? 'You have not submitted any reports yet.'
                          : 'Sign in to see your reports.',
                      style: const TextStyle(color: inkSoft),
                    ),
                  )
                else
                  ...visible.map((item) => _MyReportCard(report: item)),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
    String coordinates,
    String watchers,
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
    color: Colors.white.withValues(alpha: .88),
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: BorderSide(color: Colors.white.withValues(alpha: .95)),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => MyReportDetailsPage(report: report)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 4,
              height: 66,
              decoration: BoxDecoration(
                color: report.color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: SizedBox(
                width: 66,
                height: 66,
                child: Image.network(
                  report.image,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: report.color.withValues(alpha: .12),
                    child: Icon(report.icon, color: report.color, size: 25),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          report.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: infraHeading(
                            color: ink,
                            fontSize: 12.5,
                            weight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      StatusPill(label: report.status, color: report.color),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    report.coordinates,
                    style: infraMono(fontSize: 9, color: inkSoft),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.visibility_outlined,
                        size: 13,
                        color: inkSoft,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        report.watchers,
                        style: const TextStyle(color: inkSoft, fontSize: 10),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        report.age,
                        style: infraMono(fontSize: 9.5, color: inkSoft),
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
    String coordinates,
    String watchers,
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
              Text(
                'Report ID: ${report.reportId} ? Filed ${report.age}',
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
    String coordinates,
    String watchers,
    String age,
    String image,
    String status,
    Color color,
    IconData icon,
  })
  report,
) => report.location;

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
    String coordinates,
    String watchers,
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
