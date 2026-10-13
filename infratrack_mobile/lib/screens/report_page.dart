part of '../main.dart';

enum _CaptureMode { photo, video }

class ReportPage extends StatefulWidget {
  const ReportPage({super.key});
  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  final _imagePicker = ImagePicker();
  final _descriptionController = TextEditingController();
  String category = 'Road';
  XFile? _capturedMedia;
  bool _capturedVideo = false;
  Position? _position;
  bool _locating = false;
  String? _locationError;

  @override
  void initState() {
    super.initState();
    _refreshLocation();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    if (_descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a description first')),
      );
      return;
    }
    if (_position == null) {
      await _refreshLocation();
      if (_position == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _locationError ?? 'Please enable location before submitting.',
              ),
            ),
          );
        }
        return;
      }
    }
    try {
      final mediaUrl = _capturedMedia == null
          ? null
          : await ApiService.uploadMedia(
              File(_capturedMedia!.path),
              isVideo: _capturedVideo,
            );
      await ApiService.createReport(
        title:
            '${category == 'Road' ? 'Road' : category} issue reported by resident',
        description: _descriptionController.text.trim(),
        category: category == 'Road' ? 'Roads' : category,
        location: 'Mati City',
        latitude: _position!.latitude,
        longitude: _position!.longitude,
        mediaUrl: mediaUrl,
        mediaType: _capturedVideo ? 'video' : 'photo',
      );
      if (!mounted) return;
      _descriptionController.clear();
      setState(() {
        _capturedMedia = null;
        _capturedVideo = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report submitted successfully')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    }
  }

  Future<void> _refreshLocation() async {
    if (_locating) return;
    setState(() {
      _locating = true;
      _locationError = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception('Location services are disabled.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permission is required to place a report.');
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (mounted) setState(() => _position = position);
    } catch (error) {
      if (mounted) {
        setState(
          () =>
              _locationError = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _openCamera() async {
    final mode = await showModalBottomSheet<_CaptureMode>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: teal),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, _CaptureMode.photo),
            ),
            ListTile(
              leading: const Icon(Icons.videocam_outlined, color: clay),
              title: const Text('Record a video'),
              onTap: () => Navigator.pop(context, _CaptureMode.video),
            ),
          ],
        ),
      ),
    );
    if (mode == null || !mounted) return;

    final media = mode == _CaptureMode.video
        ? await _imagePicker.pickVideo(source: ImageSource.camera)
        : await _imagePicker.pickImage(
            source: ImageSource.camera,
            imageQuality: 88,
          );
    if (!mounted || media == null) return;
    setState(() {
      _capturedMedia = media;
      _capturedVideo = mode == _CaptureMode.video;
    });
  }

  @override
  Widget build(BuildContext context) => PageEntrance(
    child: AppScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppHeader(eyebrow: 'NEW SUBMISSION', title: 'Report an issue'),
          Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            color: Colors.white.withValues(alpha: .78),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: BorderSide(color: Colors.white.withValues(alpha: .9)),
            ),
            child: InkWell(
              onTap: _openCamera,
              borderRadius: BorderRadius.circular(22),
              child: _capturedMedia == null
                  ? SizedBox(
                      height: 158,
                      width: double.infinity,
                      child: _AddMediaPlaceholder(),
                    )
                  : _CapturedMediaPreview(
                      file: _capturedMedia!,
                      isVideo: _capturedVideo,
                    ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'CATEGORY',
            style: TextStyle(
              color: inkSoft,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _CategoryButton(
                label: 'Road',
                icon: Icons.construction_outlined,
                color: clay,
                selected: category == 'Road',
                onTap: () => setState(() => category = 'Road'),
              ),
              _CategoryButton(
                label: 'Water',
                icon: Icons.water_drop_outlined,
                color: teal,
                selected: category == 'Water',
                onTap: () => setState(() => category = 'Water'),
              ),
              _CategoryButton(
                label: 'Drainage',
                icon: Icons.water_damage_outlined,
                color: amber,
                selected: category == 'Drainage',
                onTap: () => setState(() => category = 'Drainage'),
              ),
              _CategoryButton(
                label: 'Lighting',
                icon: Icons.lightbulb_outline,
                color: navy,
                selected: category == 'Lighting',
                onTap: () => setState(() => category = 'Lighting'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'LOCATION',
            style: TextStyle(
              color: inkSoft,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          _CoordinatesCard(
            position: _position,
            loading: _locating,
            error: _locationError,
            onRefresh: _refreshLocation,
          ),
          const SizedBox(height: 20),
          const Text(
            'DESCRIPTION',
            style: TextStyle(
              color: inkSoft,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _descriptionController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Describe what you saw — size, severity, and any safety risk...',
              filled: true,
              fillColor: Colors.white,
              contentPadding: EdgeInsets.all(16),
              hintStyle: TextStyle(color: inkSoft, fontSize: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(14)),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: clay,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 17),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 3,
              ),
              onPressed: _submitReport,
              child: const Text('Submit report'),
            ),
          ),
        ],
      ),
    ),
  );
}

class _AddMediaPlaceholder extends StatelessWidget {
  const _AddMediaPlaceholder();

  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.center,
    children: [
      Positioned(
        right: -25,
        top: -35,
        child: Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: teal.withValues(alpha: .08),
          ),
        ),
      ),
      Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: teal.withValues(alpha: .12),
            ),
            child: const Icon(
              Icons.add_a_photo_outlined,
              size: 25,
              color: teal,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Add photo or video',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 3),
          const Text(
            'Use your camera to capture evidence',
            style: TextStyle(color: inkSoft, fontSize: 11),
          ),
        ],
      ),
    ],
  );
}

class _CapturedMediaPreview extends StatelessWidget {
  const _CapturedMediaPreview({required this.file, required this.isVideo});

  final XFile file;
  final bool isVideo;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 158,
    width: double.infinity,
    child: Stack(
      fit: StackFit.expand,
      children: [
        if (isVideo)
          Container(
            color: deepNavy,
            child: const Center(
              child: Icon(Icons.videocam, color: Colors.white, size: 42),
            ),
          )
        else
          Image.file(File(file.path), fit: BoxFit.cover),
        Positioned(
          left: 12,
          bottom: 10,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Text(
                isVideo
                    ? 'Video captured · Tap to retake'
                    : 'Photo captured · Tap to retake',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _CoordinatesCard extends StatelessWidget {
  const _CoordinatesCard({
    required this.position,
    required this.loading,
    required this.error,
    required this.onRefresh,
  });

  final Position? position;
  final bool loading;
  final String? error;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: navy,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: navy.withValues(alpha: .16),
          blurRadius: 16,
          offset: const Offset(0, 7),
        ),
      ],
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final coordinateText = position == null
            ? 'Location unavailable'
            : '${position!.latitude.toStringAsFixed(5)}° N, '
                  '${position!.longitude.toStringAsFixed(5)}° E';
        final details = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'DETECTED COORDINATES',
              style: TextStyle(color: Color(0xFF9FC2C9), fontSize: 9),
            ),
            SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                coordinateText,
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
          ],
        );
        final refresh = FilledButton.tonalIcon(
          onPressed: loading ? null : onRefresh,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white12,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          icon: loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh, color: Colors.white, size: 20),
          label: Text(
            loading
                ? 'Locating…'
                : error == null
                ? 'Refresh'
                : 'Try again',
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        );

        if (constraints.maxWidth < 350) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              details,
              const SizedBox(height: 12),
              Align(alignment: Alignment.centerRight, child: refresh),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: details),
            const SizedBox(width: 10),
            refresh,
          ],
        );
      },
    ),
  );
}

class _CategoryButton extends StatelessWidget {
  const _CategoryButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedScale(
      scale: selected ? 1 : .94,
      duration: const Duration(milliseconds: 180),
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 72,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: selected ? color : Colors.white.withValues(alpha: .72),
              border: Border.all(
                color: selected ? color : line,
                width: selected ? 2.5 : 1,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: .24),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ]
                  : null,
            ),
            child: Icon(icon, color: selected ? Colors.white : color, size: 23),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: selected ? navy : inkSoft,
              fontSize: 10,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}
