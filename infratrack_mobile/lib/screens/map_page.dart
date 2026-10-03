part of '../main.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  static const _matiCity = LatLng(6.9551, 126.2166);
  final _mapController = MapController();
  final _searchController = TextEditingController();
  String? _selectedReport;
  String _activeCategory = 'All';
  double _zoom = 15;
  bool _showLegend = false;
  bool _satelliteView = false;
  List<_MapReport> _reports = [];
  bool _loadingReports = true;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    try {
      final issues = await ApiService.issues();
      if (!mounted) return;
      setState(() {
        _reports = issues.map(_mapReportFromIssue).toList();
        _loadingReports = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingReports = false);
    }
  }

  _MapReport _mapReportFromIssue(Map<String, dynamic> issue) {
    final latitude =
        double.tryParse('${issue['latitude']}') ?? _matiCity.latitude;
    final longitude =
        double.tryParse('${issue['longitude']}') ?? _matiCity.longitude;
    return _MapReport(
      title: issue['title'] as String? ?? 'Infrastructure report',
      category: issue['category'] as String? ?? 'Other',
      color: _issueColor(issue),
      point: LatLng(latitude, longitude),
    );
  }

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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_MapReport> get _visibleReports {
    final query = _searchController.text.trim().toLowerCase();
    return _reports.where((report) {
      final matchesCategory =
          _activeCategory == 'All' || report.category == _activeCategory;
      final matchesSearch =
          query.isEmpty ||
          report.title.toLowerCase().contains(query) ||
          report.category.toLowerCase().contains(query);
      return matchesCategory && matchesSearch;
    }).toList();
  }

  void _changeZoom(double amount) {
    _zoom = (_zoom + amount).clamp(12, 19);
    _mapController.move(_matiCity, _zoom);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => PageEntrance(
    child: Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _matiCity,
            initialZoom: _zoom,
            minZoom: 12,
            maxZoom: 19,
            onPositionChanged: (position, _) {
              if (position.zoom != _zoom) {
                _zoom = position.zoom;
              }
            },
            onTap: (_, _) => setState(() => _selectedReport = null),
          ),
          children: [
            TileLayer(
              urlTemplate: _satelliteView
                  ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                  : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.infratrack.mobile',
            ),
            MarkerLayer(
              markers: [
                for (final report in _visibleReports)
                  Marker(
                    point: report.point,
                    width: 54,
                    height: 64,
                    child: GestureDetector(
                      onTap: () =>
                          setState(() => _selectedReport = report.title),
                      child: _ReportMarker(
                        color: report.color,
                        selected: _selectedReport == report.title,
                      ),
                    ),
                  ),
              ],
            ),
            RichAttributionWidget(
              attributions: [
                TextSourceAttribution(
                  _satelliteView
                      ? 'Tiles © Esri — Source: Esri, Maxar, Earthstar Geographics'
                      : 'OpenStreetMap contributors',
                ),
              ],
            ),
          ],
        ),
        Positioned(
          top: 12,
          left: 16,
          right: 16,
          child: Material(
            elevation: 5,
            shadowColor: navy.withValues(alpha: .24),
            borderRadius: BorderRadius.circular(16),
            color: Colors.white,
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() => _selectedReport = null),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search street or barangay',
                prefixIcon: const Icon(Icons.search, color: inkSoft),
                suffixIcon: _searchController.text.isEmpty
                    ? const Icon(Icons.tune, color: inkSoft)
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.close, color: inkSoft),
                      ),
                filled: true,
                fillColor: Colors.white,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 15),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 78,
          left: 16,
          right: 16,
          child: SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final category in const [
                  'All',
                  'Roads',
                  'Water',
                  'Drainage',
                  'Lighting',
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _MapFilterChip(
                      label: category,
                      selected: _activeCategory == category,
                      onTap: () => setState(() {
                        _activeCategory = category;
                        _selectedReport = null;
                      }),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (_selectedReport != null)
          Positioned(
            top: 128,
            left: 16,
            right: 16,
            child: _ReportCallout(
              report: _reports.firstWhere(
                (item) => item.title == _selectedReport,
              ),
              onClose: () => setState(() => _selectedReport = null),
            ),
          ),
        Positioned(
          right: 16,
          top: 132,
          child: Column(
            children: [
              _MapControlButton(
                icon: Icons.add,
                tooltip: 'Zoom in',
                onPressed: () => _changeZoom(1),
              ),
              const SizedBox(height: 6),
              _MapControlButton(
                icon: Icons.remove,
                tooltip: 'Zoom out',
                onPressed: () => _changeZoom(-1),
              ),
              const SizedBox(height: 12),
              _MapControlButton(
                icon: Icons.my_location,
                tooltip: 'Center on Mati City',
                onPressed: () {
                  _mapController.move(_matiCity, 15);
                  setState(() => _zoom = 15);
                },
              ),
              const SizedBox(height: 12),
              _MapControlButton(
                icon: Icons.satellite_alt,
                tooltip: _satelliteView
                    ? 'Switch to street view'
                    : 'Switch to satellite view',
                selected: _satelliteView,
                onPressed: () => setState(() {
                  _satelliteView = !_satelliteView;
                }),
              ),
            ],
          ),
        ),
        Positioned(
          bottom: 18,
          left: 16,
          right: 16,
          child: Material(
            elevation: 5,
            color: Colors.white,
            borderRadius: BorderRadius.circular(17),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => setState(() => _showLegend = !_showLegend),
              child: AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 13, 16, 12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: teal.withValues(alpha: .12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.layers_outlined,
                              color: teal,
                            ),
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _loadingReports
                                      ? 'Loading reports…'
                                      : '${_visibleReports.length} reports in this area',
                                  style: infraHeading(
                                    color: navy,
                                    fontSize: 13,
                                    weight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _showLegend
                                      ? 'Tap a category to filter the map'
                                      : 'Tap to view map legend',
                                  style: const TextStyle(
                                    color: inkSoft,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            _showLegend
                                ? Icons.keyboard_arrow_down
                                : Icons.keyboard_arrow_up,
                            color: inkSoft,
                          ),
                        ],
                      ),
                      if (_showLegend) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Divider(height: 1),
                        ),
                        for (final item in _legendItems)
                          _MapLegendRow(
                            label: item.$1,
                            color: item.$2,
                            count: item.$3,
                            selected: _activeCategory == item.$1,
                            onTap: () => setState(() {
                              _activeCategory = item.$1;
                              _selectedReport = null;
                            }),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  List<(String, Color, int)> get _legendItems => [
    ('All', navy, _reports.length),
    for (final category in const ['Roads', 'Water', 'Drainage', 'Lighting'])
      if (_reports.any((report) => report.category == category))
        (
          category,
          _reports.firstWhere((report) => report.category == category).color,
          _reports.where((report) => report.category == category).length,
        ),
  ];
}

class _MapReport {
  const _MapReport({
    required this.title,
    required this.category,
    required this.color,
    required this.point,
  });

  final String title;
  final String category;
  final Color color;
  final LatLng point;
}

class _MapFilterChip extends StatelessWidget {
  const _MapFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? navy : Colors.white,
    elevation: selected ? 3 : 2,
    shadowColor: navy.withValues(alpha: .18),
    borderRadius: BorderRadius.circular(20),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : navy,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ),
  );
}

class _MapControlButton extends StatelessWidget {
  const _MapControlButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.selected = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? teal : Colors.white,
    elevation: 4,
    shadowColor: navy.withValues(alpha: .22),
    borderRadius: BorderRadius.circular(12),
    child: IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      color: selected ? Colors.white : navy,
      icon: Icon(icon, size: 21),
      constraints: const BoxConstraints.tightFor(width: 44, height: 44),
    ),
  );
}

class _MapLegendRow extends StatelessWidget {
  const _MapLegendRow({
    required this.label,
    required this.color,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? navy : ink,
                  fontSize: 11.5,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                ),
              ),
            ),
            Text(
              '$count open',
              style: TextStyle(
                color: selected ? color : inkSoft,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (selected) ...[
              const SizedBox(width: 7),
              Icon(Icons.check_circle, color: color, size: 16),
            ],
          ],
        ),
      ),
    ),
  );
}

class _ReportMarker extends StatelessWidget {
  const _ReportMarker({required this.color, required this.selected});

  final Color color;
  final bool selected;

  @override
  Widget build(BuildContext context) => AnimatedScale(
    scale: selected ? 1.18 : 1,
    duration: const Duration(milliseconds: 150),
    child: Icon(Icons.location_on, color: color, size: 42),
  );
}

class _ReportCallout extends StatelessWidget {
  const _ReportCallout({required this.report, required this.onClose});

  final _MapReport report;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Card(
    elevation: 5,
    child: ListTile(
      leading: Icon(Icons.warning_amber_rounded, color: report.color),
      title: Text(
        report.title,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(report.category),
      trailing: IconButton(
        tooltip: 'Close report details',
        onPressed: onClose,
        icon: const Icon(Icons.close),
      ),
    ),
  );
}
