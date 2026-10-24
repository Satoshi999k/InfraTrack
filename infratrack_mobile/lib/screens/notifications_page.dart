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
  bool _markingAllRead = false;
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
      showInfraNotice(
        context,
        error.toString().replaceFirst('Exception: ', ''),
        kind: InfraNoticeKind.error,
      );
    }
  }

  Future<void> _markAllRead() async {
    final unreadIds = _serverNotifications
        .where((item) => item['read_at'] == null)
        .map((item) => int.parse(item['id'].toString()))
        .toList();
    if (_markingAllRead || unreadIds.isEmpty) {
      return;
    }
    final previousNotifications = _serverNotifications;
    final readAt = DateTime.now().toIso8601String();
    setState(() {
      _markingAllRead = true;
      _serverNotifications = _serverNotifications
          .map(
            (item) =>
                item['read_at'] == null ? {...item, 'read_at': readAt} : item,
          )
          .toList();
    });
    try {
      await ApiService.markAllNotificationsRead(unreadIds);
    } catch (error) {
      if (!mounted) return;
      try {
        final latestNotifications = await ApiService.notifications();
        if (!mounted) return;
        setState(() => _serverNotifications = latestNotifications);
      } catch (refreshError) {
        setState(() => _serverNotifications = previousNotifications);
        showInfraNotice(
          context,
          'Could not refresh notifications after marking them read: '
          '${refreshError.toString().replaceFirst('Exception: ', '')}',
          kind: InfraNoticeKind.error,
        );
        return;
      }
      showInfraNotice(
        context,
        error.toString().replaceFirst('Exception: ', ''),
        kind: InfraNoticeKind.error,
      );
    } finally {
      if (mounted) setState(() => _markingAllRead = false);
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
      final value when value.contains('restor') || value.contains('verif') =>
        green,
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
              final value when value.contains('verif') => 'VERIFIED',
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
              final value
                  when value.contains('restor') || value.contains('verif') =>
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: PageEntrance(
          child: RefreshIndicator(
            color: teal,
            backgroundColor: Theme.of(context).colorScheme.surface,
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
                    onMarkAllRead: _markingAllRead ? null : _markAllRead,
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
                          const NotificationFeedSkeleton(count: 5)
                        else if (_loadError != null)
                          LoadErrorPanel(
                            message: _loadError!,
                            onRetry: _loadNotifications,
                          )
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
                                style: TextStyle(
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? const Color(0xFF9FB8BC)
                                      : inkSoft,
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
    required this.onMarkAllRead,
    required this.onBack,
  });

  final String filter;
  final List<_NotificationItem> notifications;
  final ValueChanged<String> onFilterChanged;
  final VoidCallback? onMarkAllRead;
  final VoidCallback onBack;

  @override
  double get minExtent => 154;

  @override
  double get maxExtent => 154;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF0D2430)
          : sand,
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
                        Text(
                          'ACCOUNT',
                          style: TextStyle(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF75D5CF)
                                : teal,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                          ),
                        ),
                        Text(
                          'Notifications',
                          style: infraHeading(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFFEAF6F4)
                                : navy,
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
            const SizedBox(height: 2),
            Align(
              alignment: Alignment.centerRight,
              child: notifications.any((item) => item.unread)
                  ? TextButton.icon(
                      onPressed: onMarkAllRead,
                      icon: const Icon(Icons.done_all_rounded, size: 16),
                      label: const Text('Mark all as read'),
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        minimumSize: const Size(0, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        textStyle: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  : const SizedBox(height: 32),
            ),
            const SizedBox(height: 2),
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
                      final icon = switch (item) {
                        'All' => Icons.notifications_outlined,
                        'Report updates' => Icons.assignment_outlined,
                        'City updates' => Icons.campaign_outlined,
                        'Account' => Icons.person_outline_rounded,
                        _ => Icons.notifications_outlined,
                      };
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          avatar: Icon(
                            icon,
                            size: 15,
                            color: selected
                                ? Colors.white
                                : (Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? const Color(0xFF75D5CF)
                                      : teal),
                          ),
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
                          selectedColor: Theme.of(context).colorScheme.primary,
                          backgroundColor:
                              Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF173F4D)
                              : Colors.white.withValues(alpha: .72),
                          side: BorderSide(
                            color: selected
                                ? (infraAppearance.value.highContrast
                                      ? Theme.of(context).colorScheme.onPrimary
                                      : Theme.of(context).colorScheme.primary)
                                : (infraAppearance.value.highContrast
                                      ? Theme.of(context).colorScheme.outline
                                      : Theme.of(context).brightness ==
                                            Brightness.dark
                                      ? const Color(0xFF345A63)
                                      : line),
                            width: infraAppearance.value.highContrast ? 2 : 1,
                          ),
                          shape: const StadiumBorder(),
                          labelStyle: TextStyle(
                            color: selected
                                ? Theme.of(context).colorScheme.onPrimary
                                : infraMutedTextColor(context),
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
      oldDelegate.notifications != notifications ||
      oldDelegate.onMarkAllRead != onMarkAllRead;
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
    color: Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF173F4D)
        : Colors.white.withValues(alpha: .78),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: IconButton(
      onPressed: onPressed,
      tooltip: 'Back',
      icon: Icon(
        Icons.arrow_back,
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFFEAF6F4)
            : navy,
      ),
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
      color: selected
          ? Colors.white24
          : (Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF244753)
                : sand),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      '$count',
      style: TextStyle(
        color: selected
            ? Colors.white
            : (Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFFB2C9CC)
                  : inkSoft),
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
    color: Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF173F4D)
        : Color.lerp(Colors.white.withValues(alpha: .92), item.color, .045),
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
                          style: TextStyle(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFFEAF6F4)
                                : ink,
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
                    style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFFB2C9CC)
                          : inkSoft,
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
