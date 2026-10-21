part of '../main.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with WidgetsBindingObserver {
  XFile? _profileImage;
  Map<String, dynamic> _profile = ApiService.currentUser ?? {};
  List<Map<String, dynamic>> _reports = [];
  List<Map<String, dynamic>> _notifications = [];
  String? _loadError;
  Timer? _notificationRefreshTimer;
  bool _refreshingNotifications = false;

  Future<void> refresh() => _loadProfile();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ApiService.notificationReadRevision.addListener(_handleNotificationRead);
    _loadProfile();
    _notificationRefreshTimer = Timer.periodic(const Duration(seconds: 30), (
      _,
    ) {
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        _refreshNotifications();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshNotifications();
  }

  void _handleNotificationRead() {
    final notificationId = ApiService.lastReadNotificationId?.toString();
    if (notificationId == null || !mounted) return;
    setState(() {
      _notifications = _notifications.map((item) {
        if (item['id'].toString() != notificationId ||
            item['read_at'] != null) {
          return item;
        }
        return {...item, 'read_at': DateTime.now().toIso8601String()};
      }).toList();
    });
  }

  Future<void> _loadProfile() async {
    if (!ApiService.isSignedIn) return;
    final notificationRevision = ApiService.notificationReadRevision.value;
    try {
      final results = await Future.wait([
        ApiService.profile(),
        ApiService.reports(),
        ApiService.notifications(),
      ]);
      if (context.mounted) {
        setState(() {
          _profile = results[0] as Map<String, dynamic>;
          _reports = results[1] as List<Map<String, dynamic>>;
          _notifications = _notificationsAfterRead(
            results[2] as List<Map<String, dynamic>>,
            notificationRevision,
          );
          _loadError = null;
        });
      }
    } catch (error) {
      if (context.mounted) {
        setState(
          () => _loadError = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    }
  }

  List<Map<String, dynamic>> _notificationsAfterRead(
    List<Map<String, dynamic>> notifications,
    int startingRevision,
  ) {
    if (startingRevision == ApiService.notificationReadRevision.value) {
      return notifications;
    }
    final notificationId = ApiService.lastReadNotificationId?.toString();
    if (notificationId == null) return notifications;
    return notifications.map((item) {
      if (item['id'].toString() != notificationId || item['read_at'] != null) {
        return item;
      }
      return {...item, 'read_at': DateTime.now().toIso8601String()};
    }).toList();
  }

  Future<void> _refreshNotifications() async {
    if (!ApiService.isSignedIn || _refreshingNotifications) return;
    _refreshingNotifications = true;
    final notificationRevision = ApiService.notificationReadRevision.value;
    try {
      final notifications = await ApiService.notifications();
      if (!mounted) return;
      setState(() {
        _notifications = _notificationsAfterRead(
          notifications,
          notificationRevision,
        );
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      _refreshingNotifications = false;
    }
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const NotificationsPage()));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ApiService.notificationReadRevision.removeListener(_handleNotificationRead);
    _notificationRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _editProfile(BuildContext context) async {
    if (!ApiService.isSignedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to edit your profile.')),
      );
      return;
    }
    XFile? selectedImage;
    String? selectionError;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: sand,
        title: Text(
          'Edit profile',
          style: infraHeading(
            color: navy,
            fontSize: 18,
            weight: FontWeight.w800,
          ),
        ),
        content: StatefulBuilder(
          builder: (context, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () async {
                  final source = await showModalBottomSheet<ImageSource>(
                    context: context,
                    builder: (sheetContext) => SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: teal.withValues(alpha: .12),
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: const Icon(
                                Icons.camera_alt_outlined,
                                color: teal,
                              ),
                            ),
                            title: const Text('Take a photo'),
                            onTap: () =>
                                Navigator.pop(sheetContext, ImageSource.camera),
                          ),
                          ListTile(
                            leading: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: amber.withValues(alpha: .14),
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: const Icon(
                                Icons.photo_library_outlined,
                                color: amber,
                              ),
                            ),
                            title: const Text('Choose from gallery'),
                            onTap: () => Navigator.pop(
                              sheetContext,
                              ImageSource.gallery,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                  if (source == null) return;
                  try {
                    final image = await ImagePicker().pickImage(
                      source: source,
                      imageQuality: 85,
                    );
                    if (image != null) {
                      setDialogState(() {
                        selectedImage = image;
                        selectionError = null;
                      });
                    }
                  } catch (error) {
                    setDialogState(() {
                      selectionError = error.toString().replaceFirst(
                        'Exception: ',
                        '',
                      );
                    });
                  }
                },
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 38,
                      backgroundColor: const Color(0xFF2A6C7C),
                      backgroundImage: selectedImage != null
                          ? FileImage(File(selectedImage!.path))
                          : publicMediaUrl(_profile['avatar_url'] as String?) ==
                                null
                          ? null
                          : NetworkImage(
                              publicMediaUrl(
                                _profile['avatar_url'] as String?,
                              )!,
                            ),
                      child: selectedImage == null
                          ? publicMediaUrl(_profile['avatar_url'] as String?) !=
                                    null
                                ? null
                                : Text(
                                    _initialsFor(
                                      _profile['name']?.toString() ?? '',
                                    ),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 22,
                                    ),
                                  )
                          : null,
                    ),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: clay,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.camera_alt_outlined,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    if (selectionError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        selectionError!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: clay, fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tap the photo to change it',
                style: TextStyle(color: inkSoft, fontSize: 11),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: line),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person_outline, color: inkSoft),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Display name',
                            style: TextStyle(color: inkSoft, fontSize: 10),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _profile['name']?.toString() ?? '',
                            style: const TextStyle(
                              color: ink,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.lock_outline, color: inkSoft, size: 17),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel', style: TextStyle(color: teal)),
          ),
          FilledButton(
            onPressed: () {
              if (selectedImage == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Choose a new photo before saving.'),
                  ),
                );
                return;
              }
              Navigator.pop(dialogContext, true);
            },
            style: FilledButton.styleFrom(backgroundColor: clay),
            child: const Text('Save changes'),
          ),
        ],
      ),
    );
    if (result == true && selectedImage != null && context.mounted) {
      try {
        final updated = await ApiService.uploadProfilePhoto(selectedImage!);
        if (context.mounted) {
          setState(() {
            _profile = updated;
            _profileImage = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Your profile photo was saved to your account.'),
            ),
          );
        }
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error.toString().replaceFirst('Exception: ', '')),
            ),
          );
        }
      }
    }
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: sand,
        insetPadding: const EdgeInsets.symmetric(horizontal: 22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        icon: Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: red.withValues(alpha: .11),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.logout_rounded, color: red, size: 26),
        ),
        iconPadding: const EdgeInsets.only(top: 22, bottom: 2),
        titlePadding: const EdgeInsets.fromLTRB(24, 6, 24, 0),
        title: Text(
          'Leave InfraTrack?',
          textAlign: TextAlign.center,
          style: infraHeading(
            color: navy,
            fontSize: 18,
            weight: FontWeight.w800,
          ),
        ),
        content: const Text(
          'You can sign back in anytime to continue tracking your reports and community updates.',
          textAlign: TextAlign.center,
          style: TextStyle(color: inkSoft, height: 1.45, fontSize: 12),
        ),
        contentPadding: const EdgeInsets.fromLTRB(24, 10, 24, 4),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel', style: TextStyle(color: teal)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: red),
            child: const Text('Log out'),
          ),
        ],
        actionsPadding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
        actionsAlignment: MainAxisAlignment.center,
      ),
    );

    if (shouldLogout == true && context.mounted) {
      try {
        await ApiService.logout();
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error.toString().replaceFirst('Exception: ', '')),
            ),
          );
        }
      }
      if (!context.mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (_) => false,
      );
    }
  }

  /*
  class IdentityVerificationPage extends StatelessWidget {
    const IdentityVerificationPage({super.key});

    @override
    Widget build(BuildContext context) => Scaffold(
      backgroundColor: sand,
      appBar: AppBar(
        title: const Text('Identity verification'),
        backgroundColor: sand,
        foregroundColor: navy,
        elevation: 0,
      ),
      body: AppScroll(
        onRefresh: _loadProfile,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: green.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: green.withValues(alpha: .25)),
              ),
              child: const Row(
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: green,
                    child: Icon(Icons.verified, color: Colors.white, size: 28),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Account verified',
                          style: TextStyle(
                            color: navy,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Your ID and selfie check are complete.',
                          style: TextStyle(color: inkSoft, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'VERIFICATION DETAILS',
              style: infraMono(
                color: inkSoft,
                fontSize: 10,
                weight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Card(
              child: Column(
                children: [
                  _VerificationDetail(
                    icon: Icons.badge_outlined,
                    title: 'Government ID',
                    value: 'Verified securely',
                  ),
                  Divider(height: 1),
                  _VerificationDetail(
                    icon: Icons.face_retouching_natural,
                    title: 'Live selfie',
                    value: 'Verified securely',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Your documents are private and are not displayed on your profile or reports. Re-verification may be requested if your account details change.',
              style: TextStyle(color: inkSoft, fontSize: 12, height: 1.5),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const VerifyIdPage()),
                ),
                icon: const Icon(Icons.refresh),
                label: const Text('Re-verify identity'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: navy,
                  side: const BorderSide(color: navy),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  class _VerificationDetail extends StatelessWidget {
    const _VerificationDetail({
      required this.icon,
      required this.title,
      required this.value,
    });

    final IconData icon;
    final String title;
    final String value;

    @override
    Widget build(BuildContext context) => ListTile(
      leading: Icon(icon, color: teal),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(value, style: const TextStyle(color: green, fontSize: 11)),
      trailing: const Icon(Icons.check_circle, color: green, size: 19),
    );
  }

  class PrivacySecurityPage extends StatefulWidget {
    const PrivacySecurityPage({super.key});

    @override
    State<PrivacySecurityPage> createState() => _PrivacySecurityPageState();
  }

  class _PrivacySecurityPageState extends State<PrivacySecurityPage> {
    bool _showLocationOnReports = true;
    bool _allowNotifications = true;
    bool _biometricLock = false;

    Future<void> _changePassword() async {
      final formKey = GlobalKey<FormState>();
      final current = TextEditingController();
      final next = TextEditingController();
      final confirm = TextEditingController();
      final changed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Change password'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: current,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Current password'),
                  validator: (value) => value!.isEmpty ? 'Required' : null,
                ),
                TextFormField(
                  controller: next,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'New password'),
                  validator: (value) => value!.length < 8 ? 'Use 8+ characters' : null,
                ),
                TextFormField(
                  controller: confirm,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Confirm new password'),
                  validator: (value) => value != next.text ? 'Passwords differ' : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(dialogContext, true);
                }
              },
              child: const Text('Update'),
            ),
          ],
        ),
      );
      current.dispose();
      next.dispose();
      confirm.dispose();
      if (changed == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password updated successfully.')),
        );
      }
    }

    @override
    Widget build(BuildContext context) => Scaffold(
      backgroundColor: sand,
      appBar: AppBar(
        title: const Text('Privacy & security'),
        backgroundColor: sand,
        foregroundColor: navy,
        elevation: 0,
      ),
      body: AppScroll(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _ProfileSectionTitle(title: 'PRIVACY'),
            Card(
              child: Column(
                children: [
                  SwitchListTile.adaptive(
                    value: _showLocationOnReports,
                    onChanged: (value) => setState(() => _showLocationOnReports = value),
                    title: const Text('Show location on reports'),
                    subtitle: const Text('Helps the city locate reported issues'),
                    secondary: const Icon(Icons.location_on_outlined, color: teal),
                  ),
                  const Divider(height: 1),
                  SwitchListTile.adaptive(
                    value: _allowNotifications,
                    onChanged: (value) => setState(() => _allowNotifications = value),
                    title: const Text('Report updates'),
                    subtitle: const Text('Receive status and city advisory alerts'),
                    secondary: const Icon(Icons.notifications_none, color: amber),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const _ProfileSectionTitle(title: 'SECURITY'),
            Card(
              child: Column(
                children: [
                  SwitchListTile.adaptive(
                    value: _biometricLock,
                    onChanged: (value) => setState(() => _biometricLock = value),
                    title: const Text('Biometric app lock'),
                    subtitle: const Text('Use device biometrics when available'),
                    secondary: const Icon(Icons.fingerprint, color: navy),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.key_outlined, color: clay),
                    title: const Text('Change password'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _changePassword,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Security settings are applied on this device. Account credentials and identity documents should be handled by a secure backend in production.',
              style: TextStyle(color: inkSoft, fontSize: 11, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

*/

  @override
  Widget build(BuildContext context) => PageEntrance(
    child: AppScroll(
      paddingTop: 0,
      onRefresh: _loadProfile,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ProfileHeader(
            onEdit: () => _editProfile(context),
            profileImage: _profileImage,
            profile: _profile,
          ),
          if (_loadError != null)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: _ProfileLoadError(
                message: _loadError!,
                onRetry: _loadProfile,
              ),
            ),
          const SizedBox(height: 16),
          Builder(
            builder: (context) {
              final resolved = _reports
                  .where((report) => report['status'] == 'Resolved')
                  .length;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _ProfileSectionTitle(title: 'YOUR ACTIVITY'),
                  _CommunityImpactCard(resolvedCount: resolved),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          const _ProfileSectionTitle(title: 'ACCOUNT STATUS'),
          _VerificationCard(
            verification:
                _profile['verification']?.toString() ?? 'Not submitted',
            onTap: () async {
              await Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => const IdentityVerificationPage(),
                ),
              );
              if (mounted) await _loadProfile();
            },
          ),
          const SizedBox(height: 20),
          const _ProfileSectionTitle(title: 'QUICK ACCESS'),
          _SettingsGroup(
            reportCount: _reports.length,
            openReportCount: _reports
                .where(
                  (report) => ![
                    'Resolved',
                    'Rejected',
                    'Archived',
                  ].contains(report['status']),
                )
                .length,
            unreadNotificationCount: _notifications
                .where((notification) => notification['read_at'] == null)
                .length,
            onMyReportsTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const MyReportsPage())),
            onNotificationsTap: _openNotifications,
            onChatbotTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const ChatbotPage())),
          ),
          const SizedBox(height: 20),
          const _ProfileSectionTitle(title: 'ACCOUNT SETTINGS'),
          _TrustSettingsGroup(
            onPrivacyTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PrivacySecurityPage()),
            ),
          ),
          const SizedBox(height: 20),
          const _ProfileSectionTitle(title: 'SESSION'),
          MenuRow(
            icon: Icons.logout,
            title: 'Log out',
            destructive: true,
            accentColor: red,
            showChevron: false,
            centered: true,
            onTap: () => _confirmLogout(context),
          ),
          const SizedBox(height: 4),
        ],
      ),
    ),
  );
}

String _initialsFor(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .take(2);
  final initials = parts
      .map((part) => part.substring(0, 1))
      .join()
      .toUpperCase();
  return initials.isEmpty ? '?' : initials;
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.onEdit,
    required this.profile,
    this.profileImage,
  });

  final VoidCallback onEdit;
  final XFile? profileImage;
  final Map<String, dynamic> profile;

  @override
  Widget build(BuildContext context) {
    final name = profile['name']?.toString() ?? 'Guest';
    final avatarUrl = publicMediaUrl(profile['avatar_url']?.toString());
    final barangay = profile['barangay']?.toString() ?? 'Mati City';
    final email = profile['email']?.toString() ?? '';
    final createdAt = DateTime.tryParse(
      profile['created_at']?.toString() ?? '',
    );
    final membership = createdAt == null
        ? 'Browsing without an account'
        : 'Member since ${_profileMonth(createdAt.month)} ${createdAt.year}';
    final standing = profile['standing']?.toString();
    final accountStatus = standing == null
        ? 'Guest access'
        : standing == 'Active'
        ? 'Active account'
        : standing;
    final standingColor = standing == null
        ? amber
        : standing == 'Active'
        ? green
        : clay;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [deepNavy, navy, Color(0xFF155B66)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.all(Radius.circular(25)),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -50,
            top: -65,
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: .08)),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'YOUR ACCOUNT',
                      style: TextStyle(
                        color: Color(0xFF9FC2C9),
                        fontSize: 10,
                        letterSpacing: 1.3,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 15),
                    label: const Text('Edit profile'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.white.withValues(alpha: .12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 7,
                      ),
                      minimumSize: const Size(0, 36),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Colors.white24),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _ProfileAvatar(
                    image: profileImage,
                    avatarUrl: avatarUrl,
                    name: name,
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                          ),
                        ),
                        if (email.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFC5D8DB),
                              fontSize: 11,
                            ),
                          ),
                        ],
                        const SizedBox(height: 5),
                        Text(
                          membership,
                          style: const TextStyle(
                            color: Color(0xFFB9CBD1),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 17),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ProfileMetaChip(
                    icon: Icons.location_on_outlined,
                    label: barangay,
                    color: const Color(0xFF8FD6CE),
                  ),
                  _ProfileMetaChip(
                    icon: standing == 'Active'
                        ? Icons.check_circle_outline
                        : Icons.shield_outlined,
                    label: accountStatus,
                    color: standingColor,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _profileMonth(int month) => const [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
][month - 1];

class _ProfileMetaChip extends StatelessWidget {
  const _ProfileMetaChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(maxWidth: 220),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .10),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withValues(alpha: .17)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.name, this.image, this.avatarUrl});
  final String name;
  final XFile? image;
  final String? avatarUrl;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 72,
    height: 72,
    child: Container(
      padding: const EdgeInsets.all(3),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0x668FD6CE),
      ),
      child: CircleAvatar(
        radius: 33,
        backgroundColor: const Color(0xFF2A6C7C),
        backgroundImage: image != null
            ? FileImage(File(image!.path))
            : avatarUrl != null
            ? NetworkImage(avatarUrl!)
            : null,
        child: image == null && avatarUrl == null
            ? Text(
                _initialsFor(name),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                ),
              )
            : null,
      ),
    ),
  );
}

class _ProfileSectionTitle extends StatelessWidget {
  const _ProfileSectionTitle({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
      child: Text(
        title,
        style: const TextStyle(
          color: inkSoft,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
        ),
      ),
    ),
  );
}

class _CommunityImpactCard extends StatelessWidget {
  const _CommunityImpactCard({required this.resolvedCount});

  final int resolvedCount;

  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    padding: const EdgeInsets.symmetric(horizontal: 19, vertical: 20),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [teal, navy],
      ),
      borderRadius: BorderRadius.circular(25),
      boxShadow: [
        BoxShadow(
          color: navy.withValues(alpha: .16),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: Stack(
      children: [
        Positioned(
          right: -50,
          top: -64,
          child: Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: .045),
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'YOUR COMMUNITY IMPACT',
                    style: TextStyle(
                      color: Color(0xFFD4E9E4),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '$resolvedCount ',
                            style: infraHeading(
                              color: Colors.white,
                              fontSize: 27,
                              weight: FontWeight.w800,
                            ),
                          ),
                          TextSpan(
                            text: resolvedCount == 1
                                ? 'report resolved'
                                : 'reports resolved',
                            style: infraHeading(
                              color: Colors.white,
                              fontSize: 17,
                              weight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      softWrap: false,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: .16),
                border: Border.all(color: Colors.white.withValues(alpha: .16)),
              ),
              child: const Icon(
                Icons.volunteer_activism_outlined,
                color: Colors.white,
                size: 32,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _VerificationCard extends StatelessWidget {
  const _VerificationCard({required this.verification, required this.onTap});

  final String verification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = verification.toLowerCase();
    final verified = status == 'verified';
    final pending = status.contains('pending');
    final rejected = status.contains('mismatch') || status.contains('rejected');
    final accent = verified
        ? green
        : rejected
        ? clay
        : amber;
    final icon = verified
        ? Icons.verified_user_rounded
        : pending
        ? Icons.hourglass_top_rounded
        : rejected
        ? Icons.fact_check_outlined
        : Icons.shield_outlined;
    final title = verified
        ? 'Identity verified'
        : pending
        ? 'Verification in review'
        : rejected
        ? 'Update your verification'
        : 'Verify your identity';
    final detail = verified
        ? 'You’re ready to submit trusted community reports.'
        : pending
        ? 'Your documents are being reviewed. We’ll update you when there’s a decision.'
        : rejected
        ? 'Review your identity status and submit clear documents to continue.'
        : 'Complete a quick identity check to unlock community reporting.';
    final action = verified
        ? 'View status'
        : pending
        ? 'Check status'
        : rejected
        ? 'Review and update'
        : 'Start verification';
    final badge = verified
        ? 'VERIFIED'
        : pending
        ? 'IN REVIEW'
        : rejected
        ? 'ACTION NEEDED'
        : 'NOT VERIFIED';

    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: accent.withValues(alpha: .25)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: .11),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: accent, size: 23),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: infraHeading(
                            color: navy,
                            fontSize: 14,
                            weight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          detail,
                          style: const TextStyle(
                            color: inkSoft,
                            fontSize: 11,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 13),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        color: accent,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .55,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      action,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        color: teal,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: teal,
                    size: 16,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileLoadError extends StatelessWidget {
  const _ProfileLoadError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF5F0),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: clay.withValues(alpha: .22)),
    ),
    child: Row(
      children: [
        const Icon(Icons.cloud_off_outlined, color: clay, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(color: ink, fontSize: 11, height: 1.35),
          ),
        ),
        IconButton(
          tooltip: 'Retry loading profile',
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded, color: clay),
        ),
      ],
    ),
  );
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({
    required this.onMyReportsTap,
    required this.onNotificationsTap,
    required this.onChatbotTap,
    required this.reportCount,
    required this.openReportCount,
    required this.unreadNotificationCount,
  });
  final VoidCallback onMyReportsTap;
  final VoidCallback onNotificationsTap;
  final VoidCallback onChatbotTap;
  final int reportCount;
  final int openReportCount;
  final int unreadNotificationCount;
  @override
  Widget build(BuildContext context) => Material(
    clipBehavior: Clip.antiAlias,
    color: Colors.white.withValues(alpha: .58),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(22),
      side: BorderSide(color: Colors.white.withValues(alpha: .86)),
    ),
    child: Column(
      children: [
        MenuRow(
          icon: Icons.description_outlined,
          title: 'My reports',
          subtitle:
              '$openReportCount open · ${reportCount - openReportCount} resolved',
          badge: '$reportCount',
          accentColor: teal,
          inGroup: true,
          onTap: onMyReportsTap,
        ),
        MenuRow(
          icon: Icons.notifications_none,
          title: 'Notifications',
          subtitle: '$unreadNotificationCount unread',
          badge: '$unreadNotificationCount',
          accentColor: amber,
          inGroup: true,
          onTap: onNotificationsTap,
        ),
        MenuRow(
          icon: Icons.chat_outlined,
          title: 'Chatbot assistant',
          subtitle: 'Ask about reports and city updates',
          badge: 'Chat',
          accentColor: navy,
          inGroup: true,
          lastInGroup: true,
          onTap: onChatbotTap,
        ),
      ],
    ),
  );
}

class _TrustSettingsGroup extends StatelessWidget {
  const _TrustSettingsGroup({required this.onPrivacyTap});

  final VoidCallback onPrivacyTap;

  @override
  Widget build(BuildContext context) => Material(
    clipBehavior: Clip.antiAlias,
    color: Colors.white.withValues(alpha: .58),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(22),
      side: BorderSide(color: Colors.white.withValues(alpha: .86)),
    ),
    child: Column(
      children: [
        MenuRow(
          icon: Icons.lock_outline,
          title: 'Privacy & security',
          subtitle: 'Password and account access',
          accentColor: clay,
          inGroup: true,
          lastInGroup: true,
          onTap: onPrivacyTap,
        ),
      ],
    ),
  );
}

class IdentityVerificationPage extends StatefulWidget {
  const IdentityVerificationPage({super.key});

  @override
  State<IdentityVerificationPage> createState() =>
      _IdentityVerificationPageState();
}

class _IdentityVerificationPageState extends State<IdentityVerificationPage> {
  String _verification =
      ApiService.currentUser?['verification']?.toString() ?? 'Not submitted';
  bool _loading = false;
  String? _loadError;

  bool get _isVerified => _verification.toLowerCase() == 'verified';
  bool get _isPending => _verification.toLowerCase().contains('pending');
  bool get _isRejected =>
      _verification.toLowerCase().contains('mismatch') ||
      _verification.toLowerCase().contains('rejected');

  @override
  void initState() {
    super.initState();
    _loadVerification();
  }

  Future<void> _loadVerification() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final profile = await ApiService.profile();
      if (!mounted) return;
      setState(() {
        _verification = profile['verification']?.toString() ?? 'Not submitted';
      });
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _loadError = error.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _startReverification() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const VerifyIdPage()));
    if (mounted) await _loadVerification();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: sand,
    appBar: AppBar(
      title: const Text('Identity verification'),
      backgroundColor: sand,
      foregroundColor: navy,
      elevation: 0,
    ),
    body: AppScroll(
      onRefresh: _loadVerification,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [teal, navy],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: navy.withValues(alpha: .20),
                  blurRadius: 20,
                  offset: const Offset(0, 9),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .18),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white38),
                      ),
                      child: const Icon(
                        Icons.verified_user_outlined,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: (_isVerified ? green : amber).withValues(
                          alpha: .28,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isVerified
                                ? Icons.check_circle
                                : _isPending
                                ? Icons.hourglass_top
                                : _isRejected
                                ? Icons.error_outline
                                : Icons.info_outline,
                            color: Colors.white,
                            size: 15,
                          ),
                          SizedBox(width: 5),
                          Text(
                            _loading
                                ? 'CHECKING'
                                : _isVerified
                                ? 'VERIFIED'
                                : _isPending
                                ? 'PENDING REVIEW'
                                : _isRejected
                                ? 'ACTION REQUIRED'
                                : 'NOT SUBMITTED',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: .6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  _isVerified
                      ? 'Your identity is confirmed'
                      : _isPending
                      ? 'Your documents are under review'
                      : _isRejected
                      ? 'Your verification needs attention'
                      : 'Verify your identity',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _isVerified
                      ? 'You can file trusted reports with InfraTrack.'
                      : _isPending
                      ? 'An admin will review your ID and selfie.'
                      : 'Submit your ID and selfie for admin review.',
                  style: const TextStyle(
                    color: Color(0xFFC5E4E0),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          _SecuritySectionLabel(
            title: 'VERIFICATION CHECKLIST',
            subtitle: _isVerified
                ? 'Both checks are complete for this account.'
                : _isPending
                ? 'Your documents are waiting for admin review.'
                : _isRejected
                ? 'Please submit your documents again for review.'
                : 'Complete both steps to submit your identity for review.',
          ),
          if (_loadError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Could not refresh verification status: $_loadError',
                      style: const TextStyle(color: clay, fontSize: 12),
                    ),
                  ),
                  TextButton(
                    onPressed: _loading ? null : _loadVerification,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .72),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: .9)),
            ),
            child: Column(
              children: [
                _IdentityStep(
                  icon: Icons.badge_outlined,
                  title: 'Government ID',
                  subtitle: _isVerified
                      ? 'Document verified securely'
                      : _isPending
                      ? 'Waiting for admin review'
                      : _isRejected
                      ? 'Please submit a clear ID image'
                      : 'Not submitted',
                  isLast: false,
                  isVerified: _isVerified,
                  isPending: _isPending,
                  isRejected: _isRejected,
                ),
                _IdentityStep(
                  icon: Icons.face_retouching_natural,
                  title: 'Live selfie',
                  subtitle: _isVerified
                      ? 'Face check completed securely'
                      : _isPending
                      ? 'Waiting for admin review'
                      : _isRejected
                      ? 'Please retake your selfie'
                      : 'Not submitted',
                  isLast: true,
                  isVerified: _isVerified,
                  isPending: _isPending,
                  isRejected: _isRejected,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: teal.withValues(alpha: .09),
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: teal.withValues(alpha: .18)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lock_outline, color: teal, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Your ID and selfie are used only for verification. They are never shown publicly on your profile or reports.',
                    style: TextStyle(
                      color: Color(0xFF0E4F49),
                      fontSize: 11.5,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: _startReverification,
              icon: const Icon(Icons.refresh),
              label: const Text('Re-verify identity'),
              style: FilledButton.styleFrom(
                backgroundColor: clay,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _IdentityStep extends StatelessWidget {
  const _IdentityStep({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isLast,
    required this.isVerified,
    required this.isPending,
    required this.isRejected,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isLast;
  final bool isVerified;
  final bool isPending;
  final bool isRejected;

  @override
  Widget build(BuildContext context) {
    final statusColor = isVerified
        ? green
        : isPending
        ? amber
        : isRejected
        ? clay
        : inkSoft;
    final statusIcon = isVerified
        ? Icons.check_circle
        : isPending
        ? Icons.hourglass_top
        : isRejected
        ? Icons.error_outline
        : Icons.radio_button_unchecked;
    return SizedBox(
      height: 78,
      child: Row(
        children: [
          SizedBox(
            width: 42,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (!isLast)
                  Positioned(
                    top: 42,
                    bottom: 0,
                    child: Container(
                      width: 2,
                      color: statusColor.withValues(alpha: .28),
                    ),
                  ),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: .12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: statusColor, size: 19),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(color: inkSoft, fontSize: 10.5),
                ),
              ],
            ),
          ),
          Icon(statusIcon, color: statusColor, size: 20),
        ],
      ),
    );
  }
}

class PrivacySecurityPage extends StatefulWidget {
  const PrivacySecurityPage({super.key});

  @override
  State<PrivacySecurityPage> createState() => _PrivacySecurityPageState();
}

class _PrivacySecurityPageState extends State<PrivacySecurityPage> {
  bool _location = true;
  bool _notifications = true;
  bool _biometric = false;
  bool _biometricBusy = false;
  String? _preferencesError;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final biometricEnabled = await biometricSignIn.isEnabled;
      if (mounted) {
        setState(() => _biometric = biometricEnabled);
      }
      if (!ApiService.isSignedIn) return;
      final preferences = await ApiService.preferences();
      if (!mounted) return;
      setState(() {
        _location = preferences['showLocationOnReports'] as bool;
        _notifications = preferences['allowNotifications'] as bool;
      });
    } catch (error) {
      if (mounted) {
        setState(
          () => _preferencesError = error.toString().replaceFirst(
            'Exception: ',
            '',
          ),
        );
      }
    }
  }

  Future<void> _setBiometricSignIn(bool enabled) async {
    if (_biometricBusy) return;
    if (!enabled) {
      setState(() => _biometricBusy = true);
      try {
        await biometricSignIn.disable();
        if (mounted) setState(() => _biometric = false);
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Could not disable biometric sign-in: ${error.toString().replaceFirst('Exception: ', '')}',
              ),
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _biometricBusy = false);
      }
      return;
    }

    if (!ApiService.isSignedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to enable biometric sign-in.')),
      );
      return;
    }

    setState(() => _biometricBusy = true);
    try {
      if (!await biometricSignIn.isAvailable) {
        throw StateError(
          'Set up fingerprint or face recognition on this device first.',
        );
      }
      final email = ApiService.currentUser?['email']?.toString().trim() ?? '';
      if (email.isEmpty) {
        throw StateError('Your account email is unavailable. Sign in again.');
      }
      final password = await _requestBiometricPassword();
      if (password == null) return;
      if (password.isEmpty) {
        throw StateError('Enter your current password to continue.');
      }
      final authenticated = await biometricSignIn.authenticate(
        'Enable biometric sign-in for InfraTrack',
      );
      if (!authenticated) return;
      await ApiService.login(email, password);
      await biometricSignIn.enable(email: email, password: password);
      if (mounted) {
        setState(() {
          _biometric = true;
          _preferencesError = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Biometric sign-in is enabled.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not enable biometric sign-in: ${error.toString().replaceFirst('Exception: ', '')}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _biometricBusy = false);
    }
  }

  Future<String?> _requestBiometricPassword() async {
    final controller = TextEditingController();
    try {
      return await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Confirm your password'),
          content: TextField(
            controller: controller,
            autofocus: true,
            obscureText: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
            decoration: const InputDecoration(
              labelText: 'Current password',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(controller.text),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _savePreferences({
    bool? allowNotifications,
    bool? showLocationOnReports,
  }) async {
    if (!ApiService.isSignedIn) return;
    final nextNotifications = allowNotifications ?? _notifications;
    final nextLocation = showLocationOnReports ?? _location;
    try {
      final preferences = await ApiService.updatePreferences(
        allowNotifications: nextNotifications,
        showLocationOnReports: nextLocation,
      );
      if (mounted) {
        setState(() {
          _notifications = preferences['allowNotifications'] as bool;
          _location = preferences['showLocationOnReports'] as bool;
          _preferencesError = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _preferencesError = error.toString().replaceFirst(
            'Exception: ',
            '',
          ),
        );
      }
    }
  }

  Future<void> _changePassword() async {
    if (!ApiService.isSignedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to change your password.')),
      );
      return;
    }
    final formKey = GlobalKey<FormState>();
    final current = TextEditingController();
    final next = TextEditingController();
    final confirm = TextEditingController();
    var obscureCurrent = true;
    var obscureNext = true;
    var obscureConfirm = true;
    final updated = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: sand,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: clay.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.key_rounded,
                          color: clay,
                          size: 23,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Change password',
                              style: TextStyle(
                                color: navy,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Keep your account access secure.',
                              style: TextStyle(color: inkSoft, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _PasswordDialogField(
                    controller: current,
                    label: 'Current password',
                    hint: 'Enter your current password',
                    obscureText: obscureCurrent,
                    onToggle: () =>
                        setDialogState(() => obscureCurrent = !obscureCurrent),
                    validator: (value) => value == null || value.isEmpty
                        ? 'Enter your current password.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  _PasswordDialogField(
                    controller: next,
                    label: 'New password',
                    hint: 'Create a stronger password',
                    obscureText: obscureNext,
                    onToggle: () =>
                        setDialogState(() => obscureNext = !obscureNext),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Enter a new password.';
                      }
                      if (value.length < 8) return 'Use at least 8 characters.';
                      if (!RegExp(r'[A-Z]').hasMatch(value)) {
                        return 'Add at least 1 uppercase letter.';
                      }
                      if (!RegExp(r'[0-9]').hasMatch(value)) {
                        return 'Add at least 1 number.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  const _PasswordHint(),
                  const SizedBox(height: 12),
                  _PasswordDialogField(
                    controller: confirm,
                    label: 'Confirm new password',
                    hint: 'Type the new password again',
                    obscureText: obscureConfirm,
                    onToggle: () =>
                        setDialogState(() => obscureConfirm = !obscureConfirm),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please confirm your new password.';
                      }
                      if (value != next.text) {
                        return 'Confirmation does not match the new password.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: navy,
                            side: const BorderSide(color: line),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {
                            if (formKey.currentState!.validate()) {
                              Navigator.pop(dialogContext, true);
                            }
                          },
                          icon: const Icon(Icons.check, size: 17),
                          label: const Text('Update'),
                          style: FilledButton.styleFrom(
                            backgroundColor: clay,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    final currentPassword = current.text;
    final newPassword = next.text;
    current.dispose();
    next.dispose();
    confirm.dispose();
    if (updated == true) {
      final biometricWasEnabled = _biometric;
      try {
        await ApiService.changePassword(
          currentPassword: currentPassword,
          newPassword: newPassword,
        );
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error.toString().replaceFirst('Exception: ', '')),
            ),
          );
        }
        return;
      }
      if (biometricWasEnabled) {
        try {
          await biometricSignIn.disable();
          if (mounted) setState(() => _biometric = false);
        } catch (error) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Password updated, but biometric credentials could not be cleared: ${error.toString().replaceFirst('Exception: ', '')}',
                ),
              ),
            );
          }
          return;
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              biometricWasEnabled
                  ? 'Password updated. Enable biometric sign-in again to use the new password.'
                  : 'Password updated successfully.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: sand,
    appBar: AppBar(
      title: const Text('Privacy & security'),
      backgroundColor: sand,
      foregroundColor: navy,
      elevation: 0,
    ),
    body: AppScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [deepNavy, navy],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: navy.withValues(alpha: .20),
                  blurRadius: 20,
                  offset: const Offset(0, 9),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: teal.withValues(alpha: .28),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
                    color: Colors.white,
                    size: 29,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your account is protected',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'Manage how your information is shared and secured.',
                        style: TextStyle(
                          color: Color(0xFFB9D5D8),
                          fontSize: 11.5,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const _SecuritySectionLabel(
            title: 'PRIVACY CONTROLS',
            subtitle: 'Choose what InfraTrack can share with you and the city.',
          ),
          if (_preferencesError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _preferencesError!,
                style: const TextStyle(color: clay),
              ),
            ),
          _SettingsCard(
            children: [
              _PrivacySettingTile(
                icon: Icons.location_on_outlined,
                color: teal,
                title: 'Show location on reports',
                subtitle: 'Helps the city locate reported issues',
                value: _location,
                onChanged: (value) {
                  if (!ApiService.isSignedIn) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Sign in to update privacy settings.'),
                      ),
                    );
                    return;
                  }
                  _savePreferences(showLocationOnReports: value);
                },
              ),
              _PrivacySettingTile(
                icon: Icons.notifications_none,
                color: amber,
                title: 'Report updates',
                subtitle: 'Receive status and city advisory alerts',
                value: _notifications,
                onChanged: (value) {
                  if (!ApiService.isSignedIn) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Sign in to update privacy settings.'),
                      ),
                    );
                    return;
                  }
                  _savePreferences(allowNotifications: value);
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          const _SecuritySectionLabel(
            title: 'SECURITY',
            subtitle: 'Keep your account access private and up to date.',
          ),
          _SettingsCard(
            children: [
              _PrivacySettingTile(
                icon: Icons.fingerprint,
                color: navy,
                title: 'Biometric sign-in',
                subtitle: 'Use fingerprint or face recognition to sign in',
                value: _biometric,
                onChanged: _biometricBusy ? null : _setBiometricSignIn,
              ),
              _ActionSettingTile(
                icon: Icons.key_outlined,
                color: clay,
                title: 'Change password',
                subtitle: 'Update your sign-in password',
                onTap: _changePassword,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .56),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: line),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: inkSoft, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Your password is stored in encrypted device storage for biometric sign-in. Face and fingerprint data stay on your device.',
                    style: TextStyle(color: inkSoft, fontSize: 11, height: 1.5),
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

class _PasswordDialogField extends StatelessWidget {
  const _PasswordDialogField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.obscureText,
    required this.onToggle,
    required this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final bool obscureText;
  final VoidCallback onToggle;
  final FormFieldValidator<String> validator;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label.toUpperCase(),
        style: infraMono(
          color: inkSoft,
          fontSize: 9.5,
          weight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 6),
      TextFormField(
        controller: controller,
        obscureText: obscureText,
        validator: validator,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.lock_outline, color: inkSoft, size: 19),
          suffixIcon: IconButton(
            tooltip: obscureText ? 'Show password' : 'Hide password',
            onPressed: onToggle,
            icon: Icon(
              obscureText
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              size: 19,
            ),
          ),
          filled: true,
          fillColor: Colors.white.withValues(alpha: .72),
        ),
      ),
    ],
  );
}

class _PasswordHint extends StatelessWidget {
  const _PasswordHint();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
    decoration: BoxDecoration(
      color: teal.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(11),
    ),
    child: const Row(
      children: [
        Icon(Icons.info_outline, color: teal, size: 16),
        SizedBox(width: 7),
        Expanded(
          child: Text(
            'Use 8+ characters with an uppercase letter and a number.',
            style: TextStyle(
              color: Color(0xFF0E4F49),
              fontSize: 10.5,
              height: 1.3,
            ),
          ),
        ),
      ],
    ),
  );
}

class _SecuritySectionLabel extends StatelessWidget {
  const _SecuritySectionLabel({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: infraMono(
            color: inkSoft,
            fontSize: 10,
            weight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(subtitle, style: const TextStyle(color: inkSoft, fontSize: 11)),
      ],
    ),
  );
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .70),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withValues(alpha: .90)),
      boxShadow: [
        BoxShadow(
          color: navy.withValues(alpha: .05),
          blurRadius: 15,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: Column(
      children: [
        for (var index = 0; index < children.length; index++) ...[
          children[index],
          if (index != children.length - 1)
            const Divider(height: 1, indent: 70),
        ],
      ],
    ),
  );
}

class _PrivacySettingTile extends StatelessWidget {
  const _PrivacySettingTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
    leading: _SettingsIcon(icon: icon, color: color),
    title: Text(
      title,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: ink,
      ),
    ),
    subtitle: Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Text(
        subtitle,
        style: const TextStyle(fontSize: 10.5, color: inkSoft),
      ),
    ),
    trailing: Switch.adaptive(value: value, onChanged: onChanged),
  );
}

class _ActionSettingTile extends StatelessWidget {
  const _ActionSettingTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onTap,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
    leading: _SettingsIcon(icon: icon, color: color),
    title: Text(
      title,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: ink,
      ),
    ),
    subtitle: Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Text(
        subtitle,
        style: const TextStyle(fontSize: 10.5, color: inkSoft),
      ),
    ),
    trailing: const Icon(Icons.chevron_right, color: inkSoft),
  );
}

class _SettingsIcon extends StatelessWidget {
  const _SettingsIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 40,
    height: 40,
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Icon(icon, color: color, size: 20),
  );
}
