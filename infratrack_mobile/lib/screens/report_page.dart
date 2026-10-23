part of '../main.dart';

enum _CaptureMode { photo, video }

enum _ReportSubmissionStage {
  locating,
  assessingSeverity,
  uploadingEvidence,
  submitting,
  success,
}

class ReportPage extends StatefulWidget {
  const ReportPage({super.key});
  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  final _imagePicker = ImagePicker();
  final _descriptionController = TextEditingController();
  String category = 'Roads';
  XFile? _capturedMedia;
  bool _capturedVideo = false;
  Position? _position;
  bool _locating = false;
  String? _locationError;
  String _verification =
      ApiService.currentUser?['verification']?.toString() ?? 'Not submitted';
  bool _verificationLoading = true;
  bool _checkingVerification = false;
  String? _verificationError;
  bool _submitting = false;

  bool get _isVerified => _verification.toLowerCase() == 'verified';

  Future<void> refresh() => _refreshAccess();

  @override
  void initState() {
    super.initState();
    _refreshAccess();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    if (!_isVerified || _verificationLoading || _submitting) return;
    if (_descriptionController.text.trim().isEmpty) {
      showInfraNotice(
        context,
        'Please add a description first.',
        kind: InfraNoticeKind.warning,
      );
      return;
    }

    setState(() => _submitting = true);
    final stage = ValueNotifier(_ReportSubmissionStage.locating);
    final dialogResult = showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ReportSubmissionDialog(
        stage: stage,
        hasEvidence: _capturedMedia != null,
      ),
    );
    var aiAssessmentUnavailable = false;
    try {
      if (_position == null) {
        stage.value = _ReportSubmissionStage.locating;
        await _refreshLocation();
        if (_position == null) {
          throw Exception(
            _locationError ?? 'Please enable location before submitting.',
          );
        }
      }

      String? aiSeverity;
      String? aiAnalysis;
      stage.value = _ReportSubmissionStage.assessingSeverity;
      try {
        final assessment = await ApiService.assessReportSeverity(
          description: _descriptionController.text.trim(),
          category: category,
          evidence: _capturedMedia == null ? null : File(_capturedMedia!.path),
          isVideo: _capturedVideo,
        );
        aiSeverity = assessment.severity;
        aiAnalysis = assessment.analysis;
      } catch (error) {
        debugPrint('Report AI assessment unavailable: $error');
        aiAssessmentUnavailable = true;
      }

      final mediaUrl = _capturedMedia == null
          ? null
          : await _uploadEvidence(stage);
      stage.value = _ReportSubmissionStage.submitting;
      await ApiService.createReport(
        title: '$category issue reported by resident',
        description: _descriptionController.text.trim(),
        category: category,
        location: 'Mati City',
        severity: 'Medium',
        aiSeverity: aiSeverity,
        aiAnalysis: aiAnalysis,
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
      stage.value = _ReportSubmissionStage.success;
      final openReports = await dialogResult;
      if (!mounted) return;
      if (openReports == true) {
        await Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const MyReportsPage()));
      }
      if (mounted && aiAssessmentUnavailable) {
        showInfraNotice(
          context,
          'AI analysis was unavailable. The admin can still review your report and set its priority.',
          kind: InfraNoticeKind.warning,
        );
      }
    } catch (error) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (mounted) {
        if (error is ApiException && error.code == 'REPORTING_SUSPENDED') {
          setState(() {});
          return;
        }
        if (error is ApiException && error.code == 'ACCOUNT_NOT_VERIFIED') {
          setState(() {
            _verification =
                ApiService.currentUser?['verification']?.toString() ??
                'Not submitted';
          });
          return;
        }
        if (error is ApiException && error.code == 'ACCOUNT_BANNED') return;
        showInfraNotice(
          context,
          error.toString().replaceFirst('Exception: ', ''),
          kind: InfraNoticeKind.error,
        );
      }
    } finally {
      stage.dispose();
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<String> _uploadEvidence(
    ValueNotifier<_ReportSubmissionStage> stage,
  ) async {
    stage.value = _ReportSubmissionStage.uploadingEvidence;
    return ApiService.uploadMedia(
      File(_capturedMedia!.path),
      isVideo: _capturedVideo,
    );
  }

  Future<void> _refreshAccess() async {
    if (_checkingVerification) return;
    _checkingVerification = true;
    setState(() {
      _verificationLoading = true;
      _verificationError = null;
    });
    try {
      final profile = await ApiService.profile();
      if (!mounted) return;
      setState(() {
        _verification = profile['verification']?.toString() ?? 'Not submitted';
      });
      if (_isVerified) await _refreshLocation();
    } catch (error) {
      if (mounted) {
        setState(
          () => _verificationError = error.toString().replaceFirst(
            'Exception: ',
            '',
          ),
        );
      }
    } finally {
      _checkingVerification = false;
      if (mounted) setState(() => _verificationLoading = false);
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
        ? await _imagePicker.pickVideo(
            source: ImageSource.camera,
            maxDuration: const Duration(seconds: 15),
          )
        : await _imagePicker.pickImage(
            source: ImageSource.camera,
            imageQuality: 70,
            maxWidth: 768,
            maxHeight: 768,
          );
    if (!mounted || media == null) return;
    setState(() {
      _capturedMedia = media;
      _capturedVideo = mode == _CaptureMode.video;
    });
  }

  Object? get _suspendedUntil => ApiService.currentUser?['suspended_until'];

  bool get _isReportingSuspended {
    if (ApiService.currentUser?['standing']?.toString() != 'Suspended') {
      return false;
    }
    final end = DateTime.tryParse(_suspendedUntil?.toString() ?? '')?.toLocal();
    return end == null || end.isAfter(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    if (_isReportingSuspended) {
      return PageEntrance(
        child: AppScroll(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppHeader(
                eyebrow: 'NEW SUBMISSION',
                title: 'Report an issue',
              ),
              const SizedBox(height: 12),
              _ReportingSuspendedNotice(suspendedUntil: _suspendedUntil),
            ],
          ),
        ),
      );
    }
    if (_verificationLoading || !_isVerified || _verificationError != null) {
      return PageEntrance(
        child: LayoutBuilder(
          builder: (context, constraints) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: AppHeader(
                  eyebrow: 'NEW SUBMISSION',
                  title: 'Report an issue',
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, contentConstraints) {
                    final minimumHeight = (contentConstraints.maxHeight - 40)
                        .clamp(0.0, double.infinity)
                        .toDouble();
                    return SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 20,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: minimumHeight),
                        child: Center(
                          key: const ValueKey('verificationNoticeCenter'),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 420),
                            child: _ReportVerificationNotice(
                              verification: _verification,
                              loading: _verificationLoading,
                              error: _verificationError,
                              onRetry: _refreshAccess,
                              onVerify: () async {
                                await Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        const IdentityVerificationPage(),
                                  ),
                                );
                                if (mounted) await _refreshAccess();
                              },
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    }
    return PageEntrance(
      child: AppScroll(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppHeader(
              eyebrow: 'NEW SUBMISSION',
              title: 'Report an issue',
              subtitle:
                  'Help improve Mati City by sharing a clear, accurate report.',
            ),
            const _ReportIntroCard(),
            const SizedBox(height: 20),
            const _ReportSectionHeading(
              step: '01',
              title: 'Add evidence',
              detail: 'Optional, but a photo helps the team assess the issue.',
            ),
            Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: line),
              ),
              child: InkWell(
                onTap: _isReportingSuspended || _submitting
                    ? null
                    : _openCamera,
                borderRadius: BorderRadius.circular(20),
                child: _capturedMedia == null
                    ? SizedBox(
                        height: 148,
                        width: double.infinity,
                        child: _AddMediaPlaceholder(),
                      )
                    : _CapturedMediaPreview(
                        file: _capturedMedia!,
                        isVideo: _capturedVideo,
                      ),
              ),
            ),
            const SizedBox(height: 22),
            const _ReportSectionHeading(
              step: '02',
              title: 'Choose a category',
              detail: 'Pick the type that best describes the issue.',
            ),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 9,
              crossAxisSpacing: 9,
              childAspectRatio: 2.55,
              children: [
                _CategoryButton(
                  label: 'Roads',
                  icon: Icons.add_road_rounded,
                  color: clay,
                  selected: category == 'Roads',
                  onTap: _submitting
                      ? null
                      : () => setState(() => category = 'Roads'),
                ),
                _CategoryButton(
                  label: 'Public Buildings',
                  icon: Icons.apartment_rounded,
                  color: teal,
                  selected: category == 'Public Buildings',
                  onTap: _submitting
                      ? null
                      : () => setState(() => category = 'Public Buildings'),
                ),
                _CategoryButton(
                  label: 'Drainage',
                  icon: Icons.water_damage_outlined,
                  color: amber,
                  selected: category == 'Drainage',
                  onTap: _submitting
                      ? null
                      : () => setState(() => category = 'Drainage'),
                ),
                _CategoryButton(
                  label: 'Streetlights',
                  icon: Icons.lightbulb_outline_rounded,
                  color: navy,
                  selected: category == 'Streetlights',
                  onTap: _submitting
                      ? null
                      : () => setState(() => category = 'Streetlights'),
                ),
                _CategoryButton(
                  label: 'Electric Poles',
                  icon: Icons.electric_bolt_rounded,
                  color: amber,
                  selected: category == 'Electric Poles',
                  onTap: _submitting
                      ? null
                      : () => setState(() => category = 'Electric Poles'),
                ),
              ],
            ),
            const SizedBox(height: 22),
            const _ReportSectionHeading(
              step: '03',
              title: 'Confirm the location',
              detail: 'Your current location helps crews find the issue.',
            ),
            _CoordinatesCard(
              position: _position,
              loading: _locating,
              error: _locationError,
              onRefresh: _submitting ? null : _refreshLocation,
            ),
            const SizedBox(height: 22),
            const _ReportSectionHeading(
              step: '04',
              title: 'Describe the issue',
              detail:
                  'Include what happened and a nearby landmark if possible.',
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: line),
              ),
              child: TextField(
                controller: _descriptionController,
                readOnly: _submitting,
                maxLines: 5,
                minLines: 4,
                maxLength: 1000,
                decoration: InputDecoration(
                  hintText: 'What needs attention? Add details such as the condition, size, or a nearby landmark.',
                  filled: true,
                  fillColor: Colors.transparent,
                  contentPadding: const EdgeInsets.all(16),
                  hintStyle: const TextStyle(
                    color: inkSoft,
                    fontSize: 12,
                    height: 1.45,
                  ),
                  counterStyle: const TextStyle(color: inkSoft, fontSize: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const _ReportSectionHeading(
              step: '05',
              title: 'AI assessment',
              detail:
                  'An admin reviews the findings and sets the report priority.',
            ),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: line),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.auto_awesome_outlined, size: 18, color: teal),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'When you submit, AI reviews your description and attached image or a frame from your video. Its findings are saved with your report for the admin to review; AI does not set the priority.',
                      style: TextStyle(
                        color: inkSoft,
                        fontSize: 11,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'AI uses your report text and selected evidence for one short analysis. Videos are reduced to one frame before analysis.',
              style: TextStyle(color: inkSoft, fontSize: 10, height: 1.4),
            ),
            const SizedBox(height: 12),
            const _ReportPrivacyNote(),
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
                onPressed: _isReportingSuspended || _submitting
                    ? null
                    : _submitReport,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _submitting
                          ? Icons.hourglass_top_rounded
                          : Icons.send_rounded,
                      size: 18,
                    ),
                    const SizedBox(width: 9),
                    Text(_submitting ? 'Submitting report…' : 'Submit report'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'Please submit accurate, respectful reports.',
                style: TextStyle(color: inkSoft, fontSize: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportIntroCard extends StatelessWidget {
  const _ReportIntroCard();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [deepNavy, navy, Color(0xFF155B66)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: navy.withValues(alpha: .13),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: Row(
      children: [
        Container(
          width: 43,
          height: 43,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .13),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.campaign_outlined,
            color: Color(0xFF9FE1D7),
            size: 23,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'Your report helps the right city team understand what needs attention.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

class _ReportSectionHeading extends StatelessWidget {
  const _ReportSectionHeading({
    required this.step,
    required this.title,
    required this.detail,
  });

  final String step;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 27,
          height: 27,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: teal.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            step,
            style: const TextStyle(
              color: teal,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 10),
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
              const SizedBox(height: 2),
              Text(
                detail,
                style: const TextStyle(
                  color: inkSoft,
                  fontSize: 10.5,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ReportPrivacyNote extends StatelessWidget {
  const _ReportPrivacyNote();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: teal.withValues(alpha: .07),
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: teal.withValues(alpha: .13)),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.shield_outlined, color: teal, size: 17),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            'Your location is shared with the city team only to help assess this report.',
            style: TextStyle(color: navy, fontSize: 10.5, height: 1.4),
          ),
        ),
      ],
    ),
  );
}

class _ReportSubmissionDialog extends StatelessWidget {
  const _ReportSubmissionDialog({
    required this.stage,
    required this.hasEvidence,
  });

  final ValueNotifier<_ReportSubmissionStage> stage;
  final bool hasEvidence;

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<_ReportSubmissionStage>(
        valueListenable: stage,
        builder: (context, currentStage, _) {
          final success = currentStage == _ReportSubmissionStage.success;
          return PopScope(
            canPop: success,
            child: Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 26),
              child: Container(
                padding: const EdgeInsets.fromLTRB(22, 23, 22, 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: deepNavy.withValues(alpha: .18),
                      blurRadius: 28,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: success
                    ? _ReportSubmissionSuccess(
                        onDone: () => Navigator.of(context).pop(false),
                        onViewReports: () => Navigator.of(context).pop(true),
                      )
                    : _ReportSubmissionProgress(
                        stage: currentStage,
                        hasEvidence: hasEvidence,
                      ),
              ),
            ),
          );
        },
      );
}

class _ReportSubmissionProgress extends StatelessWidget {
  const _ReportSubmissionProgress({
    required this.stage,
    required this.hasEvidence,
  });

  final _ReportSubmissionStage stage;
  final bool hasEvidence;

  @override
  Widget build(BuildContext context) {
    final assessing = stage == _ReportSubmissionStage.assessingSeverity;
    final uploading = stage == _ReportSubmissionStage.uploadingEvidence;
    final locating = stage == _ReportSubmissionStage.locating;
    final title = locating
        ? 'Confirming report location'
        : assessing
        ? 'Assessing report severity'
        : uploading
        ? 'Uploading your evidence'
        : 'Submitting your report';
    final detail = locating
        ? 'Getting the latest location so the team can find the issue.'
        : assessing
        ? 'Making one short AI request using the report details and evidence.'
        : uploading
        ? 'Your photo or video is being securely uploaded.'
        : 'Sending your report to the city team. Please keep this screen open.';
    final activeStep = locating
        ? 0
        : assessing
        ? 1
        : uploading
        ? 2
        : hasEvidence
        ? 3
        : 2;
    const evidenceStep = 2;
    final submitStep = hasEvidence ? 3 : 2;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: teal.withValues(alpha: .10),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: SizedBox(
              width: 29,
              height: 29,
              child: CircularProgressIndicator(strokeWidth: 3, color: teal),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          title,
          textAlign: TextAlign.center,
          style: infraHeading(
            color: navy,
            fontSize: 18,
            weight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          detail,
          textAlign: TextAlign.center,
          style: const TextStyle(color: inkSoft, fontSize: 12, height: 1.45),
        ),
        const SizedBox(height: 20),
        _SubmissionStep(
          label: 'Confirm location',
          state: activeStep > 0
              ? _SubmissionStepState.complete
              : activeStep == 0
              ? _SubmissionStepState.active
              : _SubmissionStepState.waiting,
        ),
        const SizedBox(height: 10),
        _SubmissionStep(
          label: 'Analyze report',
          state: activeStep > 1
              ? _SubmissionStepState.complete
              : activeStep == 1
              ? _SubmissionStepState.active
              : _SubmissionStepState.waiting,
        ),
        const SizedBox(height: 10),
        if (hasEvidence) ...[
          _SubmissionStep(
            label: 'Upload evidence',
            state: activeStep > evidenceStep
                ? _SubmissionStepState.complete
                : activeStep == evidenceStep
                ? _SubmissionStepState.active
                : _SubmissionStepState.waiting,
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 10),
        _SubmissionStep(
          label: 'Send report',
          state: activeStep == submitStep
              ? _SubmissionStepState.active
              : activeStep > submitStep
              ? _SubmissionStepState.complete
              : _SubmissionStepState.waiting,
        ),
        const SizedBox(height: 17),
        const LinearProgressIndicator(
          minHeight: 3,
          borderRadius: BorderRadius.all(Radius.circular(3)),
          color: teal,
          backgroundColor: Color(0xFFE7EFEC),
        ),
        const SizedBox(height: 9),
        const Text(
          'This may take a moment on a slow connection.',
          textAlign: TextAlign.center,
          style: TextStyle(color: inkSoft, fontSize: 10),
        ),
      ],
    );
  }
}

enum _SubmissionStepState { waiting, active, complete }

class _SubmissionStep extends StatelessWidget {
  const _SubmissionStep({required this.label, required this.state});

  final String label;
  final _SubmissionStepState state;

  @override
  Widget build(BuildContext context) {
    final complete = state == _SubmissionStepState.complete;
    final active = state == _SubmissionStepState.active;
    final color = complete
        ? green
        : active
        ? teal
        : inkSoft.withValues(alpha: .55);
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .11),
            shape: BoxShape.circle,
          ),
          child: Icon(
            complete
                ? Icons.check_rounded
                : active
                ? Icons.more_horiz
                : Icons.circle,
            color: color,
            size: complete
                ? 15
                : active
                ? 16
                : 7,
          ),
        ),
        const SizedBox(width: 9),
        Text(
          label,
          style: TextStyle(
            color: state == _SubmissionStepState.waiting ? inkSoft : navy,
            fontSize: 11,
            fontWeight: active || complete ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        const Spacer(),
        if (active)
          const Text(
            'IN PROGRESS',
            style: TextStyle(
              color: teal,
              fontSize: 8,
              fontWeight: FontWeight.w800,
              letterSpacing: .5,
            ),
          ),
        if (complete)
          const Text(
            'DONE',
            style: TextStyle(
              color: green,
              fontSize: 8,
              fontWeight: FontWeight.w800,
              letterSpacing: .5,
            ),
          ),
      ],
    );
  }
}

class _ReportSubmissionSuccess extends StatelessWidget {
  const _ReportSubmissionSuccess({
    required this.onDone,
    required this.onViewReports,
  });

  final VoidCallback onDone;
  final VoidCallback onViewReports;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 68,
        height: 68,
        decoration: BoxDecoration(
          color: green.withValues(alpha: .11),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check_rounded, color: green, size: 36),
      ),
      const SizedBox(height: 17),
      Text(
        'Report submitted',
        style: infraHeading(color: navy, fontSize: 20, weight: FontWeight.w800),
      ),
      const SizedBox(height: 7),
      const Text(
        'Your report is now with the city team. You can follow its progress in My Reports.',
        textAlign: TextAlign.center,
        style: TextStyle(color: inkSoft, fontSize: 12, height: 1.5),
      ),
      const SizedBox(height: 20),
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: onViewReports,
          icon: const Icon(Icons.description_outlined, size: 18),
          label: const Text('View my reports'),
          style: FilledButton.styleFrom(
            backgroundColor: navy,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
      TextButton(onPressed: onDone, child: const Text('Done')),
    ],
  );
}

class _ReportVerificationNotice extends StatelessWidget {
  const _ReportVerificationNotice({
    required this.verification,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.onVerify,
  });

  final String verification;
  final bool loading;
  final String? error;
  final Future<void> Function() onRetry;
  final Future<void> Function() onVerify;

  @override
  Widget build(BuildContext context) {
    final status = verification.toLowerCase();
    final pending = status.contains('pending');
    final rejected = status.contains('mismatch') || status.contains('rejected');
    final accent = error != null || rejected
        ? clay
        : pending
        ? amber
        : teal;
    final heading = loading
        ? 'Checking your account'
        : error != null
        ? 'We couldn’t confirm your status'
        : pending
        ? 'Your verification is in review'
        : rejected
        ? 'Your verification needs an update'
        : 'Verify your account to report';
    final description = loading
        ? 'We’re securely checking your verification status before opening the report form.'
        : error != null
        ? 'Reporting stays locked until we can confirm your account. Check your connection and try again.'
        : pending
        ? 'Your ID and selfie are being reviewed. You can submit a report as soon as your account is approved.'
        : rejected
        ? 'Your previous verification was not approved. Review your identity status and submit clear documents to continue.'
        : 'To help keep community reports trustworthy, complete identity verification before submitting an issue.';
    final statusLabel = loading
        ? 'CHECKING'
        : error != null
        ? 'STATUS UNAVAILABLE'
        : pending
        ? 'PENDING REVIEW'
        : rejected
        ? 'ACTION NEEDED'
        : 'NOT VERIFIED';
    final actionLabel = pending
        ? 'View verification status'
        : rejected
        ? 'Update verification'
        : 'Verify identity';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accent.withValues(alpha: .10),
            border: Border.all(color: accent.withValues(alpha: .17)),
          ),
          child: Center(
            child: Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: .82),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: .10),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: loading
                  ? Padding(
                      padding: const EdgeInsets.all(21),
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: accent,
                      ),
                    )
                  : Icon(
                      pending
                          ? Icons.hourglass_top_rounded
                          : rejected
                          ? Icons.fact_check_outlined
                          : error != null
                          ? Icons.cloud_off_outlined
                          : Icons.verified_user_outlined,
                      color: accent,
                      size: 32,
                    ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Text(
            statusLabel,
            style: TextStyle(
              color: accent,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: .8,
            ),
          ),
        ),
        const SizedBox(height: 13),
        Text(
          'REPORTING ACCESS',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: teal,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          heading,
          textAlign: TextAlign.center,
          style: infraHeading(
            color: navy,
            fontSize: 22,
            weight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 9),
        Text(
          description,
          textAlign: TextAlign.center,
          style: const TextStyle(color: inkSoft, fontSize: 13, height: 1.5),
        ),
        if (error != null) ...[
          const SizedBox(height: 11),
          Text(
            error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: clay, fontSize: 11, height: 1.4),
          ),
        ],
        const SizedBox(height: 17),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.lock_outline_rounded, color: teal, size: 16),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Your verification documents stay private and never appear on your public reports.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: navy.withValues(alpha: .82),
                  fontSize: 10,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 19),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: loading ? null : onVerify,
            icon: const Icon(Icons.verified_user_outlined, size: 18),
            label: Text(actionLabel),
            style: FilledButton.styleFrom(
              backgroundColor: clay,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          ),
        ),
        const SizedBox(height: 5),
        TextButton.icon(
          onPressed: loading ? null : onRetry,
          icon: const Icon(Icons.refresh_rounded, size: 17),
          label: const Text('Refresh verification status'),
          style: TextButton.styleFrom(
            foregroundColor: navy,
            padding: const EdgeInsets.symmetric(vertical: 10),
          ),
        ),
      ],
    );
  }
}

class _ReportingSuspendedNotice extends StatelessWidget {
  const _ReportingSuspendedNotice({this.suspendedUntil});

  final Object? suspendedUntil;

  @override
  Widget build(BuildContext context) {
    final end = DateTime.tryParse(suspendedUntil?.toString() ?? '')?.toLocal();
    final endLabel = end == null
        ? 'until an administrator restores access'
        : 'until ${MaterialLocalizations.of(context).formatMediumDate(end)} at ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(end))}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .82),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE7CDAF)),
        boxShadow: [
          BoxShadow(
            color: deepNavy.withValues(alpha: .06),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: clay.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.hourglass_top_rounded,
                  color: clay,
                  size: 23,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reporting suspended',
                      style: infraHeading(
                        color: navy,
                        fontSize: 16,
                        weight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'You can still browse reports, updates, and your account.',
                      style: TextStyle(
                        color: inkSoft,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
            decoration: BoxDecoration(
              color: sand,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Row(
              children: [
                const Icon(Icons.schedule_rounded, color: teal, size: 17),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Report access resumes $endLabel.',
                    style: const TextStyle(
                      color: navy,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
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
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: line),
    ),
    child: LayoutBuilder(
      builder: (context, _) {
        final coordinateText = position == null
            ? error == null
                  ? 'Waiting for location'
                  : 'Location unavailable'
            : '${position!.latitude.toStringAsFixed(5)}° N, '
                  '${position!.longitude.toStringAsFixed(5)}° E';
        final details = Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: (position == null ? amber : teal).withValues(alpha: .11),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                position == null
                    ? Icons.location_searching_rounded
                    : Icons.my_location_rounded,
                color: position == null ? amber : teal,
                size: 20,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    position == null ? 'Location status' : 'Current location',
                    style: const TextStyle(
                      color: navy,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    coordinateText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: inkSoft,
                      fontFamily: 'monospace',
                      fontSize: 10,
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      error!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: clay, fontSize: 9.5),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
        final refresh = IconButton(
          tooltip: position == null
              ? 'Get current location'
              : 'Refresh location',
          onPressed: loading ? null : onRefresh,
          style: IconButton.styleFrom(
            backgroundColor: sand,
            foregroundColor: navy,
            minimumSize: const Size(42, 42),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: loading
              ? const SizedBox(
                  width: 17,
                  height: 17,
                  child: CircularProgressIndicator(strokeWidth: 2, color: teal),
                )
              : const Icon(Icons.refresh_rounded, size: 20),
        );

        return Row(
          children: [
            Expanded(child: details),
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
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? color.withValues(alpha: .09) : Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(
        color: selected ? color.withValues(alpha: .7) : line,
        width: selected ? 1.5 : 1,
      ),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: selected
                    ? color.withValues(alpha: .15)
                    : sand.withValues(alpha: .75),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: color, size: 19),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: navy,
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded, color: color, size: 17),
          ],
        ),
      ),
    ),
  );
}
