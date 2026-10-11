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

  Future<void> _markAllRead() async {
    try {
      await ApiService.markNotificationsRead();
      await _loadNotifications();
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

  List<_NotificationItem> get notifications => _serverNotifications.map((item) {
    final rawType = (item['type'] as String? ?? 'system').toLowerCase();
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
    return _NotificationItem(
      group: group,
      title: item['title'] as String? ?? 'InfraTrack update',
      message: item['message'] as String? ?? '',
      time: createdAt?.toLocal().toString().split('.').first ?? '',
      label: rawType.replaceAll('_', ' ').toUpperCase(),
      color: type == 'Report updates'
          ? teal
          : type == 'Account'
          ? clay
          : amber,
      icon: type == 'Report updates'
          ? Icons.sync
          : type == 'Account'
          ? Icons.person_outline
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
          child: AppScroll(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _NotificationBackButton(
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
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
                    IconButton(
                      onPressed: _markAllRead,
                      tooltip: 'Mark all as read',
                      icon: const Icon(Icons.done_all, color: teal),
                    ),
                  ],
                ),
                const SizedBox(height: 17),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  clipBehavior: Clip.none,
                  child: Row(
                    children:
                        [
                          'All',
                          'Report updates',
                          'City updates',
                          'Account',
                        ].map((item) {
                          final selected = filter == item;
                          final count = item == 'All'
                              ? notifications
                                    .where((item) => item.unread)
                                    .length
                              : notifications
                                    .where(
                                      (entry) =>
                                          entry.type == item && entry.unread,
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
                                    _CountBadge(
                                      count: count,
                                      selected: selected,
                                    ),
                                  ],
                                ],
                              ),
                              selected: selected,
                              showCheckmark: false,
                              onSelected: (_) => setState(() => filter = item),
                              selectedColor: navy,
                              backgroundColor: Colors.white.withValues(
                                alpha: .72,
                              ),
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
                        }).toList(),
                  ),
                ),
                const SizedBox(height: 16),
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
                          .map((item) => _NotificationCard(item: item)),
                      const SizedBox(height: 5),
                    ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationItem {
  const _NotificationItem({
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
  const _NotificationCard({required this.item});
  final _NotificationItem item;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    color: Colors.white.withValues(alpha: .86),
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: BorderSide(color: Colors.white.withValues(alpha: .9)),
    ),
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
                        decoration: const BoxDecoration(
                          color: clay,
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
