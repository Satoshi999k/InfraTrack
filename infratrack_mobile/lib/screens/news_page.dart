part of '../main.dart';

class NewsPage extends StatefulWidget {
  const NewsPage({super.key});

  @override
  State<NewsPage> createState() => _NewsPageState();
}

class _NewsPageState extends State<NewsPage> {
  final _pageController = PageController();
  Timer? _rotationTimer;
  int _currentPage = 0;
  String _selectedCategory = 'All';
  List<Map<String, dynamic>> _advisories = [];
  List<Map<String, dynamic>> _issues = [];
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadNews();
    _rotationTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_pageController.hasClients || _stories.isEmpty) return;
      _pageController.animateToPage(
        (_currentPage + 1) % _stories.length,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    });
  }

  Future<void> _loadNews() async {
    try {
      final results = await Future.wait([
        ApiService.advisories(),
        ApiService.issues(),
      ]);
      if (!mounted) return;
      setState(() {
        _advisories = results[0];
        _issues = results[1];
        _loading = false;
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

  List<({String image, String title, String subtitle})> get _stories =>
      _advisories.map((advisory) {
        final mediaUrl = advisory['media_url'] as String?;
        return (
          image: mediaUrl ?? '',
          title: advisory['title'] as String? ?? 'City advisory',
          subtitle: _advisoryType(advisory['type'] as String?),
        );
      }).toList();

  String _advisoryType(String? type) => switch (type) {
    'alert' => 'Emergency alert',
    'maint' => 'Maintenance advisory',
    _ => 'Public announcement',
  };

  List<Map<String, dynamic>> get _visibleIssues => _issues.where((issue) {
    final status = issue['status'] as String? ?? '';
    final category = issue['category'] as String? ?? '';
    if (_selectedCategory == 'Repairs') return status == 'Resolved';
    if (_selectedCategory == 'Construction') {
      return category == 'Roads' && status != 'Resolved';
    }
    if (_selectedCategory == 'Maintenance') return category != 'Roads';
    return true;
  }).toList();

  @override
  void dispose() {
    _rotationTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PageEntrance(
    child: AppScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppHeader(
            eyebrow: 'PUBLIC ADVISORY · INFRASTRUCTURE MEDIA',
            title: 'City updates',
          ),
          if (_stories.isNotEmpty)
            _NewsHeroCarousel(
              stories: _stories,
              controller: _pageController,
              currentPage: _currentPage,
              onPageChanged: (page) => setState(() => _currentPage = page),
            ),
          const SizedBox(height: 14),
          _NewsFilterBar(
            selectedCategory: _selectedCategory,
            onCategorySelected: (category) =>
                setState(() => _selectedCategory = category),
          ),
          const SizedBox(height: 18),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(child: CircularProgressIndicator(color: teal)),
            )
          else if (_loadError != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(_loadError!, style: const TextStyle(color: clay)),
            )
          else ...[
            for (final issue in _visibleIssues)
              NewsCard(
                icon: _issueIcon(issue),
                title: issue['title'] as String? ?? 'Infrastructure report',
                body:
                    '${issue['status'] ?? 'Reported'} · ${issue['location'] ?? 'Mati City'}',
                color: _issueColor(issue),
              ),
            const SectionTitle(title: 'Advisories'),
            if (_advisories.isEmpty)
              const NewsCard(
                icon: Icons.campaign_outlined,
                title: 'No current advisories',
                body: 'New city advisories from the LGU will appear here.',
                color: red,
              )
            else
              ..._advisories.map(
                (advisory) => _PublicAdvisoryCard(advisory: advisory),
              ),
          ],
        ],
      ),
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
}

class _PublicAdvisoryCard extends StatelessWidget {
  const _PublicAdvisoryCard({required this.advisory});

  final Map<String, dynamic> advisory;

  @override
  Widget build(BuildContext context) {
    final type = advisory['type'] as String? ?? 'gen';
    final color = type == 'alert'
        ? red
        : type == 'maint'
        ? amber
        : teal;
    final mediaUrl = publicMediaUrl(advisory['media_url'] as String?);
    final mediaKind = advisory['media_kind'] as String?;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (mediaUrl != null) _AdvisoryMedia(url: mediaUrl, kind: mediaKind),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type == 'alert'
                      ? 'EMERGENCY ALERT'
                      : type == 'maint'
                      ? 'MAINTENANCE'
                      : 'ANNOUNCEMENT',
                  style: TextStyle(
                    color: color,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .8,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  advisory['title'] as String? ?? 'City advisory',
                  style: infraHeading(
                    color: navy,
                    fontSize: 15,
                    weight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  advisory['message'] as String? ?? '',
                  style: const TextStyle(
                    color: inkSoft,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                if (mediaKind != null) ...[
                  const SizedBox(height: 7),
                  Text(
                    mediaKind == 'gif'
                        ? 'GIF advisory media'
                        : 'Public advisory media',
                    style: infraMono(fontSize: 9, color: inkSoft),
                  ),
                ],
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
      );
    }
    if (_controller == null || !_controller!.value.isInitialized) {
      return const SizedBox(
        height: 150,
        child: Center(child: CircularProgressIndicator(color: teal)),
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
    required this.onCategorySelected,
  });

  final String selectedCategory;
  final ValueChanged<String> onCategorySelected;

  static const _categories = ['All', 'Repairs', 'Construction', 'Maintenance'];

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    physics: const AlwaysScrollableScrollPhysics(),
    child: Padding(
      padding: const EdgeInsets.only(right: 20),
      child: Row(
        children: [
          for (var index = 0; index < _categories.length; index++) ...[
            if (index > 0) const SizedBox(width: 10),
            _NewsFilterChip(
              label: _categories[index],
              icon: switch (_categories[index]) {
                'Repairs' => Icons.construction,
                'Construction' => Icons.engineering_outlined,
                'Maintenance' => Icons.build_outlined,
                _ => null,
              },
              selected: selectedCategory == _categories[index],
              onTap: () => onCategorySelected(_categories[index]),
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
  Widget build(BuildContext context) => Material(
    color: selected ? navy : Colors.white,
    borderRadius: BorderRadius.circular(22),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: selected ? navy : line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: selected ? Colors.white : inkSoft, size: 15),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : inkSoft,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
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

  final List<({String image, String title, String subtitle})> stories;
  final PageController controller;
  final int currentPage;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(18),
    child: SizedBox(
      height: 158,
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
                    errorBuilder: (_, _, _) => Container(color: navy),
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
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 26),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'FEATURED THIS WEEK',
                          style: TextStyle(
                            color: Color(0xFFB9E0E2),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          story.title,
                          style: infraHeading(
                            color: Colors.white,
                            fontSize: 18,
                            weight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          story.subtitle,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          Positioned(
            bottom: 11,
            right: 16,
            child: Row(
              children: [
                for (var index = 0; index < stories.length; index++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: index == currentPage ? 15 : 5,
                    height: 5,
                    margin: const EdgeInsets.only(left: 5),
                    decoration: BoxDecoration(
                      color: index == currentPage
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
