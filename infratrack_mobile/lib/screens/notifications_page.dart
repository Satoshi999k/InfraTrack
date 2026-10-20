part of '../main.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  String filter = 'All';
  List<Map<String, dynamic>> _serverNotifications = [];
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    try {
      final items = await ApiService.notifications();
      if (mounted) {
        setState(() {
          _serverNotifications = items;
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

  Future<void> _markRead(_NotificationItem notification) async {
    if (!notification.unread) return;
    final previousReadAt = _serverNotifications.firstWhere(
      (item) => item['id'].toString() == notification.id.toString(),
    )['read_at'];
    setState(() {
      _serverNotifications = _serverNotifications.map((item) {
        if (item['id'].toString() != notification.id.toString()) return item;
        return {...item, 'read_at': DateTime.now().toIso8601String()};
      }).toList();
    });
    try {
      await ApiService.markNotificationRead(notification.id);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _serverNotifications = _serverNotifications.map((item) {
          if (item['id'].toString() != notification.id.toString()) return item;
          return {...item, 'read_at': previousReadAt};
        }).toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  List<_NotificationItem> get notifications => _serverNotifications.map((item) {
    final rawType = (item['type'] as String? ?? 'system').toLowerCase();
    final title = item['title'] as String? ?? 'InfraTrack update';
    final type = switch (rawType) {
      'report' ||
      'duplicate_issue' ||
      'priority_escalation' => 'Report updates',
      'account' => 'Account',
      _ => 'City updates',
    };
    final createdAt = DateTime.tryParse(item['created_at']?.toString() ?? '');
    final now = DateTime.now();
    final daysAgo = createdAt == null
        ? null
        : DateTime(now.year, now.month, now.day)
              .difference(
                DateTime(createdAt.year, createdAt.month, createdAt.day),
              )
              .inDays;
    final group = createdAt == null
        ? 'EARLIER'
        : daysAgo == 0
        ? 'TODAY'
        : daysAgo == 1
        ? 'YESTERDAY'
        : 'EARLIER';
    final accountActionColor = switch (title.toLowerCase()) {
      final value when value.contains('warn') => amber,
      final value when value.contains('suspend') => clay,
      final value when value.contains('ban') => red,
      final value when value.contains('restor') => green,
      _ => clay,
    };
    return _NotificationItem(
      id: int.parse(item['id'].toString()),
      group: group,
      title: title,
      message: item['message'] as String? ?? '',
      time: createdAt?.toLocal().toString().split('.').first ?? '',
      label: type == 'Account'
          ? switch (title.toLowerCase()) {
              final value when value.contains('warn') => 'WARNING',
              final value when value.contains('suspend') => 'SUSPENSION',
              final value when value.contains('ban') => 'ACCOUNT BANNED',
              final value when value.contains('restor') => 'RESTORED',
              _ => 'ACCOUNT',
            }
          : rawType.replaceAll('_', ' ').toUpperCase(),
      color: type == 'Report updates'
          ? teal
          : type == 'Account'
          ? accountActionColor
          : amber,
      icon: type == 'Account'
          ? switch (title.toLowerCase()) {
              final value when value.contains('warn') =>
                Icons.warning_amber_rounded,
              final value when value.contains('suspend') =>
                Icons.hourglass_top_rounded,
              final value when value.contains('ban') => Icons.gpp_bad_outlined,
              final value when value.contains('restor') =>
                Icons.verified_outlined,
              _ => Icons.person_outline,
            }
          : type == 'Report updates'
          ? Icons.sync
          : Icons.notifications_active_outlined,
      type: type,
      unread: item['read_at'] == null,
    );
  }).toList();

  @override
  Widget build(BuildContext context) {
    final visible = filter == 'All'
        ? notifications
        : notifications.where((item) => item.type == filter).toList();
    final groups = visible.map((item) => item.group).toSet();

    return Scaffold(
      backgroundColor: sand,
      body: SafeArea(
        child: PageEntrance(
          child: RefreshIndicator(
            color: teal,
            backgroundColor: Colors.white,
            triggerMode: RefreshIndicatorTriggerMode.onEdge,
            onRefresh: _loadNotifications,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _NotificationHeaderDelegate(
                    filter: filter,
                    notifications: notifications,
                    onFilterChanged: (value) => setState(() => filter = value),
                    onBack: () => Navigator.pop(context),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_loading)
                          const Center(child: CircularProgressIndicator())
                        else if (_loadError != null)
                          Text(_loadError!, style: const TextStyle(color: clay))
                        else if (visible.isEmpty)
                          _EmptyNotifications(
                            message: ApiService.isSignedIn
                                ? 'No notifications in this category.'
                                : 'Sign in to view your notifications.',
                          )
                        else
                          for (final group in ['TODAY', 'YESTERDAY', 'EARLIER'])
                            if (groups.contains(group)) ...[
                              Text(
                                group,
                                style: const TextStyle(
                                  color: inkSoft,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: 9),
                              ...visible
                                  .where((item) => item.group == group)
                                  .map(
                                    (item) => _NotificationCard(
                                      item: item,
                                      onTap: () => _markRead(item),
                                    ),
                                  ),
                              const SizedBox(height: 5),
                            ],
                      ],
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

class _NotificationHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _NotificationHeaderDelegate({
    required this.filter,
    required this.notifications,
    required this.onFilterChanged,
    required this.onBack,
  });

  final String filter;
  final List<_NotificationItem> notifications;
  final ValueChanged<String> onFilterChanged;
  final VoidCallback onBack;

  @override
  double get minExtent => 132;

  @override
  double get maxExtent => 132;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      color: sand,
      elevation: overlapsContent ? 2 : 0,
      shadowColor: navy.withValues(alpha: .12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 48,
              child: Row(
                children: [
                  _NotificationBackButton(onPressed: onBack),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ACCOUNT',
                          style: TextStyle(
                            color: teal,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                          ),
                        ),
                        Text(
                          'Notifications',
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
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              clipBehavior: Clip.none,
              child: Row(
                children: ['All', 'Report updates', 'City updates', 'Account']
                    .map((item) {
                      final selected = filter == item;
                      final count = item == 'All'
                          ? notifications.where((item) => item.unread).length
                          : notifications
                                .where(
                                  (entry) => entry.type == item && entry.unread,
                                )
                                .length;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(item),
                              if (count > 0) ...[
                                const SizedBox(width: 6),
                                _CountBadge(count: count, selected: selected),
                              ],
                            ],
                          ),
                          selected: selected,
                          showCheckmark: false,
                          onSelected: (_) => onFilterChanged(item),
                          selectedColor: navy,
                          backgroundColor: Colors.white.withValues(alpha: .72),
                          side: BorderSide(color: selected ? navy : line),
                          shape: const StadiumBorder(),
                          labelStyle: TextStyle(
                            color: selected ? Colors.white : inkSoft,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 5,
                          ),
                        ),
                      );
                    })
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _NotificationHeaderDelegate oldDelegate) =>
      oldDelegate.filter != filter ||
      oldDelegate.notifications != notifications;
}

class _NotificationItem {
  const _NotificationItem({
    required this.id,
    required this.group,
    required this.title,
    required this.message,
    required this.time,
    required this.label,
    required this.color,
    required this.icon,
    required this.type,
    required this.unread,
  });
  final int id;
  final String group, title, message, time, label, type;
  final Color color;
  final IconData icon;
  final bool unread;
}

class _NotificationBackButton extends StatelessWidget {
  const _NotificationBackButton({required this.onPressed});
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white.withValues(alpha: .78),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: IconButton(
      onPressed: onPressed,
      tooltip: 'Back',
      icon: const Icon(Icons.arrow_back, color: navy),
    ),
  );
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count, required this.selected});
  final int count;
  final bool selected;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: selected ? Colors.white24 : sand,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      '$count',
      style: TextStyle(
        color: selected ? Colors.white : inkSoft,
        fontSize: 9,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.item, required this.onTap});
  final _NotificationItem item;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    color: Color.lerp(Colors.white.withValues(alpha: .92), item.color, .045),
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: BorderSide(color: item.color.withValues(alpha: .22)),
    ),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(item.icon, color: item.color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: const TextStyle(
                            color: ink,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            height: 1.25,
                          ),
                        ),
                      ),
                      if (item.unread) ...[
                        const SizedBox(width: 7),
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: item.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    item.message,
                    style: const TextStyle(
                      color: inkSoft,
                      fontSize: 10.5,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: item.color.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          item.label,
                          style: TextStyle(
                            color: item.color,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: .2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        item.time,
                        style: infraMono(fontSize: 9, color: inkSoft),
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

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 42,
            color: inkSoft.withValues(alpha: .5),
          ),
          const SizedBox(height: 10),
          const Text(
            'You’re all caught up',
            style: TextStyle(color: navy, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(message, style: const TextStyle(color: inkSoft, fontSize: 11)),
        ],
      ),
    ),
  );
}
