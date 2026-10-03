part of '../main.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  String filter = 'All';

  final notifications = const [
    _NotificationItem(
      group: 'TODAY',
      title: 'Your report moved to Scheduled for repair',
      message: 'Deep pothole along Rizal St. · Work order issued to Team Alpha',
      time: '2h ago',
      label: 'REPORT PROGRESS',
      color: teal,
      icon: Icons.sync,
      type: 'Report updates',
      unread: true,
    ),
    _NotificationItem(
      group: 'TODAY',
      title: '32 more residents are watching your report',
      message: 'No water supply, Purok 3 · now 87 watching',
      time: '5h ago',
      label: 'COMMUNITY ACTIVITY',
      color: clay,
      icon: Icons.groups_outlined,
      type: 'Similar reports',
      unread: true,
    ),
    _NotificationItem(
      group: 'YESTERDAY',
      title: 'A similar report was spotted near yours',
      message:
          'Clogged drainage near market · 2 reports merged into one ticket',
      time: '1d ago',
      label: 'SIMILAR REPORT',
      color: amber,
      icon: Icons.near_me_outlined,
      type: 'Similar reports',
      unread: true,
    ),
    _NotificationItem(
      group: 'YESTERDAY',
      title: 'Your report was marked Resolved',
      message: 'Streetlight repaired, J.P. Laurel · Rate the repair',
      time: '1d ago',
      label: 'RESOLVED',
      color: green,
      icon: Icons.check,
      type: 'Report updates',
      unread: false,
    ),
  ];

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
                      onPressed: () => setState(() {}),
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
                    children: ['All', 'Report updates', 'Similar reports'].map((
                      item,
                    ) {
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
                          onSelected: (_) => setState(() => filter = item),
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
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),
                if (visible.isEmpty)
                  const _EmptyNotifications()
                else
                  for (final group in ['TODAY', 'YESTERDAY'])
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
  const _EmptyNotifications();
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
          const Text(
            'No notifications in this category.',
            style: TextStyle(color: inkSoft, fontSize: 11),
          ),
        ],
      ),
    ),
  );
}
