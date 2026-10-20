part of 'main.dart';

class SkeletonShimmer extends StatefulWidget {
  const SkeletonShimmer({super.key, required this.child});

  final Widget child;

  @override
  State<SkeletonShimmer> createState() => _SkeletonShimmerState();
}

class _SkeletonShimmerState extends State<SkeletonShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1350),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Loading content',
    child: ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _controller,
        child: widget.child,
        builder: (context, child) => ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final progress = _controller.value * 2 - 1;
            return LinearGradient(
              begin: Alignment(progress - 1, 0),
              end: Alignment(progress + 1, 0),
              colors: const [
                Color(0xFFE5E8E4),
                Color(0xFFF7F8F5),
                Color(0xFFE5E8E4),
              ],
              stops: const [0.32, 0.5, 0.68],
            ).createShader(bounds);
          },
          child: child,
        ),
      ),
    ),
  );
}

class SkeletonBlock extends StatelessWidget {
  const SkeletonBlock({
    super.key,
    required this.height,
    this.width,
    this.radius = 10,
  });

  final double height;
  final double? width;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: const Color(0xFFE5E8E4),
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}

class ReportFeedSkeleton extends StatelessWidget {
  const ReportFeedSkeleton({super.key, this.count = 4, this.animated = true});

  final int count;
  final bool animated;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        for (var index = 0; index < count; index++)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: line),
            ),
            child: Row(
              children: [
                const SkeletonBlock(height: 48, width: 48, radius: 14),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBlock(
                        height: 14,
                        width: index.isEven ? 156 : 122,
                        radius: 7,
                      ),
                      const SizedBox(height: 9),
                      SkeletonBlock(
                        height: 11,
                        width: index.isEven ? 104 : 138,
                        radius: 6,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const SkeletonBlock(height: 23, width: 68, radius: 14),
              ],
            ),
          ),
      ],
    );
    return animated ? SkeletonShimmer(child: content) : content;
  }
}

class NewsFeedSkeleton extends StatelessWidget {
  const NewsFeedSkeleton({super.key, this.count = 3});

  final int count;

  @override
  Widget build(BuildContext context) => SkeletonShimmer(
    child: Column(
      children: [
        for (var index = 0; index < count; index++)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonBlock(
                  height: 126,
                  width: double.infinity,
                  radius: 13,
                ),
                const SizedBox(height: 14),
                SkeletonBlock(
                  height: 15,
                  width: index.isEven ? 220 : 176,
                  radius: 7,
                ),
                const SizedBox(height: 10),
                const SkeletonBlock(
                  height: 11,
                  width: double.infinity,
                  radius: 6,
                ),
                const SizedBox(height: 7),
                const SkeletonBlock(height: 11, width: 190, radius: 6),
              ],
            ),
          ),
      ],
    ),
  );
}

class NotificationFeedSkeleton extends StatelessWidget {
  const NotificationFeedSkeleton({super.key, this.count = 5});

  final int count;

  @override
  Widget build(BuildContext context) => SkeletonShimmer(
    child: Column(
      children: [
        for (var index = 0; index < count; index++)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: line),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonBlock(height: 42, width: 42, radius: 21),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBlock(
                        height: 13,
                        width: index.isEven ? 164 : 128,
                        radius: 7,
                      ),
                      const SizedBox(height: 8),
                      const SkeletonBlock(
                        height: 10,
                        width: double.infinity,
                        radius: 6,
                      ),
                      const SizedBox(height: 6),
                      SkeletonBlock(
                        height: 10,
                        width: index.isEven ? 206 : 172,
                        radius: 6,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

class LoadErrorPanel extends StatelessWidget {
  const LoadErrorPanel({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .82),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.cloud_off_outlined, color: clay, size: 22),
        const SizedBox(height: 9),
        Text(
          message,
          style: const TextStyle(
            color: ink,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh, size: 17),
          label: const Text('Try again'),
        ),
      ],
    ),
  );
}
