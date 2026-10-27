import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:camera/camera.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

import 'api_service.dart';
import 'appearance_preferences.dart';
import 'biometric_sign_in.dart';
import 'push_notifications.dart';
import 'report_categories.dart';

part 'loading_skeleton.dart';
part 'screens/home_page.dart';
part 'screens/map_page.dart';
part 'screens/report_page.dart';
part 'screens/news_page.dart';
part 'screens/profile_page.dart';
part 'screens/my_reports_page.dart';
part 'screens/notifications_page.dart';
part 'screens/chatbot_page.dart';
part 'screens/create_account_page.dart';

const _mobileDesignPreview = bool.fromEnvironment('MOBILE_DESIGN_PREVIEW');

const navy = Color(0xFF0E3A4C);
const deepNavy = Color(0xFF092732);
const teal = Color(0xFF1B8A83);
const clay = Color(0xFFC1592B);
const brandOrange = Color(0xFFF06423);
const sand = Colors.white;
const ink = Color(0xFF17231F);
const inkSoft = Color(0xFF5B6B67);
const line = Color(0xFFE0E5E7);
const amber = Color(0xFFD99A2B);
const green = Color(0xFF3C8A5F);
const red = Color(0xFFB33A3A);

Color infraMutedTextColor(BuildContext context) =>
    Theme.of(context).inputDecorationTheme.hintStyle?.color ?? inkSoft;

class AppGuidePreferences {
  static const _completedKey = 'infratrack_app_guide_completed';

  static Future<bool> shouldShowFirstLaunchGuide() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_completedKey) != true;
  }

  static Future<void> markGuideCompleted() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_completedKey, true);
  }
}

TextStyle infraHeading({double? fontSize, Color? color, FontWeight? weight}) =>
    appearanceFontStyle(
      infraAppearance.value.typeface,
      TextStyle(
        fontSize: fontSize,
        color: color,
        fontWeight: weight ?? FontWeight.w700,
      ),
    );

TextStyle infraMono({double? fontSize, Color? color, FontWeight? weight}) =>
    GoogleFonts.ibmPlexMono(
      fontSize: fontSize,
      color: color,
      fontWeight: weight,
    );

enum InfraNoticeKind { success, error, warning, info }

void showInfraNotice(
  BuildContext context,
  String message, {
  InfraNoticeKind kind = InfraNoticeKind.info,
  Duration? duration,
}) {
  final messenger = ScaffoldMessenger.of(context);
  late final Color accent;
  late final IconData icon;
  switch (kind) {
    case InfraNoticeKind.success:
      accent = const Color(0xFF66D2A5);
      icon = Icons.check_circle_outline_rounded;
      break;
    case InfraNoticeKind.error:
      accent = const Color(0xFFFF8B80);
      icon = Icons.error_outline_rounded;
      break;
    case InfraNoticeKind.warning:
      accent = const Color(0xFFFFCA72);
      icon = Icons.warning_amber_rounded;
      break;
    case InfraNoticeKind.info:
      accent = const Color(0xFF75D5CF);
      icon = Icons.info_outline_rounded;
      break;
  }

  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.transparent,
      elevation: 0,
      padding: EdgeInsets.zero,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      duration: duration ?? const Duration(seconds: 4),
      content: Container(
        constraints: const BoxConstraints(minHeight: 68),
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        decoration: BoxDecoration(
          color: deepNavy,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          boxShadow: [
            BoxShadow(
              color: deepNavy.withValues(alpha: 0.22),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            ExcludeSemantics(
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accent, size: 21),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            IconButton(
              onPressed: messenger.hideCurrentSnackBar,
              tooltip: 'Dismiss notification',
              visualDensity: VisualDensity.compact,
              icon: Icon(
                Icons.close_rounded,
                color: Colors.white.withValues(alpha: 0.68),
                size: 19,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

void main() => runApp(const InfraTrackApp());

class InfraTrackApp extends StatefulWidget {
  const InfraTrackApp({super.key});

  @override
  State<InfraTrackApp> createState() => _InfraTrackAppState();
}

class _InfraTrackAppState extends State<InfraTrackApp> {
  @override
  void initState() {
    super.initState();
    unawaited(loadInfraAppearance());
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<InfraAppearance>(
    valueListenable: infraAppearance,
    builder: (context, appearance, _) {
      final textScale = switch (appearance.textSize) {
        'compact' => .9,
        'large' => 1.12,
        _ => 1.0,
      };
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'InfraTrack',
        theme: buildInfraTheme(appearance, Brightness.light),
        darkTheme: buildInfraTheme(appearance, Brightness.dark),
        themeMode: switch (appearance.theme) {
          'dark' => ThemeMode.dark,
          'system' => ThemeMode.system,
          _ => ThemeMode.light,
        },
        builder: (context, child) {
          final brightness = Theme.of(context).brightness;
          final systemBarBackground = Theme.of(context).scaffoldBackgroundColor;
          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle(
              statusBarColor: systemBarBackground,
              statusBarIconBrightness: brightness == Brightness.dark
                  ? Brightness.light
                  : Brightness.dark,
              statusBarBrightness: brightness,
            ),
            child: ColoredBox(
              color: systemBarBackground,
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(
                    MediaQuery.textScalerOf(context).scale(1) * textScale,
                  ),
                ),
                child: ValueListenableBuilder<String?>(
                  valueListenable: ApiService.connectionIssue,
                  builder: (context, issue, _) => Stack(
                    fit: StackFit.expand,
                    children: [
                      ?child,
                      if (issue != null && !_mobileDesignPreview)
                        _ConnectionUnavailablePage(
                          message: issue,
                          onRetry: ApiService.checkServerConnection,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
        home: const AppLoadingPage(),
      );
    },
  );
}

class _ConnectionUnavailablePage extends StatefulWidget {
  const _ConnectionUnavailablePage({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  State<_ConnectionUnavailablePage> createState() =>
      _ConnectionUnavailablePageState();
}

class _ConnectionUnavailablePageState extends State<_ConnectionUnavailablePage>
    with WidgetsBindingObserver {
  bool _checking = false;
  bool _isForeground = true;
  Timer? _retryTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _retryTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (_isForeground) _retry();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isForeground = state == AppLifecycleState.resumed;
    if (_isForeground) _retry();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _retryTimer?.cancel();
    super.dispose();
  }

  Future<void> _retry() async {
    if (_checking) return;
    setState(() => _checking = true);
    try {
      await widget.onRetry();
    } on Exception {
      // The API service keeps the connection message visible when retry fails.
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/chatbot_character/chatbot_face/profile.png',
                width: 190,
                height: 190,
                fit: BoxFit.contain,
                semanticLabel: 'InfraTrack mascot',
              ),
              const SizedBox(height: 18),
              Text(
                'We can’t reach InfraTrack',
                textAlign: TextAlign.center,
                style: infraHeading(
                  color: navy,
                  fontSize: 23,
                  weight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                widget.message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: inkSoft,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              TextButton.icon(
                onPressed: _checking ? null : _retry,
                icon: _checking
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: teal,
                        ),
                      )
                    : const Icon(Icons.refresh_rounded),
                label: Text(_checking ? 'Checking connection…' : 'Try again'),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.primary,
                  textStyle: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class AppLoadingPage extends StatefulWidget {
  const AppLoadingPage({super.key});

  @override
  State<AppLoadingPage> createState() => _AppLoadingPageState();
}

class _AppLoadingPageState extends State<AppLoadingPage> {
  static const _minimumDisplayDuration = Duration(seconds: 3);

  bool _sessionReady = false;
  late final Stopwatch _startupTimer = Stopwatch()..start();

  @override
  void initState() {
    super.initState();
    unawaited(_restoreSession());
  }

  Future<void> _restoreSession() async {
    await ApiService.restoreSession();
    final remaining = _minimumDisplayDuration - _startupTimer.elapsed;
    if (remaining > Duration.zero) await Future<void>.delayed(remaining);
    if (!mounted) return;
    setState(() => _sessionReady = true);
    _navigateWhenReady();
  }

  void _navigateWhenReady() {
    if (!_sessionReady || !mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) {
          final notice = ApiService.consumeSessionNotice();
          return ApiService.isSignedIn
              ? const MainShell()
              : LoginPage(sessionNotice: notice);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: deepNavy,
    body: SafeArea(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage(
              'assets/chatbot_character/thinking_animation/loading_background.png',
            ),
            fit: BoxFit.cover,
          ),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x16092732), Color(0x24092732), Color(0xB3092732)],
            stops: [0, .55, 1],
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 32,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/chatbot_character/thinking_animation/trako_loading.png',
                        key: const ValueKey('startup-trako-mascot'),
                        width: 250,
                        height: 310,
                        fit: BoxFit.contain,
                        semanticLabel: 'Trako loading',
                      ),
                      const SizedBox(height: 8),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'Infra',
                              style: infraHeading(
                                color: Colors.white,
                                fontSize: 30,
                                weight: FontWeight.w800,
                              ),
                            ),
                            TextSpan(
                              text: 'Track',
                              style: infraHeading(
                                color: brandOrange,
                                fontSize: 30,
                                weight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'MATI CITY · DAVAO ORIENTAL',
                        style: TextStyle(
                          color: Color(0xFFD0E3E8),
                          fontSize: 10,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 30),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          _sessionReady
                              ? 'Opening your community dashboard…'
                              : 'Restoring your session…',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFFE0ECEF),
                            fontSize: 13,
                            letterSpacing: .1,
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
  );
}

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: deepNavy,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 650;
            final actions = _SplashActions(
              onCreateAccount: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CreateAccountPage()),
              ),
              onLogin: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const LoginPage())),
              onTourist: () => _openHome(context),
            );

            if (compact) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 28, 28, 28),
                child: Column(
                  children: [
                    Transform.translate(
                      offset: const Offset(0, 50),
                      child: _SplashArt(compact: true),
                    ),
                    const SizedBox(height: 28),
                    actions,
                  ],
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: Transform.translate(
                        offset: const Offset(0, 150),
                        child: _SplashArt(compact: false),
                      ),
                    ),
                  ),
                  actions,
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _openHome(BuildContext context) {
    Navigator.of(context)
        .pushReplacement(MaterialPageRoute(builder: (_) => const MainShell()));
  }
}

class PasswordResetPage extends StatefulWidget {
  const PasswordResetPage({super.key, this.initialEmail = ''});

  final String initialEmail;

  @override
  State<PasswordResetPage> createState() => _PasswordResetPageState();
}

class _PasswordResetPageState extends State<PasswordResetPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  Timer? _resendTimer;
  bool _codeRequested = false;
  bool _resetComplete = false;
  bool _isBusy = false;
  int _resendSeconds = 0;
  String? _errorMessage;
  String? _infoMessage;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Enter your email address.';
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  Future<void> _requestCode() async {
    if (_isBusy || !_formKey.currentState!.validate()) return;
    setState(() {
      _isBusy = true;
      _errorMessage = null;
      _infoMessage = null;
    });
    try {
      await ApiService.requestPasswordReset(_emailController.text);
      if (!mounted) return;
      setState(() {
        _codeRequested = true;
        _isBusy = false;
        _infoMessage = 'If an account matches this email, a 6-digit code will arrive shortly. Check your spam folder too.';
      });
      _resendSeconds = 60;
      _resendTimer?.cancel();
      _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() {
          _resendSeconds--;
          if (_resendSeconds <= 0) timer.cancel();
        });
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isBusy = false;
        _errorMessage = error is ApiException
            ? error.message
            : error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _completeReset() async {
    if (_isBusy || !_formKey.currentState!.validate()) return;
    setState(() {
      _isBusy = true;
      _errorMessage = null;
    });
    try {
      await ApiService.completePasswordReset(
        email: _emailController.text,
        code: _codeController.text,
        newPassword: _passwordController.text,
      );
      if (!mounted) return;
      _resendTimer?.cancel();
      setState(() {
        _isBusy = false;
        _resetComplete = true;
        _infoMessage = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isBusy = false;
        _errorMessage = error is ApiException
            ? error.message
            : error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _changeEmail() {
    _resendTimer?.cancel();
    setState(() {
      _codeRequested = false;
      _resendSeconds = 0;
      _codeController.clear();
      _passwordController.clear();
      _confirmPasswordController.clear();
      _errorMessage = null;
      _infoMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: sand,
    appBar: AppBar(
      backgroundColor: sand,
      foregroundColor: navy,
      elevation: 0,
      title: const Text(
        'Password recovery',
        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
      ),
    ),
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 390),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: deepNavy.withValues(alpha: .08),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3C9),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Icon(
                        _resetComplete
                            ? Icons.check_circle_outline
                            : Icons.lock_reset_outlined,
                        color: navy,
                        size: 25,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      _resetComplete
                          ? 'Password updated'
                          : _codeRequested
                          ? 'Enter your reset code'
                          : 'Forgot your password?',
                      style: infraHeading(
                        color: navy,
                        fontSize: 22,
                        weight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      _resetComplete
                          ? 'Your password has been changed. You can now sign in with the new password.'
                          : _codeRequested
                          ? 'Enter the 6-digit code sent to ${_emailController.text.trim()}, then choose a new password.'
                          : 'We’ll email you a short-lived code so you can securely choose a new password.',
                      style: const TextStyle(
                        color: inkSoft,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                    if (!_resetComplete && !_codeRequested) ...[
                      const SizedBox(height: 24),
                      _LoginField(
                        label: 'Email address',
                        hint: 'Enter your account email',
                        icon: Icons.mail_outline,
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        validator: _validateEmail,
                      ),
                    ],
                    if (!_resetComplete && _codeRequested) ...[
                      const SizedBox(height: 22),
                      _LoginField(
                        label: '6-digit code',
                        hint: 'Enter the code from your email',
                        icon: Icons.password_outlined,
                        controller: _codeController,
                        keyboardType: TextInputType.number,
                        validator: (value) =>
                            value == null ||
                                !RegExp(r'^\d{6}$').hasMatch(value.trim())
                            ? 'Enter the 6-digit code from your email.'
                            : null,
                      ),
                      _LoginField(
                        label: 'New password',
                        hint: 'At least 8 characters',
                        icon: Icons.lock_outline,
                        controller: _passwordController,
                        obscureText: true,
                        validator: (value) => value == null || value.length < 8
                            ? 'Use at least 8 characters.'
                            : value.length > 128
                            ? 'Use no more than 128 characters.'
                            : null,
                      ),
                      _LoginField(
                        label: 'Confirm new password',
                        hint: 'Re-enter your new password',
                        icon: Icons.lock_outline,
                        controller: _confirmPasswordController,
                        obscureText: true,
                        validator: (value) => value != _passwordController.text
                            ? 'The passwords do not match.'
                            : null,
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _isBusy ? null : _changeEmail,
                          child: const Text('Change email'),
                        ),
                      ),
                    ],
                    if (_infoMessage != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        _infoMessage!,
                        style: const TextStyle(
                          color: teal,
                          fontSize: 12,
                          height: 1.45,
                        ),
                      ),
                    ],
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Color(0xFFAE3E36),
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: FilledButton(
                        onPressed: _isBusy
                            ? null
                            : _resetComplete
                            ? () => Navigator.of(context).pop(true)
                            : _codeRequested
                            ? _completeReset
                            : _requestCode,
                        style: FilledButton.styleFrom(
                          backgroundColor: clay,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        child: _isBusy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _resetComplete
                                    ? 'Back to log in'
                                    : _codeRequested
                                    ? 'Reset password'
                                    : 'Send reset code',
                              ),
                      ),
                    ),
                    if (_codeRequested && !_resetComplete) ...[
                      const SizedBox(height: 7),
                      Center(
                        child: TextButton(
                          onPressed: _isBusy || _resendSeconds > 0
                              ? null
                              : _requestCode,
                          child: Text(
                            _resendSeconds > 0
                                ? 'Resend code in $_resendSeconds sec'
                                : 'Resend code',
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.sessionNotice, this.biometricService});

  final String? sessionNotice;
  final BiometricSignInService? biometricService;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  BiometricSignInService get _biometricSignIn =>
      widget.biometricService ?? biometricSignIn;

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoggingIn = false;
  bool _hasBiometricSignIn = false;
  String? _loginError;
  bool _loginErrorIsBan = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadBiometricSignIn());
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadBiometricSignIn() async {
    try {
      final enabled = await _biometricSignIn.isEnabled;
      if (mounted) setState(() => _hasBiometricSignIn = enabled);
    } catch (error) {
      if (mounted) {
        setState(
          () => _loginError =
              'Biometric sign-in could not be loaded: ${error.toString().replaceFirst('Exception: ', '')}',
        );
      }
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoggingIn = true);
    final email = _emailController.text.trim();
    try {
      await ApiService.login(email, _passwordController.text);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoggingIn = false;
        if (error is ApiException && error.code == 'ACCOUNT_BANNED') {
          _loginErrorIsBan = true;
          _loginError = error.message;
        } else {
          _loginErrorIsBan = false;
          _loginError = 'We couldn’t sign you in with those details.';
        }
      });
      return;
    }
    try {
      await _biometricSignIn.disableIfAccountMismatch(email);
    } catch (error) {
      if (mounted) {
        showInfraNotice(
          context,
          'Signed in, but saved biometric credentials could not be cleared: ${error.toString().replaceFirst('Exception: ', '')}',
          kind: InfraNoticeKind.warning,
        );
      }
    }
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainShell()),
      (_) => false,
    );
  }

  Future<void> _loginWithBiometrics() async {
    setState(() {
      _isLoggingIn = true;
      _loginError = null;
      _loginErrorIsBan = false;
    });
    try {
      final credentials = await _biometricSignIn.readCredentials();
      if (credentials == null) {
        throw StateError(
          'Biometric sign-in details are unavailable. Sign in with your password and enable it again.',
        );
      }
      final authenticated = await _biometricSignIn.authenticate(
        'Sign in to InfraTrack',
      );
      if (!authenticated) return;
      await ApiService.login(credentials.email, credentials.password);
    } on ApiException catch (error) {
      String? cleanupError;
      try {
        await _biometricSignIn.disable();
      } catch (error) {
        cleanupError = error.toString().replaceFirst('Exception: ', '');
      }
      if (mounted) {
        setState(() {
          _hasBiometricSignIn = false;
          _loginErrorIsBan = error.code == 'ACCOUNT_BANNED';
          _loginError = _loginErrorIsBan ? error.message : 'Biometric sign-in was rejected. Sign in with your password and enable it again.';
          if (cleanupError != null) {
            _loginError =
                '$_loginError Saved credentials could not be cleared: $cleanupError';
          }
        });
      }
      return;
    } catch (error) {
      if (mounted) {
        setState(() {
          if (error is StateError) _hasBiometricSignIn = false;
          _loginErrorIsBan = false;
          _loginError = error.toString().replaceFirst('Exception: ', '');
        });
      }
      return;
    } finally {
      if (mounted) setState(() => _isLoggingIn = false);
    }
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainShell()),
      (_) => false,
    );
  }

  void _continueAsTourist() {
    Navigator.of(context)
        .pushReplacement(MaterialPageRoute(builder: (_) => const MainShell()));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: deepNavy,
    body: Stack(
      children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(
                  'assets/chatbot_character/chatbot_face/background.png',
                ),
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        const Positioned.fill(child: ColoredBox(color: Color(0x66F7FAF7))),
        SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 56,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(20, 26, 20, 18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: deepNavy.withValues(alpha: .20),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: DefaultTextStyle.merge(
                        style: appearanceFontStyle(
                          infraAppearance.value.typeface,
                          const TextStyle(),
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 38,
                                    height: 38,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(11),
                                      child: Image.asset(
                                        'assets/chatbot_character/chatbot_face/logo (2).png',
                                        fit: BoxFit.cover,
                                        semanticLabel: 'InfraTrack logo',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 9),
                                  Text.rich(
                                    TextSpan(
                                      text: 'Infra',
                                      style: infraHeading(
                                        color: navy,
                                        fontSize: 20,
                                        weight: FontWeight.w800,
                                      ),
                                      children: [
                                        TextSpan(
                                          text: 'Track',
                                          style: infraHeading(
                                            color: brandOrange,
                                            fontSize: 20,
                                            weight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'MATI CITY  ·  DAVAO ORIENTAL',
                                style: TextStyle(
                                  color: teal,
                                  fontSize: 7,
                                  letterSpacing: 1.2,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 15),
                              const Text(
                                'Log in to track your reports and get updates\nfrom the LGU.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: inkSoft,
                                  fontSize: 11,
                                  height: 1.45,
                                ),
                              ),
                              if (widget.sessionNotice != null) ...[
                                const SizedBox(height: 17),
                                _SessionNoticeContent(
                                  message: widget.sessionNotice!,
                                ),
                              ],
                              const SizedBox(height: 22),
                              _LoginField(
                                label: 'Email address',
                                hint: 'Enter your email',
                                icon: Icons.mail_outline,
                                controller: _emailController,
                                onChanged: (_) {
                                  if (_loginError != null) {
                                    setState(() => _loginError = null);
                                  }
                                },
                                keyboardType: TextInputType.emailAddress,
                                validator: (value) =>
                                    value == null || value.trim().isEmpty
                                    ? 'Enter your email address.'
                                    : null,
                              ),
                              _LoginField(
                                label: 'Password',
                                hint: 'Enter your password',
                                icon: Icons.lock_outline,
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                onChanged: (_) {
                                  if (_loginError != null) {
                                    setState(() => _loginError = null);
                                  }
                                },
                                validator: (value) =>
                                    value == null || value.isEmpty
                                    ? 'Enter your password.'
                                    : null,
                                suffixIcon: IconButton(
                                  onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  ),
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    size: 17,
                                  ),
                                ),
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _isLoggingIn
                                      ? null
                                      : () async {
                                          final passwordChanged =
                                              await Navigator.of(context)
                                                  .push<bool>(
                                                    MaterialPageRoute(
                                                      builder: (_) =>
                                                          PasswordResetPage(
                                                            initialEmail:
                                                                _emailController
                                                                    .text
                                                                    .trim(),
                                                          ),
                                                    ),
                                                  );
                                          if (!context.mounted ||
                                              passwordChanged != true) {
                                            return;
                                          }
                                          showInfraNotice(
                                            context,
                                            'Your password was updated. Sign in with your new password.',
                                            kind: InfraNoticeKind.success,
                                          );
                                        },
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 2,
                                    ),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text('Forgot your password?'),
                                ),
                              ),
                              const SizedBox(height: 18),
                              SizedBox(
                                width: double.infinity,
                                height: 42,
                                child: FilledButton(
                                  onPressed: _isLoggingIn ? null : _login,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: clay,
                                    foregroundColor: Colors.white,
                                    elevation: 4,
                                    shadowColor: clay.withValues(alpha: .35),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(11),
                                    ),
                                  ),
                                  child: _isLoggingIn
                                      ? const SizedBox(
                                          width: 17,
                                          height: 17,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text(
                                          'Log in',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                ),
                              ),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 220),
                                child: _loginError == null
                                    ? const SizedBox.shrink(
                                        key: ValueKey('no-login-error'),
                                      )
                                    : Padding(
                                        key: const ValueKey('login-error'),
                                        padding: const EdgeInsets.only(top: 10),
                                        child: _LoginErrorCard(
                                          message: _loginError!,
                                          isAccountBan: _loginErrorIsBan,
                                        ),
                                      ),
                              ),
                              const SizedBox(height: 16),
                              const Row(
                                children: [
                                  Expanded(child: Divider(color: line)),
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 10,
                                    ),
                                    child: Text(
                                      'OR',
                                      style: TextStyle(
                                        color: inkSoft,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                  Expanded(child: Divider(color: line)),
                                ],
                              ),
                              if (_hasBiometricSignIn) ...[
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  height: 42,
                                  child: OutlinedButton.icon(
                                    onPressed: _isLoggingIn
                                        ? null
                                        : _loginWithBiometrics,
                                    icon: const Icon(Icons.fingerprint),
                                    label: const Text(
                                      'Sign in with biometrics',
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: navy,
                                      side: const BorderSide(color: line),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(11),
                                      ),
                                      textStyle: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              TextButton.icon(
                                onPressed: _continueAsTourist,
                                style: TextButton.styleFrom(
                                  foregroundColor: Theme.of(context)
                                      .colorScheme
                                      .primary,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.travel_explore,
                                  size: 15,
                                ),
                                label: const Text(
                                  'Continue as tourist',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const CreateAccountPage(),
                                  ),
                                ),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 3,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text.rich(
                                  TextSpan(
                                    text: "Don't have an account? ",
                                    style: TextStyle(
                                      color: inkSoft,
                                      fontSize: 10,
                                    ),
                                    children: [
                                      TextSpan(
                                        text: 'Sign up',
                                        style: TextStyle(
                                          color: teal,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text.rich(
                                TextSpan(
                                  text: 'Reporting requires ',
                                  style: TextStyle(
                                    color: inkSoft,
                                    fontSize: 9.5,
                                    height: 1.4,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: 'ID and selfie verification',
                                      style: TextStyle(
                                        color: navy,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    TextSpan(
                                      text: ' to keep reports credible and prevent fake accounts. Tourists can browse reports and advisories without an account.',
                                    ),
                                  ],
                                ),
                                textAlign: TextAlign.center,
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
        ),
      ],
    ),
  );
}

class _LoginErrorCard extends StatelessWidget {
  const _LoginErrorCard({required this.message, this.isAccountBan = false});

  final String message;
  final bool isAccountBan;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    decoration: BoxDecoration(
      color: red.withValues(alpha: .09),
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: red.withValues(alpha: .24)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: red.withValues(alpha: .14),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.close, color: red, size: 15),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isAccountBan
                    ? 'Account access restricted'
                    : 'Sign-in unsuccessful',
                style: TextStyle(
                  color: red,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                isAccountBan
                    ? message
                    : '$message Check your email and password, or use the testing account below.',
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

class _LoginField extends StatelessWidget {
  const _LoginField({
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
    padding: const EdgeInsets.only(bottom: 13),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: inkSoft,
            fontSize: 10.5,
            letterSpacing: .5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 7),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          obscureText: obscureText,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 10, right: 8),
              child: Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF3C9),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: navy, size: 20),
              ),
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 56,
              minHeight: 56,
            ),
            suffixIcon: suffixIcon,
          ),
        ),
      ],
    ),
  );
}

class _SplashArt extends StatefulWidget {
  const _SplashArt({required this.compact});
  final bool compact;

  @override
  State<_SplashArt> createState() => _SplashArtState();
}

class _SplashArtState extends State<_SplashArt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 7),
  )..repeat();

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      SizedBox(
        width: widget.compact ? 180 : 212,
        height: widget.compact ? 180 : 212,
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) => Stack(
            alignment: Alignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: .14),
                  ),
                ),
              ),
              Container(
                width: widget.compact ? 136 : 164,
                height: widget.compact ? 136 : 164,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: .10),
                  ),
                ),
              ),
              CustomPaint(
                size: Size.infinite,
                painter: _SplashOrbitPainter(_animationController.value),
              ),
              Transform.scale(
                scale:
                    1 +
                    math.sin(_animationController.value * math.pi * 2) * .035,
                child: Container(
                  width: 102,
                  height: 102,
                  decoration: BoxDecoration(
                    color: clay,
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: [
                      BoxShadow(
                        color: clay.withValues(alpha: .30),
                        blurRadius:
                            20 +
                            math.sin(_animationController.value * math.pi * 2) *
                                4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.add_location_alt,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 20),
      const Text(
        'InfraTrack',
        style: TextStyle(
          color: Colors.white,
          fontSize: 30,
          fontWeight: FontWeight.w800,
          letterSpacing: -.3,
        ),
      ),
      const SizedBox(height: 5),
      const Text(
        'MATI CITY · DAVAO ORIENTAL',
        style: TextStyle(
          color: Color(0xFF7FA6AE),
          fontSize: 11,
          letterSpacing: 1.1,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

class _SplashOrbitPainter extends CustomPainter {
  _SplashOrbitPainter(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width * .405;
    final dots = [
      (clay, 0.0, 7.0),
      (teal, math.pi / 2, 5.0),
      (amber, math.pi, 6.0),
      (green, math.pi * 1.5, 5.0),
    ];

    for (final (color, startingAngle, dotSize) in dots) {
      final angle = startingAngle + progress * math.pi * 2;
      final position = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
      );
      final pulse =
          .78 + math.sin((progress * math.pi * 2) + startingAngle) * .2;
      canvas.drawCircle(
        position,
        dotSize / 2 * pulse,
        Paint()..color = color.withValues(alpha: .9),
      );
    }
  }

  @override
  bool shouldRepaint(_SplashOrbitPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _SplashActions extends StatelessWidget {
  const _SplashActions({
    required this.onCreateAccount,
    required this.onLogin,
    required this.onTourist,
  });
  final VoidCallback onCreateAccount;
  final VoidCallback onLogin;
  final VoidCallback onTourist;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _ActionButton(label: 'Log in', background: clay, onPressed: onLogin),
      const SizedBox(height: 14),
      TextButton(
        onPressed: onCreateAccount,
        style: TextButton.styleFrom(
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        ),
        child: const Text.rich(
          TextSpan(
            text: "Don't have an account? ",
            style: TextStyle(color: Color(0xFFB9CBD1)),
            children: [
              TextSpan(
                text: 'Sign up',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
      TextButton.icon(
        onPressed: onTourist,
        style: TextButton.styleFrom(
          minimumSize: Size.zero,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
        icon: const Icon(
          Icons.travel_explore,
          color: Color(0xFF8FB4BB),
          size: 16,
        ),
        label: const Text(
          'Continue as tourist',
          style: TextStyle(
            color: Color(0xFF8FB4BB),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      const Text(
        'Reporting requires ID and selfie verification to keep reports credible and prevent fake accounts. Tourists can browse reports and advisories without an account.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Color(0xFF6E8E95), fontSize: 10.5, height: 1.5),
      ),
    ],
  );
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.background,
    required this.onPressed,
  });
  final String label;
  final Color background;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: Colors.white,
          side: BorderSide(color: background),
          minimumSize: Size.zero,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
    );
  }
}

class _SessionNoticeContent extends StatelessWidget {
  const _SessionNoticeContent({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
    decoration: BoxDecoration(
      color: const Color(0xFFF0F7F5),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: teal.withValues(alpha: .20)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: teal.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.lock_clock_rounded, color: teal, size: 20),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your session has ended',
                style: infraHeading(
                  color: navy,
                  fontSize: 13,
                  weight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                message,
                style: const TextStyle(
                  color: inkSoft,
                  fontSize: 10.5,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                'Your reports and account details are safe. Sign in again to continue.',
                style: TextStyle(
                  color: navy,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
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

class AccountBannedDialog extends StatelessWidget {
  const AccountBannedDialog({super.key, required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * .82;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Container(
          key: const ValueKey('accountBannedDialogSurface'),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: sand,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.white.withValues(alpha: .85)),
            boxShadow: [
              BoxShadow(
                color: deepNavy.withValues(alpha: .22),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: clay.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.gpp_bad_outlined,
                    color: clay,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Account access restricted',
                  style: infraHeading(
                    color: navy,
                    fontSize: 21,
                    weight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 9),
                const Text(
                  'Your InfraTrack account has been banned. You have been signed out and cannot sign in while the ban is in effect.',
                  style: TextStyle(color: inkSoft, fontSize: 14, height: 1.55),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .72),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: line),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded, color: teal, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'If you believe this is a mistake, contact Mati City support for help.',
                          style: TextStyle(
                            color: inkSoft,
                            fontSize: 12.5,
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
                  child: FilledButton(
                    onPressed: onContinue,
                    style: FilledButton.styleFrom(
                      backgroundColor: clay,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: const Text(
                      'Sign out',
                      style: TextStyle(fontWeight: FontWeight.w800),
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

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  static const _guideSteps = <_GuideStep>[
    _GuideStep(
      title: 'Your city at a glance',
      description: 'Home brings together community updates, recent reports, and important city information.',
      destination: 0,
    ),
    _GuideStep(
      title: 'Explore the infrastructure map',
      description: 'Browse reported issues around Mati City and open a marker to see report details.',
      destination: 1,
    ),
    _GuideStep(
      title: 'Report an issue',
      description: 'Use this button to report damaged roads, facilities, drainage, and other infrastructure concerns.',
      destination: 2,
      isReportAction: true,
    ),
    _GuideStep(
      title: 'Stay informed',
      description:
          'Check city advisories and community updates in the News section.',
      destination: 3,
    ),
    _GuideStep(
      title: 'Your account and reports',
      description: 'Manage your profile, check verification status, and keep track of your submitted reports.',
      destination: 4,
    ),
  ];

  int index = 0;
  int? _guideStep;
  bool _handlingExpiredSession = false;
  bool _handlingAccountBan = false;
  final _shellKey = GlobalKey();
  final _guideReportKey = GlobalKey();
  final _guideDestinationKeys = List<GlobalKey>.generate(5, (_) => GlobalKey());
  final _homeKey = GlobalKey<_HomePageState>();
  final _mapKey = GlobalKey<_MapPageState>();
  final _reportKey = GlobalKey<_ReportPageState>();
  final _newsKey = GlobalKey<_NewsPageState>();
  final _profileKey = GlobalKey<_ProfilePageState>();

  late final pages = [
    HomePage(key: _homeKey, onOpenNews: openNewsTab),
    MapPage(key: _mapKey),
    ReportPage(key: _reportKey),
    NewsPage(key: _newsKey),
    ProfilePage(key: _profileKey, onStartGuide: _startGuide),
  ];

  @override
  void initState() {
    super.initState();
    ApiService.sessionExpired.addListener(_handleExpiredSession);
    ApiService.accountBanned.addListener(_handleAccountBanned);
    ApiService.connectionRestored.addListener(_handleConnectionRestored);
    PushNotifications.instance.onNotificationTap = _handlePushNotification;
    unawaited(_showFirstLaunchGuide());
    unawaited(
      PushNotifications.instance.initialize(
        authenticated: ApiService.isSignedIn,
      ),
    );
  }

  Future<void> _showFirstLaunchGuide() async {
    try {
      if (!await AppGuidePreferences.shouldShowFirstLaunchGuide() || !mounted) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (mounted) _startGuide();
    } catch (error, stackTrace) {
      debugPrint('Could not check first-launch guide preference: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  void _startGuide() {
    if (!mounted) return;
    setState(() {
      index = 0;
      _guideStep = 0;
    });
  }

  void _advanceGuide() {
    final step = _guideStep;
    if (step == null) return;
    if (step < _guideSteps.length) {
      final nextStep = step + 1;
      setState(() {
        _guideStep = nextStep;
        if (nextStep < _guideSteps.length) {
          index = _guideSteps[nextStep].destination;
        }
      });
      return;
    }
    unawaited(_finishGuide());
  }

  Future<void> _finishGuide() async {
    if (!mounted) return;
    setState(() {
      _guideStep = null;
      index = 0;
    });
    try {
      await AppGuidePreferences.markGuideCompleted();
    } catch (error, stackTrace) {
      debugPrint('Could not save guide completion preference: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Rect? _guideTargetRect() {
    final step = _guideStep;
    if (step == null || step >= _guideSteps.length) return null;
    final guideStep = _guideSteps[step];
    final targetKey = guideStep.isReportAction
        ? _guideReportKey
        : _guideDestinationKeys[guideStep.destination];
    final targetBox =
        targetKey.currentContext?.findRenderObject() as RenderBox?;
    final shellBox = _shellKey.currentContext?.findRenderObject() as RenderBox?;
    if (targetBox == null ||
        shellBox == null ||
        !targetBox.hasSize ||
        !shellBox.hasSize) {
      return null;
    }
    final globalRect = targetBox.localToGlobal(Offset.zero) & targetBox.size;
    final shellOrigin = shellBox.localToGlobal(Offset.zero);
    return globalRect.shift(-shellOrigin);
  }

  void _handleConnectionRestored() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_refreshPage(index));
    });
  }

  void _handleAccountBanned() {
    if (_handlingAccountBan || !mounted) return;
    _handlingAccountBan = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AccountBannedDialog(
          onContinue: () => Navigator.of(dialogContext).pop(),
        ),
      );
      if (!mounted) return;
      await ApiService.signOutForExpiredSession();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (_) => false,
      );
    });
  }

  void _handleExpiredSession() {
    if (_handlingExpiredSession || !mounted) return;
    _handlingExpiredSession = true;
    final notice =
        ApiService.consumeSessionNotice() ??
        'Your session has expired. Please sign in again to continue.';
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await ApiService.signOutForExpiredSession();
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => LoginPage(sessionNotice: notice)),
        (_) => false,
      );
    });
  }

  @override
  void dispose() {
    ApiService.sessionExpired.removeListener(_handleExpiredSession);
    ApiService.accountBanned.removeListener(_handleAccountBanned);
    ApiService.connectionRestored.removeListener(_handleConnectionRestored);
    PushNotifications.instance.onNotificationTap = null;
    super.dispose();
  }

  Future<void> _refreshPage(int pageIndex) async {
    switch (pageIndex) {
      case 0:
        await _homeKey.currentState?.refresh();
      case 1:
        await _mapKey.currentState?.refresh();
      case 2:
        await _reportKey.currentState?.refresh();
      case 3:
        await _newsKey.currentState?.refresh();
      case 4:
        await _profileKey.currentState?.refresh();
    }
  }

  void openNewsTab() {
    if (!mounted) return;
    setState(() => index = 3);
    unawaited(_refreshPage(3));
  }

  void _handlePushNotification(Map<String, dynamic> data) {
    final notificationId = int.tryParse(
      data['notificationId']?.toString() ?? '',
    );
    if (notificationId != null && ApiService.isSignedIn) {
      unawaited(() async {
        try {
          await ApiService.markNotificationRead(notificationId);
        } catch (error, stackTrace) {
          debugPrint('Could not mark tapped push notification as read: $error');
          debugPrintStack(stackTrace: stackTrace);
        }
      }());
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (data['advisoryId'] != null) {
        openNewsTab();
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => NotificationsPage(onCityUpdateSelected: openNewsTab),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeGuideStep = _guideStep;
    return Stack(
      key: _shellKey,
      children: [
        Scaffold(
          body: SafeArea(
            child: IndexedStack(index: index, children: pages),
          ),
          bottomNavigationBar: Container(
            margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF102C38)
                  : Colors.white.withValues(alpha: .72),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF396170)
                    : Colors.white.withValues(alpha: .85),
              ),
              boxShadow: [
                BoxShadow(
                  color:
                      (Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF081D29)
                              : navy)
                          .withValues(alpha: .14),
                  blurRadius: 26,
                  spreadRadius: 1,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: NavigationBarTheme(
                      data: NavigationBarThemeData(
                        height: 70,
                        backgroundColor: Colors.transparent,
                        surfaceTintColor: Colors.transparent,
                        elevation: 0,
                        indicatorColor: Theme.of(context).colorScheme.primary
                            .withValues(
                              alpha:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? 0.18
                                  : 0.20,
                            ),
                        indicatorShape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        labelTextStyle: WidgetStateProperty.resolveWith(
                          (states) => TextStyle(
                            color: states.contains(WidgetState.selected)
                                ? (infraAppearance.value.highContrast
                                      ? Theme.of(context).colorScheme.onSurface
                                      : Theme.of(context).colorScheme.primary)
                                : (Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? const Color(0xFFB7CDD0)
                                      : inkSoft),
                            fontSize: 10,
                            fontWeight: states.contains(WidgetState.selected)
                                ? FontWeight.w800
                                : FontWeight.w600,
                          ),
                        ),
                        iconTheme: WidgetStateProperty.resolveWith(
                          (states) => IconThemeData(
                            color: states.contains(WidgetState.selected)
                                ? (infraAppearance.value.highContrast
                                      ? Theme.of(context).colorScheme.onSurface
                                      : Theme.of(context).colorScheme.primary)
                                : (Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? const Color(0xFFB7CDD0)
                                      : inkSoft),
                            size: 22,
                          ),
                        ),
                      ),
                      child: NavigationBar(
                        labelBehavior:
                            NavigationDestinationLabelBehavior.alwaysShow,
                        selectedIndex: index,
                        onDestinationSelected: (value) {
                          if (value == index) {
                            unawaited(_refreshPage(value));
                            return;
                          }
                          setState(() => index = value);
                          if (value == 3) unawaited(_refreshPage(value));
                        },
                        destinations: [
                          NavigationDestination(
                            key: _guideDestinationKeys[0],
                            icon: Icon(Icons.home_outlined),
                            selectedIcon: Icon(Icons.home),
                            label: 'Home',
                          ),
                          NavigationDestination(
                            key: _guideDestinationKeys[1],
                            icon: Icon(Icons.map_outlined),
                            selectedIcon: Icon(Icons.map),
                            label: 'Map',
                          ),
                          NavigationDestination(
                            key: _guideDestinationKeys[2],
                            icon: SizedBox(width: 24, height: 24),
                            selectedIcon: SizedBox(width: 24, height: 24),
                            label: 'Report',
                          ),
                          NavigationDestination(
                            key: _guideDestinationKeys[3],
                            icon: Icon(Icons.newspaper_outlined),
                            selectedIcon: Icon(Icons.newspaper),
                            label: 'News',
                          ),
                          NavigationDestination(
                            key: _guideDestinationKeys[4],
                            icon: Icon(Icons.person_outline),
                            selectedIcon: Icon(Icons.person),
                            label: 'Profile',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: -18,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: _FloatingReportButton(
                      key: _guideReportKey,
                      selected: index == 2,
                      onPressed: () {
                        if (index == 2) {
                          unawaited(_refreshPage(2));
                        } else {
                          setState(() => index = 2);
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (activeGuideStep != null)
          Positioned.fill(
            child: _InfraTrackGuideOverlay(
              stepIndex: activeGuideStep,
              steps: _guideSteps,
              targetRect: _guideTargetRect(),
              onAdvance: _advanceGuide,
              onSkip: _finishGuide,
            ),
          ),
      ],
    );
  }
}

class _GuideStep {
  const _GuideStep({
    required this.title,
    required this.description,
    required this.destination,
    this.isReportAction = false,
  });

  final String title;
  final String description;
  final int destination;
  final bool isReportAction;
}

class _InfraTrackGuideOverlay extends StatelessWidget {
  const _InfraTrackGuideOverlay({
    required this.stepIndex,
    required this.steps,
    required this.targetRect,
    required this.onAdvance,
    required this.onSkip,
  });

  final int stepIndex;
  final List<_GuideStep> steps;
  final Rect? targetRect;
  final VoidCallback onAdvance;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final isFinalStep = stepIndex >= steps.length;
    final totalSteps = steps.length + 1;
    final guideStep = isFinalStep ? null : steps[stepIndex];

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardHeight = isFinalStep ? 220.0 : 242.0;
        final cardTop = isFinalStep
            ? (constraints.maxHeight - cardHeight) / 2
            : ((targetRect?.top ?? constraints.maxHeight * .74) -
                      cardHeight -
                      28)
                  .clamp(
                    MediaQuery.paddingOf(context).top + 68,
                    constraints.maxHeight - cardHeight - 90,
                  )
                  .toDouble();

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onAdvance,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _GuideDimmerPainter(
                    targetRect: isFinalStep ? null : targetRect,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
              if (isFinalStep)
                const Positioned.fill(
                  child: IgnorePointer(child: _GuideConfetti()),
                ),
              if (!isFinalStep)
                Positioned(
                  top: MediaQuery.paddingOf(context).top + 10,
                  right: 16,
                  child: TextButton(
                    onPressed: onSkip,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: deepNavy.withValues(alpha: .82),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 9,
                      ),
                      shape: const StadiumBorder(),
                    ),
                    child: const Text(
                      'Skip tour',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              Positioned(
                top: cardTop,
                left: 20,
                right: 20,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Material(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF102C38)
                          : sand,
                      elevation: 18,
                      shadowColor: Colors.black.withValues(alpha: .35),
                      borderRadius: BorderRadius.circular(26),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(21, 20, 21, 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (isFinalStep) ...[
                              const Center(
                                child: Icon(
                                  Icons.celebration_rounded,
                                  color: clay,
                                  size: 38,
                                ),
                              ),
                              const SizedBox(height: 8),
                            ] else
                              Text(
                                'STEP ${stepIndex + 1} OF $totalSteps',
                                style: const TextStyle(
                                  color: teal,
                                  fontSize: 10,
                                  letterSpacing: 1.1,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            Center(
                              child: Text(
                                isFinalStep
                                    ? 'You’re all set!'
                                    : guideStep!.title,
                                textAlign: isFinalStep
                                    ? TextAlign.center
                                    : TextAlign.start,
                                style: infraHeading(
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.white
                                      : navy,
                                  fontSize: 21,
                                  weight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(height: 9),
                            Center(
                              child: Text(
                                isFinalStep
                                    ? 'You’re ready to help make Mati City better. You can replay this guide anytime from your profile.'
                                    : guideStep!.description,
                                textAlign: isFinalStep
                                    ? TextAlign.center
                                    : TextAlign.start,
                                style: TextStyle(
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? const Color(0xFFC1D3D5)
                                      : inkSoft,
                                  fontSize: 14,
                                  height: 1.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 15),
                            Row(
                              children: [
                                if (!isFinalStep)
                                  Expanded(
                                    child: Row(
                                      children: [
                                        for (
                                          var dot = 0;
                                          dot < totalSteps;
                                          dot++
                                        ) ...[
                                          AnimatedContainer(
                                            duration: const Duration(
                                              milliseconds: 180,
                                            ),
                                            width: dot == stepIndex ? 18 : 6,
                                            height: 6,
                                            decoration: BoxDecoration(
                                              color: dot == stepIndex
                                                  ? teal
                                                  : line,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                          if (dot < totalSteps - 1)
                                            const SizedBox(width: 5),
                                        ],
                                      ],
                                    ),
                                  )
                                else
                                  const Spacer(),
                                if (!isFinalStep)
                                  FilledButton(
                                    onPressed: onAdvance,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: clay,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 18,
                                        vertical: 11,
                                      ),
                                    ),
                                    child: const Text('Next'),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 9),
                            Center(
                              child: Text(
                                isFinalStep
                                    ? 'Tap anywhere to finish'
                                    : 'Tap anywhere to continue',
                                style: TextStyle(
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? const Color(0xFFB7CDD0)
                                      : inkSoft,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
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
      },
    );
  }
}

class _GuideDimmerPainter extends CustomPainter {
  const _GuideDimmerPainter({required this.targetRect});

  final Rect? targetRect;

  @override
  void paint(Canvas canvas, Size size) {
    final overlayPath = ui.Path()..addRect(Offset.zero & size);
    final target = targetRect?.inflate(9);
    if (target != null) {
      overlayPath.addRRect(
        RRect.fromRectAndRadius(target, const Radius.circular(18)),
      );
      overlayPath.fillType = ui.PathFillType.evenOdd;
    }

    canvas.drawPath(overlayPath, Paint()..color = const Color(0xE6000000));
    if (target != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(target, const Radius.circular(18)),
        Paint()
          ..color = const Color(0xFF75D5CF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_GuideDimmerPainter oldDelegate) =>
      oldDelegate.targetRect != targetRect;
}

class _GuideConfetti extends StatefulWidget {
  const _GuideConfetti();

  @override
  State<_GuideConfetti> createState() => _GuideConfettiState();
}

class _GuideConfettiState extends State<_GuideConfetti>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, child) => CustomPaint(
      painter: _GuideConfettiPainter(_controller.value),
      child: const SizedBox.expand(),
    ),
  );
}

class _GuideConfettiPainter extends CustomPainter {
  const _GuideConfettiPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    const colors = [teal, clay, amber, Color(0xFF75D5CF), Color(0xFFFFD978)];
    for (var index = 0; index < 58; index++) {
      final seed = (index * 47 + 13) % 101;
      final phase = (progress + (index % 17) / 17) % 1;
      final x =
          size.width * seed / 101 + math.sin(phase * math.pi * 4 + index) * 18;
      final y = phase * (size.height + 70) - 35;
      final width = 5.0 + index % 5;
      final height = 8.0 + index % 7;
      final paint = Paint()
        ..color = colors[index % colors.length].withValues(
          alpha: (1 - phase * .42).clamp(0, 1),
        );
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(phase * math.pi * 3 + index);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: width, height: height),
          const Radius.circular(1.5),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_GuideConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _FloatingReportButton extends StatelessWidget {
  const _FloatingReportButton({
    super.key,
    required this.selected,
    required this.onPressed,
  });
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onPressed,
      customBorder: const CircleBorder(),
      child: Container(
        width: 62,
        height: 62,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: .80),
          boxShadow: [
            BoxShadow(
              color: clay.withValues(alpha: .32),
              blurRadius: 16,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? clay : clay.withValues(alpha: .92),
          ),
          child: const Icon(
            Icons.add_location_alt,
            color: Colors.white,
            size: 27,
          ),
        ),
      ),
    ),
  );
}

class _FastBouncingScrollPhysics extends BouncingScrollPhysics {
  const _FastBouncingScrollPhysics({super.parent});

  @override
  _FastBouncingScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      _FastBouncingScrollPhysics(parent: buildParent(ancestor));

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) =>
      super.applyPhysicsToUserOffset(position, offset) * 1.25;
}

class AppScroll extends StatelessWidget {
  const AppScroll({
    super.key,
    required this.child,
    this.paddingTop = 12,
    this.onRefresh,
  });
  final Widget child;
  final double paddingTop;
  final Future<void> Function()? onRefresh;
  @override
  Widget build(BuildContext context) {
    final scrollView = ListView.builder(
      padding: EdgeInsets.fromLTRB(20, paddingTop, 20, 30),
      physics: const _FastBouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      clipBehavior: Clip.hardEdge,
      itemCount: 1,
      itemBuilder: (context, index) => child,
    );
    if (onRefresh == null) return scrollView;
    return RefreshIndicator(
      color: teal,
      backgroundColor: Colors.white,
      triggerMode: RefreshIndicatorTriggerMode.onEdge,
      onRefresh: onRefresh!,
      child: scrollView,
    );
  }
}

class PageEntrance extends StatefulWidget {
  const PageEntrance({super.key, required this.child});
  final Widget child;

  @override
  State<PageEntrance> createState() => _PageEntranceState();
}

class _PageEntranceState extends State<PageEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 480),
  )..forward();

  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, .035),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _fade,
    child: SlideTransition(position: _slide, child: widget.child),
  );
}

class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    this.subtitle,
    this.trailing,
  });
  final String eyebrow;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow,
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF75D5CF)
                      : teal,
                  fontSize: 10,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: infraHeading(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFFEAF6F4)
                      : navy,
                  fontSize: 24,
                  weight: FontWeight.w800,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle!,
                  style: TextStyle(
                    color: infraMutedTextColor(context),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.number,
    required this.label,
    this.dark = false,
  });
  final String number;
  final String label;
  final bool dark;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: dark
          ? navy.withValues(alpha: .92)
          : Colors.white.withValues(alpha: .62),
      borderRadius: BorderRadius.circular(16),
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
        Text(
          number,
          style: infraHeading(
            color: dark ? Colors.white : navy,
            fontSize: 27,
            weight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: dark ? const Color(0xFFB9CBD1) : inkSoft,
            fontSize: 11.5,
          ),
        ),
      ],
    ),
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle({
    super.key,
    required this.title,
    this.action,
    this.onActionTap,
  });
  final String title;
  final String? action;
  final VoidCallback? onActionTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 22, 0, 12),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: infraHeading(
            color: navy,
            fontSize: 17,
            weight: FontWeight.w800,
          ),
        ),
        if (action != null)
          GestureDetector(
            onTap: onActionTap,
            child: Text(
              action!,
              style: const TextStyle(
                color: teal,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
      ],
    ),
  );
}

class ReportCard extends StatelessWidget {
  const ReportCard({
    super.key,
    required this.title,
    required this.location,
    required this.status,
    required this.color,
    required this.icon,
    required this.onTap,
  });
  final String title;
  final String location;
  final String status;
  final Color color;
  final IconData icon;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: BorderSide(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF345A63)
            : line,
      ),
    ),
    child: ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.all(12),
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color.withValues(alpha: .13),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: color),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: infraHeading(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFFEAF6F4)
                    : ink,
                weight: FontWeight.w700,
              ),
            ),
          ),
          StatusPill(label: status, color: color),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          location,
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFFB2C9CC)
                : inkSoft,
            fontSize: 11,
          ),
        ),
      ),
    ),
  );
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800),
    ),
  );
}

class NewsCard extends StatelessWidget {
  const NewsCard({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.color = teal,
  });
  final IconData icon;
  final String title;
  final String body;
  final Color color;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: ListTile(
      contentPadding: const EdgeInsets.all(12),
      leading: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: color.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(
        title,
        style: infraHeading(color: navy, weight: FontWeight.w800),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(body, style: const TextStyle(color: inkSoft, fontSize: 11)),
      ),
    ),
  );
}

class LegendRow extends StatelessWidget {
  const LegendRow({super.key, required this.color, required this.text});
  final Color color;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Row(
      children: [
        CircleAvatar(radius: 5, backgroundColor: color),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(fontSize: 11.5, color: ink)),
      ],
    ),
  );
}

class MenuRow extends StatelessWidget {
  const MenuRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.destructive = false,
    this.accentColor,
    this.badge,
    this.inGroup = false,
    this.lastInGroup = false,
    this.showChevron = true,
    this.centered = false,
    this.onTap,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool destructive;
  final Color? accentColor;
  final String? badge;
  final bool inGroup;
  final bool lastInGroup;
  final bool showChevron;
  final bool centered;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? (destructive ? red : teal);
    final row = ListTile(
      onTap: onTap,
      minTileHeight: 68,
      contentPadding: EdgeInsets.fromLTRB(inGroup ? 14 : 12, 5, 12, 5),
      leading: centered
          ? null
          : Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: .11),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: accent, size: 21),
            ),
      title: centered
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: .11),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: accent, size: 21),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    color: destructive
                        ? red
                        : Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFFEAF6F4)
                        : navy,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ],
            )
          : Text(
              title,
              style: TextStyle(
                color: destructive
                    ? red
                    : Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFFEAF6F4)
                    : navy,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFFB2C9CC)
                    : inkSoft,
                height: 1.3,
              ),
            ),
      trailing: centered
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      badge!,
                      style: TextStyle(
                        color: accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                if (showChevron) ...[
                  const SizedBox(width: 8),
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF244753)
                          : sand,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.chevron_right,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFFB2C9CC)
                          : inkSoft,
                      size: 19,
                    ),
                  ),
                ],
              ],
            ),
    );

    if (!inGroup) {
      return Card(
        elevation: 0,
        margin: const EdgeInsets.fromLTRB(0, 0, 0, 10),
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF123643)
            : Colors.white.withValues(alpha: .78),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF345A63)
                : line,
          ),
        ),
        child: row,
      );
    }

    return Column(
      children: [
        row,
        if (!lastInGroup) const Divider(height: 1, indent: 68, endIndent: 14),
      ],
    );
  }
}
