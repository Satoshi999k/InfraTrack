part of '../main.dart';

class CreateAccountPage extends StatefulWidget {
  const CreateAccountPage({super.key});

  @override
  State<CreateAccountPage> createState() => _CreateAccountPageState();
}

class _CreateAccountPageState extends State<CreateAccountPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  String _barangay = 'Barangay Central';
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  bool get _hasUppercase => RegExp(r'[A-Z]').hasMatch(_passwordController.text);
  bool get _hasNumber => RegExp(r'[0-9]').hasMatch(_passwordController.text);

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String? _required(String? value, String label) {
    if (value == null || value.trim().isEmpty) return '$label is required';
    return null;
  }

  String? _emailValidator(String? value) {
    final required = _required(value, 'Email address');
    if (required != null) return required;
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value!.trim())) {
      return 'Enter a valid email address';
    }
    return null;
  }

  Future<void> _continue() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      await ApiService.register(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        mobile: _mobileController.text.trim(),
        barangay: _barangay,
        password: _passwordController.text,
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
    if (!mounted) return;
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const VerifyIdPage()));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFEAF4F0),
    appBar: AppBar(
      backgroundColor: Colors.white.withValues(alpha: .36),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        onPressed: () => Navigator.of(context).pop(),
        tooltip: 'Back',
        icon: const Icon(Icons.arrow_back, color: navy),
      ),
    ),
    body: Stack(
      children: [
        const Positioned(
          top: -90,
          right: -70,
          child: _GlassOrb(size: 230, color: Color(0x331B8A83)),
        ),
        const Positioned(
          top: 210,
          left: -115,
          child: _GlassOrb(size: 210, color: Color(0x22C1592B)),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFFEAF4F0), sand.withValues(alpha: .82)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              top: false,
              child: Form(
                key: _formKey,
                child: AppScroll(
                  paddingTop: 10,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .52),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: .78),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: navy.withValues(alpha: .10),
                              blurRadius: 26,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _SignupProgress(),
                            const SizedBox(height: 18),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: navy.withValues(alpha: .06),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: navy.withValues(alpha: .10),
                                ),
                              ),
                              child: const Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _SignupIntroIcon(),
                                  SizedBox(width: 11),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Join the verified citizen network',
                                          style: TextStyle(
                                            color: navy,
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        SizedBox(height: 5),
                                        Text(
                                          'Create an account to file reports, follow progress, and help improve Mati City.',
                                          style: TextStyle(
                                            color: inkSoft,
                                            fontSize: 11,
                                            height: 1.45,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Create your citizen account',
                              style: infraHeading(
                                color: navy,
                                fontSize: 22,
                                weight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Every account is verified with a valid ID and a live selfie so reports stay trustworthy and duplicate or fake accounts are filtered out.',
                              style: TextStyle(
                                color: inkSoft,
                                fontSize: 12.5,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 22),
                            _SignupField(
                              label: 'Full legal name',
                              hint: 'As shown on your ID',
                              icon: Icons.badge_outlined,
                              controller: _nameController,
                              validator: (value) =>
                                  _required(value, 'Full legal name'),
                            ),
                            const _SignupGroupHeading(
                              title: 'ACCOUNT DETAILS',
                              subtitle:
                                  'Use contact details the city can reach.',
                            ),
                            _SignupField(
                              label: 'Email address',
                              hint: 'you@example.com',
                              icon: Icons.mail_outline,
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              validator: _emailValidator,
                            ),
                            _SignupField(
                              label: 'Mobile number',
                              hint: '09XX XXX XXXX',
                              icon: Icons.call_outlined,
                              controller: _mobileController,
                              keyboardType: TextInputType.phone,
                              validator: (value) =>
                                  _required(value, 'Mobile number'),
                            ),
                            const _SignupLabel('Barangay'),
                            DropdownButtonFormField<String>(
                              initialValue: _barangay,
                              decoration: const InputDecoration(
                                prefixIcon: Icon(
                                  Icons.place_outlined,
                                  color: inkSoft,
                                ),
                              ),
                              items:
                                  const [
                                    'Barangay Central',
                                    'Purok 3',
                                    'Dawan',
                                    'Sainz',
                                    'Bobon',
                                  ].map((barangay) {
                                    return DropdownMenuItem(
                                      value: barangay,
                                      child: Text(barangay),
                                    );
                                  }).toList(),
                              onChanged: (value) =>
                                  setState(() => _barangay = value!),
                            ),
                            const SizedBox(height: 14),
                            const _SignupGroupHeading(
                              title: 'SECURE YOUR ACCOUNT',
                              subtitle:
                                  'Create a password only you can access.',
                            ),
                            _SignupField(
                              label: 'Password',
                              hint: 'Min. 8 characters',
                              icon: Icons.key_outlined,
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              validator: (value) {
                                final required = _required(value, 'Password');
                                if (required != null) return required;
                                if (value!.length < 8) {
                                  return 'Password must be at least 8 characters.';
                                }
                                if (!_hasUppercase) {
                                  return 'Password needs at least 1 uppercase letter.';
                                }
                                if (!_hasNumber) {
                                  return 'Password needs at least 1 number.';
                                }
                                return null;
                              },
                              onChanged: (_) => setState(() {}),
                              suffixIcon: IconButton(
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  size: 19,
                                ),
                              ),
                            ),
                            _PasswordRequirements(
                              hasLength: _passwordController.text.length >= 8,
                              hasUppercase: _hasUppercase,
                              hasNumber: _hasNumber,
                            ),
                            _SignupField(
                              label: 'Confirm password',
                              hint: 'Repeat your password',
                              icon: Icons.key_outlined,
                              controller: _confirmController,
                              obscureText: _obscureConfirm,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please confirm your password.';
                                }
                                if (value != _passwordController.text) {
                                  return 'Your confirmation doesn’t match the Password above.';
                                }
                                return null;
                              },
                              onChanged: (_) => setState(() {}),
                              suffixIcon: IconButton(
                                onPressed: () => setState(
                                  () => _obscureConfirm = !_obscureConfirm,
                                ),
                                icon: Icon(
                                  _obscureConfirm
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  size: 19,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: teal.withValues(alpha: .10),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.verified_user_outlined,
                                    color: teal,
                                    size: 20,
                                  ),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Your account will be verified with a valid government ID and a live selfie. Your documents are never shown publicly.',
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
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: FilledButton(
                                onPressed: _continue,
                                style: FilledButton.styleFrom(
                                  backgroundColor: clay,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: const Text(
                                  'Continue to ID verification',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Center(
                              child: TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text.rich(
                                  TextSpan(
                                    text: 'Already verified? ',
                                    style: TextStyle(color: inkSoft),
                                    children: [
                                      TextSpan(
                                        text: 'Log in',
                                        style: TextStyle(
                                          color: teal,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class VerifyIdPage extends StatefulWidget {
  const VerifyIdPage({super.key});

  @override
  State<VerifyIdPage> createState() => _VerifyIdPageState();
}

class _VerifyIdPageState extends State<VerifyIdPage> {
  final _picker = ImagePicker();
  final _idTypes = const [
    ('National ID', Icons.badge_outlined),
    ("Driver's License", Icons.directions_car_outlined),
    ("Voter's ID", Icons.how_to_vote_outlined),
    ('Passport', Icons.flight_outlined),
    ('UMID / SSS', Icons.school_outlined),
  ];
  int _selectedId = 0;
  XFile? _frontImage;
  XFile? _backImage;
  bool _isProcessing = false;

  Future<void> _pickImage({required bool front}) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        decoration: const BoxDecoration(
          color: sand,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: line,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Add ${front ? 'front' : 'back'} of ID',
                style: infraHeading(
                  color: navy,
                  fontSize: 18,
                  weight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Choose how you want to add your ID photo.',
                style: TextStyle(color: inkSoft, fontSize: 12),
              ),
              const SizedBox(height: 12),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                tileColor: Colors.white.withValues(alpha: .68),
                leading: const CircleAvatar(
                  backgroundColor: teal,
                  foregroundColor: Colors.white,
                  child: Icon(Icons.camera_alt_outlined),
                ),
                title: const Text(
                  'Take a photo',
                  style: TextStyle(color: navy, fontWeight: FontWeight.w700),
                ),
                subtitle: const Text('Use your phone camera'),
                onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
              ),
              const SizedBox(height: 8),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                tileColor: Colors.white.withValues(alpha: .68),
                leading: const CircleAvatar(
                  backgroundColor: clay,
                  foregroundColor: Colors.white,
                  child: Icon(Icons.photo_library_outlined),
                ),
                title: const Text(
                  'Choose from gallery',
                  style: TextStyle(color: navy, fontWeight: FontWeight.w700),
                ),
                subtitle: const Text('Select an existing clear photo'),
                onTap: () =>
                    Navigator.of(sheetContext).pop(ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
    if (source == null) return;

    try {
      final image = await _picker.pickImage(source: source, imageQuality: 85);
      if (image == null || !mounted) return;
      setState(() {
        if (front) {
          _frontImage = image;
        } else {
          _backImage = image;
        }
      });
    } on PlatformException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to access images. Please check app permissions.',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: navy,
        ),
      );
    }
  }

  Future<void> _continue() async {
    if (_frontImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload the front side of your ID first.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: navy,
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);
    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SelfieVerificationPage(
          idImage: _frontImage!,
          idFace: null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFEAF4F0),
    appBar: AppBar(
      backgroundColor: Colors.white.withValues(alpha: .36),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        onPressed: () => Navigator.of(context).pop(),
        tooltip: 'Back',
        icon: const Icon(Icons.arrow_back, color: navy),
      ),
    ),
    body: Stack(
      children: [
        const Positioned(
          top: -90,
          right: -70,
          child: _GlassOrb(size: 230, color: Color(0x331B8A83)),
        ),
        const Positioned(
          top: 290,
          left: -120,
          child: _GlassOrb(size: 210, color: Color(0x22C1592B)),
        ),
        SafeArea(
          top: false,
          child: AppScroll(
            paddingTop: 10,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .52),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: .78),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SignupProgress(activeStep: 2),
                      const SizedBox(height: 20),
                      const _StepIcon(icon: Icons.badge_outlined, color: clay),
                      const SizedBox(height: 14),
                      Text(
                        'Verify a government ID',
                        style: infraHeading(
                          color: navy,
                          fontSize: 22,
                          weight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "This confirms you're a real resident before you can file reports.",
                        style: TextStyle(
                          color: inkSoft,
                          fontSize: 12.5,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const _VerificationNote(),
                      const SizedBox(height: 20),
                      const _SignupLabel('Select ID type'),
                      SizedBox(
                        height: 48,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _idTypes.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final item = _idTypes[index];
                            final selected = index == _selectedId;
                            return ChoiceChip(
                              label: Text(item.$1),
                              avatar: Icon(item.$2, size: 16),
                              selected: selected,
                              onSelected: (_) =>
                                  setState(() => _selectedId = index),
                              selectedColor: navy,
                              backgroundColor: Colors.white.withValues(
                                alpha: .64,
                              ),
                              labelStyle: TextStyle(
                                color: selected ? Colors.white : inkSoft,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                              side: BorderSide(color: selected ? navy : line),
                              avatarBorder: const CircleBorder(),
                              showCheckmark: false,
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 20),
                      const _SignupLabel('Upload photos of your ID'),
                      Row(
                        children: [
                          Expanded(
                            child: _IdUploadBox(
                              label: 'Front side',
                              sublabel: 'Clear, no glare',
                              image: _frontImage,
                              onTap: () => _pickImage(front: true),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _IdUploadBox(
                              label: 'Back side',
                              sublabel: 'If applicable',
                              image: _backImage,
                              onTap: () => _pickImage(front: false),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const _VerificationChecklist(),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: FilledButton.icon(
                          onPressed: _isProcessing ? null : _continue,
                          icon: const Icon(Icons.arrow_forward, size: 19),
                          label: Text(
                            _isProcessing
                                ? 'Detecting face…'
                                : 'Continue to selfie verification',
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: clay,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
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
}

class LivenessChallengeState {
  static const double minTurnAngle = 20.0;
  static const double maxTurnAngle = 55.0;

  static String instructionForStep(int step) {
    switch (step) {
      case 0:
        return 'Turn your head left to continue.';
      case 1:
        return 'Now turn your head right to continue.';
      default:
        return 'Face verified. Final selfie capture is almost ready.';
    }
  }

  static bool isTurnSatisfied({
    required double headYaw,
    required bool turnLeft,
  }) {
    final magnitude = headYaw.abs();
    if (turnLeft) {
      return headYaw <= -minTurnAngle &&
          headYaw >= -maxTurnAngle &&
          magnitude >= minTurnAngle;
    }
    return headYaw >= minTurnAngle &&
        headYaw <= maxTurnAngle &&
        magnitude >= minTurnAngle;
  }
}

class _FaceVerificationService {
  static List<Rect> detectionRegions(double width, double height) {
    final safeWidth = width <= 0 ? 1.0 : width;
    final safeHeight = height <= 0 ? 1.0 : height;

    return [
      Rect.fromLTWH(0, 0, safeWidth, safeHeight),
      Rect.fromLTWH(
        safeWidth * 0.15,
        safeHeight * 0.08,
        safeWidth * 0.7,
        safeHeight * 0.84,
      ),
      Rect.fromLTWH(
        safeWidth * 0.08,
        safeHeight * 0.14,
        safeWidth * 0.84,
        safeHeight * 0.72,
      ),
      Rect.fromLTWH(
        safeWidth * 0.05,
        safeHeight * 0.2,
        safeWidth * 0.9,
        safeHeight * 0.6,
      ),
    ];
  }

  static Future<Uint8List?> _cropImageRegion(ui.Image image, Rect region) async {
    final left = region.left.clamp(0, image.width.toDouble()).toDouble();
    final top = region.top.clamp(0, image.height.toDouble()).toDouble();
    final width = region.width
        .clamp(1, (image.width.toDouble() - left).clamp(1, double.infinity))
        .toDouble();
    final height = region.height
        .clamp(1, (image.height.toDouble() - top).clamp(1, double.infinity))
        .toDouble();
    final cropRect = Rect.fromLTWH(left, top, width, height);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImageRect(
      image,
      cropRect,
      Rect.fromLTWH(0, 0, cropRect.width, cropRect.height),
      Paint(),
    );
    final picture = recorder.endRecording();
    final scaled = await picture.toImage(cropRect.width.ceil(), cropRect.height.ceil());
    final bytes = await scaled.toByteData(format: ui.ImageByteFormat.png);
    return bytes?.buffer.asUint8List();
  }

  static Future<List<Face>> detect(XFile image) async {
    final path = image.path.trim();
    if (path.isEmpty) {
      return const <Face>[];
    }

    final detector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.accurate,
        enableLandmarks: false,
        enableContours: false,
        enableClassification: false,
        minFaceSize: 0.05,
      ),
    );

    try {
      final file = File(path);
      final candidatePaths = <String>[path];

      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        if (bytes.isNotEmpty) {
          final codec = await ui.instantiateImageCodec(bytes, targetWidth: 1800);
          final frame = await codec.getNextFrame();
          final decoded = frame.image;

          for (final region in detectionRegions(
            decoded.width.toDouble(),
            decoded.height.toDouble(),
          )) {
            final cropped = await _cropImageRegion(decoded, region);
            if (cropped == null || cropped.isEmpty) {
              continue;
            }
            final temporaryFile = File(
              '${Directory.systemTemp.path}${Platform.pathSeparator}'
              'infratrack_id_${DateTime.now().microsecondsSinceEpoch}_${candidatePaths.length}.png',
            );
            await temporaryFile.writeAsBytes(cropped, flush: true);
            if (await temporaryFile.exists()) {
              candidatePaths.add(temporaryFile.path);
            }
          }
        }
      }

      for (final candidatePath in candidatePaths) {
        try {
          final faces = await detector.processImage(
            InputImage.fromFilePath(candidatePath),
          );
          if (faces.isNotEmpty) {
            return faces;
          }
        } catch (_) {
          // Try the next candidate if this image path does not decode cleanly.
        }
      }

      return const <Face>[];
    } on Exception {
      return const <Face>[];
    } finally {
      await detector.close();
    }
  }

  // This is only a visual-quality comparison. ML Kit detects faces but does
  // not identify people. A production identity match must use embeddings on a
  // secure backend and never trust this client-side score for approval.
  static double qualitySimilarity(Rect idFace, Rect selfieFace) {
    final idRatio = idFace.width / idFace.height;
    final selfieRatio = selfieFace.width / selfieFace.height;
    final difference = (idRatio - selfieRatio).abs();
    return (1 - difference * 2.5).clamp(0.0, 1.0);
  }
}

class SelfieVerificationPage extends StatefulWidget {
  const SelfieVerificationPage({super.key, required this.idImage, this.idFace});

  static const double previewHeight = 620.0;

  final XFile idImage;
  final Face? idFace;

  @override
  State<SelfieVerificationPage> createState() => _SelfieVerificationPageState();
}

class _SelfieVerificationPageState extends State<SelfieVerificationPage> {
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.fast,
      enableContours: false,
      enableLandmarks: false,
      enableClassification: false,
    ),
  );

  CameraController? _cameraController;
  XFile? _selfie;
  String _status = 'Center your face in the frame.';
  double? _score;
  bool _processing = false;
  int _livenessStep = 0;
  bool _livenessComplete = false;
  int _noFaceFrames = 0;
  int _centeredFrames = 0;
  bool _faceStable = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initCamera();
      }
    });
  }

  @override
  void dispose() {
    if (_cameraController != null &&
        _cameraController!.value.isStreamingImages) {
      _cameraController!.stopImageStream();
    }
    _cameraController?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      if (!mounted) return;

      setState(() {
        _status = LivenessChallengeState.instructionForStep(0);
      });
      await _startLivenessCheck();
    } on CameraException catch (error) {
      if (!mounted) return;
      _showMessage(
        'Unable to access the camera: ${error.description ?? error.code}',
      );
    } on MissingPluginException {
      if (!mounted) return;
      _showMessage('Camera support is unavailable in this build.');
    } catch (error) {
      if (!mounted) return;
      _showMessage('Unable to initialize the camera: $error');
    }
  }

  Future<void> _startLivenessCheck() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    if (_cameraController!.value.isStreamingImages) {
      await _cameraController!.stopImageStream();
    }

    _livenessStep = 0;
    _livenessComplete = false;
    if (!mounted) return;

    setState(() {
      _score = null;
      _status = LivenessChallengeState.instructionForStep(0);
    });

    await _cameraController!.startImageStream((cameraImage) async {
      if (_processing || _livenessComplete || !mounted) return;

      try {
        final faces = await _faceDetector.processImage(
          _inputImageFromCameraImage(cameraImage),
        );

        if (!mounted) return;
        if (faces.isEmpty) {
          _noFaceFrames += 1;
          if (_noFaceFrames >= 4) {
            setState(() => _status = 'Center your face in the frame and keep still.');
          }
          return;
        }

        _noFaceFrames = 0;

        final face = faces.first;
        final centeredFace = face.boundingBox.center.dx > 0.18 &&
            face.boundingBox.center.dx < 0.82 &&
            face.boundingBox.center.dy > 0.15 &&
            face.boundingBox.center.dy < 0.85;
        final faceAreaRatio =
            (face.boundingBox.width * face.boundingBox.height) /
            (cameraImage.width * cameraImage.height);

        if (!centeredFace || faceAreaRatio < 0.04) {
          _faceStable = false;
          _centeredFrames = 0;
          _noFaceFrames += 1;
          if (_noFaceFrames >= 4) {
            setState(
              () => _status = 'Center your face in the frame and keep still.',
            );
          }
          return;
        }

        _noFaceFrames = 0;
        _centeredFrames += 1;

        if (_centeredFrames < 6) {
          setState(
            () => _status = 'Face detected. Keep still while we verify…',
          );
          return;
        }

        _faceStable = true;
        _livenessStep = 1;
        if (_cameraController != null &&
            _cameraController!.value.isStreamingImages) {
          await _cameraController!.stopImageStream();
        }
        if (!mounted) return;
        await _captureSelfie();
        return;
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _status = 'Center your face in the frame and keep still.';
        });
      }
    });
  }

  InputImage _inputImageFromCameraImage(CameraImage cameraImage) {
    final bytes = Uint8List(
      cameraImage.planes.fold<int>(
        0,
        (total, plane) => total + plane.bytes.length,
      ),
    );

    var offset = 0;
    for (final plane in cameraImage.planes) {
      bytes.setRange(offset, offset + plane.bytes.length, plane.bytes);
      offset += plane.bytes.length;
    }

    final format =
        InputImageFormatValue.fromRawValue(cameraImage.format.raw) ??
        InputImageFormat.nv21;

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(cameraImage.width.toDouble(), cameraImage.height.toDouble()),
        rotation: InputImageRotation.rotation0deg,
        format: format,
        bytesPerRow: cameraImage.planes.first.bytesPerRow,
      ),
    );
  }

  Future<void> _captureSelfie() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      _showMessage('Camera is not ready yet. Please wait a moment.');
      return;
    }

    try {
      setState(() {
        _processing = true;
        _score = null;
        _status = 'Taking final selfie…';
      });

      final image = await _cameraController!.takePicture();
      if (!mounted) return;
      setState(() {
        _selfie = image;
      });

      final faces = await _FaceVerificationService.detect(image);
      if (!mounted) return;
      if (faces.length != 1) {
        setState(() {
          _processing = false;
          _status = faces.isEmpty
              ? 'No face detected. Retake the selfie in good lighting.'
              : 'Multiple faces detected. Only you should be in the selfie.';
        });
        return;
      }

      final score = widget.idFace == null
          ? null
          : _FaceVerificationService.qualitySimilarity(
              widget.idFace!.boundingBox,
              faces.single.boundingBox,
            );

      setState(() {
        _processing = false;
        _score = score;
        _status = score == null
            ? 'Face detected. Manual review can continue while secure matching is prepared.'
            : 'One face detected. Ready for secure identity matching.';
      });
    } on MissingPluginException {
      _showMessage(
        'Face detection is available in the Android/iOS build. Please reinstall the latest APK.',
      );
    } on PlatformException {
      _showMessage(
        'Face detection was unavailable for this selfie. Please try again in good lighting or continue with manual review.',
      );
    } catch (error) {
      _showMessage(
        'Face detection was unavailable for this selfie. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() => _processing = false);
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message), backgroundColor: navy));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFEAF4F0),
    appBar: AppBar(
      backgroundColor: Colors.white.withValues(alpha: .36),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back, color: navy),
      ),
    ),
    body: AppScroll(
      paddingTop: 10,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SignupProgress(activeStep: 3),
          const SizedBox(height: 20),
          const _StepIcon(icon: Icons.face_retouching_natural, color: teal),
          const SizedBox(height: 14),
          Text(
            'Verify with a live selfie',
            style: infraHeading(
              color: navy,
              fontSize: 22,
              weight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Turn your head left and then right so the app can confirm the face is live and not a printed image.',
            style: TextStyle(color: inkSoft, fontSize: 12.5, height: 1.5),
          ),
          const SizedBox(height: 12),
          Container(
            height: SelfieVerificationPage.previewHeight,
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 2),
            decoration: BoxDecoration(
              color: deepNavy,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.white.withValues(alpha: .7)),
            ),
            clipBehavior: Clip.antiAlias,
            child:
                _cameraController != null &&
                    _cameraController!.value.isInitialized
                ? Stack(
                    children: [
                      Positioned.fill(child: CameraPreview(_cameraController!)),
                      Center(
                        child: Container(
                          width: 360,
                          height: 460,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(220),
                            border: Border.all(color: Colors.white70, width: 4),
                          ),
                        ),
                      ),
                    ],
                  )
                : _selfie == null
                ? const _FaceFrame()
                : FutureBuilder<Uint8List>(
                    future: _selfie!.readAsBytes(),
                    builder: (context, snapshot) => snapshot.hasData
                        ? Image.memory(snapshot.data!, fit: BoxFit.cover)
                        : const Center(child: CircularProgressIndicator()),
                  ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _score == null
                  ? teal.withValues(alpha: .10)
                  : green.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(
                  _score == null
                      ? Icons.info_outline
                      : Icons.check_circle_outline,
                  color: _score == null ? teal : green,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _status,
                    style: const TextStyle(
                      color: ink,
                      fontSize: 11.5,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_score != null) ...[
            const SizedBox(height: 10),
            Text(
              'Prototype geometry score: ${(_score! * 100).round()}% · final identity matching must be completed securely on a backend.',
              style: const TextStyle(
                color: inkSoft,
                fontSize: 10.5,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 20),
          if (_selfie != null)
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton.icon(
                onPressed: _processing ? null : _startLivenessCheck,
                icon: const Icon(Icons.refresh),
                label: Text(
                  _processing ? 'Checking face…' : 'Retake selfie',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: clay,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class _FaceFrame extends StatelessWidget {
  const _FaceFrame();

  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.center,
    children: [
      Container(
        width: 360,
        height: 460,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(220),
          border: Border.all(color: Colors.white70, width: 4),
        ),
      ),
      const Icon(
        Icons.face_retouching_natural,
        color: Colors.white38,
        size: 82,
      ),
      const Positioned(
        top: 16,
        child: Text(
          'Center your face in the frame',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ],
  );
}

class _StepIcon extends StatelessWidget {
  const _StepIcon({required this.icon, required this.color});
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 46,
    height: 46,
    decoration: BoxDecoration(
      color: color.withValues(alpha: .13),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Icon(icon, color: color, size: 23),
  );
}

class _VerificationNote extends StatelessWidget {
  const _VerificationNote();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: teal.withValues(alpha: .10),
      borderRadius: BorderRadius.circular(14),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.shield_outlined, color: teal, size: 20),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'Your ID is used only to confirm your identity and is never shown publicly on reports or your profile.',
            style: TextStyle(
              color: Color(0xFF0E4F49),
              fontSize: 11.5,
              height: 1.45,
            ),
          ),
        ),
      ],
    ),
  );
}

class _IdUploadBox extends StatelessWidget {
  const _IdUploadBox({
    required this.label,
    required this.sublabel,
    required this.image,
    required this.onTap,
  });
  final String label;
  final String sublabel;
  final XFile? image;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 126,
      decoration: BoxDecoration(
        color: image == null
            ? Colors.white.withValues(alpha: .62)
            : green.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: image == null ? line : green, width: 1.4),
      ),
      clipBehavior: Clip.antiAlias,
      child: image == null
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircleAvatar(
                  radius: 18,
                  backgroundColor: sand,
                  child: Icon(
                    Icons.add_a_photo_outlined,
                    color: inkSoft,
                    size: 18,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  label,
                  style: const TextStyle(
                    color: navy,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sublabel,
                  style: const TextStyle(color: inkSoft, fontSize: 9.5),
                ),
              ],
            )
          : Stack(
              fit: StackFit.expand,
              children: [
                FutureBuilder<Uint8List>(
                  future: image!.readAsBytes(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: Colors.white,
                          size: 28,
                        ),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      );
                    }
                    return Image.memory(snapshot.data!, fit: BoxFit.cover);
                  },
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    color: Colors.black54,
                    child: Text(
                      '$label added',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    ),
  );
}

class _VerificationChecklist extends StatelessWidget {
  const _VerificationChecklist();

  @override
  Widget build(BuildContext context) => const Column(
    children: [
      _ChecklistRow('All four corners of the ID are visible'),
      SizedBox(height: 9),
      _ChecklistRow('Name and photo are clear and unedited'),
      SizedBox(height: 9),
      _ChecklistRow('ID is valid and not expired'),
    ],
  );
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Icon(Icons.check_circle_outline, color: teal, size: 17),
      const SizedBox(width: 9),
      Expanded(
        child: Text(
          text,
          style: const TextStyle(color: ink, fontSize: 11.5, height: 1.35),
        ),
      ),
    ],
  );
}

class _GlassOrb extends StatelessWidget {
  const _GlassOrb({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );
}

class _SignupProgress extends StatelessWidget {
  const _SignupProgress({this.activeStep = 1});
  final int activeStep;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'STEP 1 OF 3 · ACCOUNT',
        style: TextStyle(
          color: teal,
          fontSize: 10.5,
          letterSpacing: 1,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(child: _ProgressSegment(active: activeStep >= 1)),
          const SizedBox(width: 6),
          Expanded(child: _ProgressSegment(active: activeStep >= 2)),
          const SizedBox(width: 6),
          Expanded(child: _ProgressSegment(active: activeStep >= 3)),
        ],
      ),
    ],
  );
}

class _ProgressSegment extends StatelessWidget {
  const _ProgressSegment({this.active = false});
  final bool active;

  @override
  Widget build(BuildContext context) => Container(
    height: 4,
    decoration: BoxDecoration(
      color: active ? teal : line,
      borderRadius: BorderRadius.circular(20),
    ),
  );
}

class _SignupLabel extends StatelessWidget {
  const _SignupLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: inkSoft,
        fontSize: 11,
        letterSpacing: .5,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _SignupIntroIcon extends StatelessWidget {
  const _SignupIntroIcon();

  @override
  Widget build(BuildContext context) => Container(
    width: 38,
    height: 38,
    decoration: BoxDecoration(
      color: teal.withValues(alpha: .14),
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Icon(Icons.groups_outlined, color: teal, size: 21),
  );
}

class _SignupGroupHeading extends StatelessWidget {
  const _SignupGroupHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4, bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: infraMono(color: teal, fontSize: 10, weight: FontWeight.w800),
        ),
        const SizedBox(height: 3),
        Text(subtitle, style: const TextStyle(color: inkSoft, fontSize: 11)),
      ],
    ),
  );
}

class _PasswordRequirements extends StatelessWidget {
  const _PasswordRequirements({
    required this.hasLength,
    required this.hasUppercase,
    required this.hasNumber,
  });

  final bool hasLength;
  final bool hasUppercase;
  final bool hasNumber;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 0, bottom: 14),
    child: Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        _RequirementChip(label: '8+ characters', valid: hasLength),
        _RequirementChip(label: '1 uppercase', valid: hasUppercase),
        _RequirementChip(label: '1 number', valid: hasNumber),
      ],
    ),
  );
}

class _RequirementChip extends StatelessWidget {
  const _RequirementChip({required this.label, required this.valid});

  final String label;
  final bool valid;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: valid ? green.withValues(alpha: .12) : Colors.white54,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: valid ? green.withValues(alpha: .28) : line),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          valid ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 13,
          color: valid ? green : inkSoft,
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            color: valid ? green : inkSoft,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _SignupField extends StatelessWidget {
  const _SignupField({
    required this.label,
    required this.hint,
    required this.icon,
    required this.controller,
    required this.validator,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
    this.onChanged,
  });
  final String label;
  final String hint;
  final IconData icon;
  final TextEditingController controller;
  final FormFieldValidator<String> validator;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SignupLabel(label),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          obscureText: obscureText,
          onChanged: onChanged,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: inkSoft),
            suffixIcon: suffixIcon,
          ),
        ),
      ],
    ),
  );
}
