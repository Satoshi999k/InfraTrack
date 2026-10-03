part of '../main.dart';

class MyReportsPage extends StatefulWidget {
  const MyReportsPage({super.key});
  @override
  State<MyReportsPage> createState() => _MyReportsPageState();
}

class _MyReportsPageState extends State<MyReportsPage> {
  String filter = 'All';
  List<Map<String, dynamic>> _serverReports = [];
  final _fallbackReports = const [
    (
      title: 'No water supply, Purok 3',
      coordinates: '6.9482° N, 126.2311° E',
      watchers: '87 watching',
      age: '5h ago',
      image: 'https://images.unsplash.com/photo-1548838134-2c43a5e9c3c5?auto=format&fit=crop&w=240&q=80',
      status: 'In progress',
      color: teal,
      icon: Icons.water_drop,
    ),
    (
      title: 'Clogged drainage near market',
      coordinates: '6.9511° N, 126.2249° E',
      watchers: '43 watching',
      age: '1d ago',
      image: 'https://images.unsplash.com/photo-1577558678587-4a8af447679c?auto=format&fit=crop&w=240&q=80',
      status: 'Reported',
      color: amber,
      icon: Icons.water_damage_outlined,
    ),
    (
      title: 'Streetlight repaired, J.P. Laurel',
      coordinates: '6.9498° N, 126.2295° E',
      watchers: '19 watching',
      age: '2d ago',
      image: 'https://images.unsplash.com/photo-1543518360-68b9612a7c8c?auto=format&fit=crop&w=240&q=80',
      status: 'Resolved',
      color: green,
      icon: Icons.lightbulb_outline,
    ),
    (
      title: 'Cracked pavement, Chapel St.',
      coordinates: '6.9503° N, 126.2264° E',
      watchers: '31 watching',
      age: '1w ago',
      image: 'https://images.unsplash.com/photo-1558690194-5aaa922b59b6?auto=format&fit=crop&w=240&q=80',
      status: 'Resolved',
      color: green,
      icon: Icons.construction,
    ),
    (
      title: 'Overflowing canal, Purok 3',
      coordinates: '6.9489° N, 126.2318° E',
      watchers: '22 watching',
      age: '2w ago',
      image: 'https://images.unsplash.com/photo-1584982751601-97dcc096659c?auto=format&fit=crop&w=240&q=80',
      status: 'Resolved',
      color: green,
      icon: Icons.water_damage_outlined,
    ),
  ];

  @override
  void initState() {
    super.initState();
    ApiService.reports()
        .then((items) {
          if (mounted) setState(() => _serverReports = items);
        })
        .catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final reports = _serverReports.isEmpty
        ? _fallbackReports
        : _serverReports.map((item) {
            final status = item['status'] as String? ?? 'Reported';
            final category = item['category'] as String? ?? 'Roads';
            final color = status == 'Resolved'
                ? green
                : status == 'In progress'
                ? teal
                : clay;
            return (
              title: item['title'] as String? ?? 'Infrastructure report',
              coordinates:
                  '${item['latitude'] ?? 0}° N, ${item['longitude'] ?? 0}° E',
              watchers: '0 watching',
              age: item['created_at'] as String? ?? 'recently',
              image: '',
              status: status,
              color: color,
              icon: category == 'Water'
                  ? Icons.water_drop
                  : category == 'Lighting'
                  ? Icons.lightbulb_outline
                  : Icons.construction,
            );
          }).toList();
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
                  children: const [
                    Expanded(
                      child: _ReportSummary(
                        number: '12',
                        label: 'Total',
                        color: navy,
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: _ReportSummary(
                        number: '3',
                        label: 'Open',
                        color: clay,
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: _ReportSummary(
                        number: '9',
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
                  children: ['All', 'Reported', 'In progress', 'Resolved']
                      .map(
                        (item) => FilterChip(
                          label: Text(item),
                          selected: filter == item,
                          showCheckmark: false,
                          onSelected: (_) => setState(() => filter = item),
                          selectedColor: navy.withValues(alpha: .94),
                          backgroundColor: Colors.transparent,
                          side: BorderSide(color: filter == item ? navy : line),
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
                'Report ID: #MT-2026-${report.title.hashCode.abs() % 900 + 100}  ·  Filed ${report.age}',
                style: infraMono(fontSize: 9, color: inkSoft),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _DetailMetaChip(
                    icon: Icons.people_alt_outlined,
                    label: report.watchers,
                  ),
                  const _DetailMetaChip(
                    icon: Icons.visibility_outlined,
                    label: '512 views',
                  ),
                  _DetailMetaChip(icon: report.icon, label: report.status),
                ],
              ),
              const SizedBox(height: 18),
              const Divider(color: line),
              const SizedBox(height: 14),
              Text(
                resolved ? 'Before & after' : 'Repair progress',
                style: infraHeading(
                  color: navy,
                  fontSize: 16,
                  weight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              if (resolved) ...[
                _BeforeAfterImage(
                  label: 'Before',
                  image: report.image,
                  color: Colors.black87,
                ),
                const SizedBox(height: 10),
                _BeforeAfterImage(
                  label: 'After',
                  image: report.image,
                  color: report.color,
                ),
                const SizedBox(height: 14),
                const _ResolutionNote(),
                const SizedBox(height: 16),
                const _RatingCard(),
              ] else ...[
                const _ProgressTimeline(),
                const SizedBox(height: 18),
                const _DiscussionCard(),
              ],
              const SizedBox(height: 18),
              const _TimelineLogs(),
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
    String coordinates,
    String watchers,
    String age,
    String image,
    String status,
    Color color,
    IconData icon,
  })
  report,
) {
  if (report.title.contains('Streetlight')) {
    return 'J.P. Laurel Ave., Brgy. Sainz';
  }
  if (report.title.contains('drainage') || report.title.contains('canal')) {
    return 'Public Market, Brgy. Central';
  }
  return 'Purok 3, Brgy. Dawan';
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

class _BeforeAfterImage extends StatelessWidget {
  const _BeforeAfterImage({
    required this.label,
    required this.image,
    required this.color,
  });
  final String label, image;
  final Color color;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(18),
    child: SizedBox(
      height: 128,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            image,
            fit: BoxFit.cover,
            color: color.withValues(alpha: .30),
            colorBlendMode: BlendMode.overlay,
          ),
          Positioned(
            left: 12,
            bottom: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ProgressTimeline extends StatelessWidget {
  const _ProgressTimeline();
  @override
  Widget build(BuildContext context) => const Column(
    children: [
      _ProgressStep(
        title: 'Reported & logged',
        detail: 'Ticket created by citizen · Aug 2, 09:20 AM',
        complete: true,
      ),
      _ProgressStep(
        title: 'Verified by inspector',
        detail: 'Site inspection completed · Aug 3, 02:45 PM',
        complete: true,
      ),
      _ProgressStep(
        title: 'Scheduled for repair',
        detail: 'Work order issued to Team Alpha · Aug 5',
        complete: true,
      ),
      _ProgressStep(
        title: 'Completion & audit',
        detail: 'Final review and closure',
        complete: false,
        last: true,
      ),
    ],
  );
}

class _ProgressStep extends StatelessWidget {
  const _ProgressStep({
    required this.title,
    required this.detail,
    required this.complete,
    this.last = false,
  });
  final String title, detail;
  final bool complete, last;
  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 28,
          child: Column(
            children: [
              CircleAvatar(
                radius: 11,
                backgroundColor: complete ? green : Colors.white,
                child: Icon(
                  complete ? Icons.check : Icons.circle_outlined,
                  size: 14,
                  color: complete ? Colors.white : line,
                ),
              ),
              if (!last)
                Expanded(
                  child: Container(width: 2, color: complete ? green : line),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  detail,
                  style: const TextStyle(color: inkSoft, fontSize: 10),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _DiscussionCard extends StatelessWidget {
  const _DiscussionCard();
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Official discussion',
            style: infraHeading(
              color: navy,
              fontSize: 16,
              weight: FontWeight.w800,
            ),
          ),
          const StatusPill(label: 'Semi-public', color: teal),
        ],
      ),
      const SizedBox(height: 10),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'LGU Admin',
                    style: TextStyle(color: navy, fontWeight: FontWeight.w800),
                  ),
                  Text(
                    '1h ago',
                    style: TextStyle(color: inkSoft, fontSize: 10),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'We have received your report. A maintenance crew has been scheduled. Please let us know if you have any other concerns.',
                style: TextStyle(color: ink, fontSize: 11, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

class _ResolutionNote extends StatelessWidget {
  const _ResolutionNote();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFE2F3F0),
      borderRadius: BorderRadius.circular(16),
      border: const Border(left: BorderSide(color: teal, width: 3)),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.verified, color: teal, size: 18),
        SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'OFFICIAL RESOLUTION NOTE',
                style: TextStyle(
                  color: teal,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 5),
              Text(
                'Maintenance Team Delta replaced the faulty wiring and upgraded the bulb to a high-efficiency LED unit. Thank you for your report!',
                style: TextStyle(color: navy, fontSize: 11, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _RatingCard extends StatelessWidget {
  const _RatingCard();
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
      child: Column(
        children: [
          Text(
            'Rate the resolution',
            style: infraHeading(
              color: navy,
              fontSize: 15,
              weight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '★ ★ ★ ★ ★',
            style: TextStyle(
              color: Color(0xFFD7CEBF),
              fontSize: 28,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 10),
          const TextField(
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Tell us more about the repair...',
            ),
          ),
          const SizedBox(height: 10),
          const SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: null,
              child: Text('Submit feedback'),
            ),
          ),
        ],
      ),
    ),
  );
}

class _TimelineLogs extends StatelessWidget {
  const _TimelineLogs();
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Timeline logs',
            style: infraHeading(
              color: navy,
              fontSize: 16,
              weight: FontWeight.w800,
            ),
          ),
          const Text(
            'See all',
            style: TextStyle(
              color: teal,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      const _LogItem(
        title: 'Maintenance crew scheduled',
        detail:
            'Repair team assigned to sector B-12. Target start date: Aug 8.',
        date: 'Aug 5',
      ),
      const _LogItem(
        title: 'Inspector assigned',
        detail: 'Engr. Santos has been assigned to verify this report.',
        date: 'Aug 3',
      ),
      const _LogItem(
        title: 'Report submitted',
        detail: 'Citizen report filed with photo evidence and GPS coordinates.',
        date: 'Aug 2',
      ),
    ],
  );
}

class _LogItem extends StatelessWidget {
  const _LogItem({
    required this.title,
    required this.detail,
    required this.date,
  });
  final String title, detail, date;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.fromLTRB(12, 0, 0, 10),
    decoration: const BoxDecoration(
      border: Border(
        left: BorderSide(color: teal, width: 3),
        bottom: BorderSide(color: line),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: ink,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(date, style: infraMono(fontSize: 9, color: inkSoft)),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          detail,
          style: const TextStyle(color: inkSoft, fontSize: 10, height: 1.35),
        ),
      ],
    ),
  );
}
