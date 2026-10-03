part of '../main.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  XFile? _profileImage;

  Future<void> _editProfile(BuildContext context) async {
    final nameController = TextEditingController(text: 'Elena Marasigan');
    XFile? selectedImage = _profileImage;
    final result = await showDialog<(String, XFile?)>(
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
                  final image = await ImagePicker().pickImage(
                    source: source,
                    imageQuality: 85,
                  );
                  if (image != null) {
                    selectedImage = image;
                    setDialogState(() {});
                  }
                },
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 38,
                      backgroundColor: const Color(0xFF2A6C7C),
                      backgroundImage: selectedImage == null
                          ? null
                          : FileImage(File(selectedImage!.path)),
                      child: selectedImage == null
                          ? const Text(
                              'EM',
                              style: TextStyle(
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
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tap the photo to change it',
                style: TextStyle(color: inkSoft, fontSize: 11),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Display name',
                  prefixIcon: Icon(Icons.person_outline),
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
            onPressed: () => Navigator.pop(dialogContext, (
              nameController.text.trim(),
              selectedImage,
            )),
            style: FilledButton.styleFrom(backgroundColor: clay),
            child: const Text('Save changes'),
          ),
        ],
      ),
    );
    nameController.dispose();
    if (result != null && result.$1.isNotEmpty && context.mounted) {
      setState(() => _profileImage = result.$2);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile changes saved on this device.')),
      );
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
      child: Column(
        children: [
          _ProfileHeader(
            onEdit: () => _editProfile(context),
            profileImage: _profileImage,
          ),
          Transform.translate(
            offset: const Offset(0, -21),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: const [
                  Expanded(
                    child: _ProfileStat(
                      number: '12',
                      label: 'Reports filed',
                      icon: Icons.description_outlined,
                      color: teal,
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: _ProfileStat(
                      number: '9',
                      label: 'Resolved',
                      icon: Icons.check_circle_outline,
                      color: green,
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: _ProfileStat(
                      number: '4.8',
                      label: 'Avg. rating',
                      icon: Icons.star_outline,
                      color: amber,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const _ProfileSectionTitle(title: 'YOUR ACTIVITY'),
          const _ImpactCard(),
          const SizedBox(height: 12),
          const _ProfileCompletionCard(),
          const SizedBox(height: 20),
          const _ProfileSectionTitle(title: 'ACTIVITY & TOOLS'),
          _SettingsGroup(
            onMyReportsTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const MyReportsPage())),
            onNotificationsTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationsPage()),
            ),
            onChatbotTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const ChatbotPage())),
          ),
          const SizedBox(height: 20),
          const _ProfileSectionTitle(title: 'TRUST & SECURITY'),
          _TrustSettingsGroup(
            onIdentityTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const IdentityVerificationPage(),
              ),
            ),
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
        ],
      ),
    ),
  );
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.onEdit, this.profileImage});

  final VoidCallback onEdit;
  final XFile? profileImage;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(18, 18, 18, 46),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [deepNavy, navy, Color(0xFF155B66)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
    ),
    child: Stack(
      children: [
        Positioned(
          right: -35,
          top: -45,
          child: Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white12),
            ),
          ),
        ),
        Positioned(
          top: -4,
          right: -4,
          child: IconButton(
            onPressed: onEdit,
            style: IconButton.styleFrom(
              minimumSize: const Size(34, 34),
              padding: EdgeInsets.zero,
              backgroundColor: Colors.white12,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.edit_outlined, size: 18),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'MY PROFILE',
              style: TextStyle(
                color: Color(0xFF9FC2C9),
                fontSize: 10,
                letterSpacing: 1.3,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 14),
            Row(
              children: [
                _ProfileAvatar(image: profileImage),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Elena Marasigan',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Member since Feb 2026',
                        style: TextStyle(color: Color(0xFFB9CBD1)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 11),
            Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  color: Color(0xFF8FD6CE),
                  size: 14,
                ),
                SizedBox(width: 3),
                Text(
                  'Barangay Central',
                  style: TextStyle(color: Color(0xFFD9E7E9), fontSize: 11),
                ),
                SizedBox(width: 9),
                Icon(Icons.star_rounded, color: amber, size: 14),
                SizedBox(width: 3),
                Text(
                  'Top reporter',
                  style: TextStyle(color: Color(0xFFD9E7E9), fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  );
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({this.image});
  final XFile? image;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 62,
    height: 62,
    child: Stack(
      children: [
        Container(
          padding: const EdgeInsets.all(2),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0x442A6C7C),
          ),
          child: CircleAvatar(
            radius: 29,
            backgroundColor: Color(0xFF2A6C7C),
            backgroundImage: image == null
                ? null
                : FileImage(File(image!.path)),
            child: image == null
                ? const Text(
                    'EM',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  )
                : null,
          ),
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: 15,
            height: 15,
            decoration: BoxDecoration(
              color: green,
              shape: BoxShape.circle,
              border: Border.all(color: deepNavy, width: 2),
            ),
          ),
        ),
      ],
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

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({
    required this.number,
    required this.label,
    required this.icon,
    required this.color,
  });
  final String number, label;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    height: 72,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .76),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.white.withValues(alpha: .9)),
      boxShadow: [
        BoxShadow(
          color: navy.withValues(alpha: .08),
          blurRadius: 16,
          offset: const Offset(0, 7),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              number,
              style: infraHeading(
                color: navy,
                fontSize: 22,
                weight: FontWeight.w800,
              ),
            ),
            Icon(icon, color: color, size: 16),
          ],
        ),
        const Spacer(),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: inkSoft, fontSize: 9),
        ),
      ],
    ),
  );
}

class _ImpactCard extends StatelessWidget {
  const _ImpactCard();
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [teal, navy],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(22),
      boxShadow: [
        BoxShadow(
          color: navy.withValues(alpha: .18),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: const Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'YOUR COMMUNITY IMPACT',
                style: TextStyle(
                  color: Color(0xFFB8E4DE),
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 7),
              Text(
                '9 issues helped move\ntoward resolution',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        CircleAvatar(
          radius: 27,
          backgroundColor: Colors.white24,
          child: Icon(Icons.volunteer_activism_outlined, color: Colors.white),
        ),
      ],
    ),
  );
}

class _ProfileCompletionCard extends StatelessWidget {
  const _ProfileCompletionCard();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 15),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .72),
      borderRadius: BorderRadius.circular(19),
      border: Border.all(color: Colors.white.withValues(alpha: .92)),
    ),
    child: Row(
      children: [
        SizedBox(
          width: 48,
          height: 48,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: 1,
                strokeWidth: 4,
                color: green.withValues(alpha: .20),
              ),
              const Icon(Icons.check, color: green, size: 20),
            ],
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Profile complete',
                style: TextStyle(
                  color: navy,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Identity verified · Ready to report',
                style: TextStyle(color: inkSoft, fontSize: 10.5),
              ),
            ],
          ),
        ),
        const Icon(Icons.verified_user_outlined, color: green, size: 20),
      ],
    ),
  );
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({
    required this.onMyReportsTap,
    required this.onNotificationsTap,
    required this.onChatbotTap,
  });
  final VoidCallback onMyReportsTap;
  final VoidCallback onNotificationsTap;
  final VoidCallback onChatbotTap;
  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .58),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: Colors.white.withValues(alpha: .86)),
    ),
    child: Column(
      children: [
        MenuRow(
          icon: Icons.description_outlined,
          title: 'My reports',
          subtitle: '3 open · 9 resolved',
          badge: '12',
          accentColor: teal,
          inGroup: true,
          onTap: onMyReportsTap,
        ),
        MenuRow(
          icon: Icons.notifications_none,
          title: 'Notifications',
          subtitle: '3 new',
          badge: '3 new',
          accentColor: amber,
          inGroup: true,
          onTap: onNotificationsTap,
        ),
        MenuRow(
          icon: Icons.chat_outlined,
          title: 'Chatbot assistant',
          subtitle: 'Online · replies in seconds',
          badge: 'Online',
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
  const _TrustSettingsGroup({
    required this.onIdentityTap,
    required this.onPrivacyTap,
  });

  final VoidCallback onIdentityTap;
  final VoidCallback onPrivacyTap;

  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .58),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: Colors.white.withValues(alpha: .86)),
    ),
    child: Column(
      children: [
        MenuRow(
          icon: Icons.verified_user_outlined,
          title: 'Identity verification',
          subtitle: 'Verified account',
          badge: 'Verified',
          accentColor: green,
          inGroup: true,
          onTap: onIdentityTap,
        ),
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
                        color: green.withValues(alpha: .28),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Colors.white,
                            size: 15,
                          ),
                          SizedBox(width: 5),
                          Text(
                            'VERIFIED',
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
                const Text(
                  'Your identity is confirmed',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'You can file trusted reports with InfraTrack.',
                  style: TextStyle(color: Color(0xFFC5E4E0), fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const _SecuritySectionLabel(
            title: 'VERIFICATION CHECKLIST',
            subtitle: 'Both checks are complete for this account.',
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .72),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: .9)),
            ),
            child: const Column(
              children: [
                _IdentityStep(
                  icon: Icons.badge_outlined,
                  title: 'Government ID',
                  subtitle: 'Document verified securely',
                  isLast: false,
                ),
                _IdentityStep(
                  icon: Icons.face_retouching_natural,
                  title: 'Live selfie',
                  subtitle: 'Face check completed securely',
                  isLast: true,
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
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const VerifyIdPage())),
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
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isLast;

  @override
  Widget build(BuildContext context) => SizedBox(
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
                    color: green.withValues(alpha: .28),
                  ),
                ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: green.withValues(alpha: .12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: green, size: 19),
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
        const Icon(Icons.check_circle, color: green, size: 20),
      ],
    ),
  );
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

  Future<void> _changePassword() async {
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
    current.dispose();
    next.dispose();
    confirm.dispose();
    if (updated == true && mounted) {
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
          _SettingsCard(
            children: [
              _PrivacySettingTile(
                icon: Icons.location_on_outlined,
                color: teal,
                title: 'Show location on reports',
                subtitle: 'Helps the city locate reported issues',
                value: _location,
                onChanged: (value) => setState(() => _location = value),
              ),
              _PrivacySettingTile(
                icon: Icons.notifications_none,
                color: amber,
                title: 'Report updates',
                subtitle: 'Receive status and city advisory alerts',
                value: _notifications,
                onChanged: (value) => setState(() => _notifications = value),
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
                title: 'Biometric app lock',
                subtitle: 'Use device biometrics when available',
                value: _biometric,
                onChanged: (value) => setState(() => _biometric = value),
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
                    'These settings apply on this device. Your credentials and identity documents remain private.',
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
  final ValueChanged<bool> onChanged;

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
