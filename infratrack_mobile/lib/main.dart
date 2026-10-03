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
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:video_player/video_player.dart';

import 'api_service.dart';

part 'screens/home_page.dart';
part 'screens/map_page.dart';
part 'screens/report_page.dart';
part 'screens/news_page.dart';
part 'screens/profile_page.dart';
part 'screens/my_reports_page.dart';
part 'screens/notifications_page.dart';
part 'screens/chatbot_page.dart';
part 'screens/create_account_page.dart';

const navy = Color(0xFF0E3A4C);
const deepNavy = Color(0xFF092732);
const teal = Color(0xFF1B8A83);
const clay = Color(0xFFC1592B);
const sand = Color(0xFFF3EFE6);
const ink = Color(0xFF17231F);
const inkSoft = Color(0xFF5B6B67);
const line = Color(0xFFDDD8CB);
const amber = Color(0xFFD99A2B);
const green = Color(0xFF3C8A5F);
const red = Color(0xFFB33A3A);

TextStyle infraHeading({double? fontSize, Color? color, FontWeight? weight}) =>
    GoogleFonts.archivo(
      fontSize: fontSize,
      color: color,
      fontWeight: weight ?? FontWeight.w700,
    );

TextStyle infraMono({double? fontSize, Color? color, FontWeight? weight}) =>
    GoogleFonts.ibmPlexMono(
      fontSize: fontSize,
      color: color,
      fontWeight: weight,
    );

void main() => runApp(const InfraTrackApp());

class InfraTrackApp extends StatelessWidget {
  const InfraTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'InfraTrack',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: sand,
        colorScheme: ColorScheme.fromSeed(seedColor: navy),
        fontFamily: GoogleFonts.inter().fontFamily,
        textTheme: GoogleFonts.interTextTheme(),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: line),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.all(16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: teal, width: 1.5),
          ),
        ),
      ),
      home: const AppLoadingPage(),
    );
  }
}

class AppLoadingPage extends StatefulWidget {
  const AppLoadingPage({super.key});

  @override
  State<AppLoadingPage> createState() => _AppLoadingPageState();
}

class _AppLoadingPageState extends State<AppLoadingPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..forward();

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        Navigator.of(
          context,
        ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginPage()));
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: deepNavy,
    body: SafeArea(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 170,
                  height: 170,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 164,
                        height: 164,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white12),
                        ),
                      ),
                      Container(
                        width: 130,
                        height: 130,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: teal.withValues(alpha: .18),
                          ),
                        ),
                      ),
                      Transform.rotate(
                        angle: _controller.value * math.pi * 2,
                        child: SizedBox(
                          width: 164,
                          height: 164,
                          child: Stack(
                            children: [
                              Positioned(
                                top: 3,
                                left: 79,
                                child: Container(
                                  width: 7,
                                  height: 7,
                                  decoration: const BoxDecoration(
                                    color: teal,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 15,
                                bottom: 29,
                                child: Container(
                                  width: 5,
                                  height: 5,
                                  decoration: const BoxDecoration(
                                    color: amber,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 154,
                        height: 154,
                        child: CircularProgressIndicator(
                          value: _controller.value,
                          strokeWidth: 4,
                          backgroundColor: Colors.white12,
                          valueColor: const AlwaysStoppedAnimation<Color>(teal),
                        ),
                      ),
                      Transform.scale(
                        scale: Curves.easeOutBack.transform(
                          (_controller.value / .72).clamp(0.0, 1.0),
                        ),
                        child: Container(
                          width: 92,
                          height: 92,
                          decoration: BoxDecoration(
                            color: clay,
                            borderRadius: BorderRadius.circular(27),
                            boxShadow: [
                              BoxShadow(
                                color: clay.withValues(alpha: .32),
                                blurRadius: 24,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.add_location_alt,
                            color: Colors.white,
                            size: 43,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                const Text(
                  'InfraTrack',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 29,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.4,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'MATI CITY · DAVAO ORIENTAL',
                  style: TextStyle(
                    color: Color(0xFF8FB4BB),
                    fontSize: 10,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'Preparing your community dashboard',
                  style: TextStyle(
                    color: Color(0xFF8FB4BB),
                    fontSize: 11,
                    letterSpacing: .15,
                  ),
                ),
              ],
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

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoggingIn = false;
  String? _loginError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoggingIn = true);
    try {
      await ApiService.login(
        _emailController.text.trim(),
        _passwordController.text,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoggingIn = false;
        _loginError = 'We couldn’t sign you in with those details.';
      });
      return;
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
          child: CustomPaint(painter: _LoginBackgroundPainter()),
        ),
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
                        style: GoogleFonts.inter(),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: clay,
                                      borderRadius: BorderRadius.circular(11),
                                    ),
                                    child: const Icon(
                                      Icons.add_location_alt,
                                      color: Colors.white,
                                      size: 21,
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
                                            color: clay,
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
                                  onPressed: () => ScaffoldMessenger.of(context)
                                      .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Password reset is not connected yet.',
                                          ),
                                        ),
                                      ),
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
                              TextButton.icon(
                                onPressed: _continueAsTourist,
                                style: TextButton.styleFrom(
                                  foregroundColor: teal,
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

class _LoginBackgroundPainter extends CustomPainter {
  const _LoginBackgroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF7FAF7), Color(0xFFE9F3EF), Color(0xFFF3EFE6)],
          stops: [0.0, .56, 1.0],
        ).createShader(bounds),
    );

    final tealShape = Paint()..color = teal.withValues(alpha: .09);
    canvas.drawCircle(
      Offset(size.width * .96, size.height * .12),
      size.width * .42,
      tealShape,
    );
    final clayShape = Paint()..color = clay.withValues(alpha: .07);
    canvas.drawCircle(
      Offset(size.width * .02, size.height * .88),
      size.width * .34,
      clayShape,
    );

    final curvePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = teal.withValues(alpha: .12);
    canvas.drawArc(
      Rect.fromCircle(
        center: Offset(size.width * .98, size.height * .18),
        radius: size.width * .33,
      ),
      math.pi * .45,
      math.pi * .82,
      false,
      curvePaint,
    );
    canvas.drawArc(
      Rect.fromCircle(
        center: Offset(size.width * .02, size.height * .84),
        radius: size.width * .27,
      ),
      -math.pi * .42,
      math.pi * .75,
      false,
      curvePaint,
    );

    final glowPaint = Paint()
      ..shader =
          RadialGradient(
            colors: [
              teal.withValues(alpha: .10),
              teal.withValues(alpha: .025),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * .82, size.height * .18),
              radius: size.width * .72,
            ),
          );
    canvas.drawCircle(
      Offset(size.width * .82, size.height * .18),
      size.width * .72,
      glowPaint,
    );

    final warmGlow = Paint()
      ..shader =
          RadialGradient(
            colors: [
              clay.withValues(alpha: .07),
              clay.withValues(alpha: .015),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * .08, size.height * .86),
              radius: size.width * .58,
            ),
          );
    canvas.drawCircle(
      Offset(size.width * .08, size.height * .86),
      size.width * .58,
      warmGlow,
    );

    final mapPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .8
      ..color = const Color(0xFF1B8A83).withValues(alpha: .07);
    for (var index = 0; index < 2; index++) {
      final points = <Offset>[
        Offset(-20, size.height * (.67 + index * .08)),
        Offset(size.width * .22, size.height * (.62 + index * .08)),
        Offset(size.width * .50, size.height * (.71 + index * .08)),
        Offset(size.width + 20, size.height * (.65 + index * .08)),
      ];
      for (var point = 0; point < points.length - 1; point++) {
        canvas.drawLine(points[point], points[point + 1], mapPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_LoginBackgroundPainter oldDelegate) => false;
}

class _LoginErrorCard extends StatelessWidget {
  const _LoginErrorCard({required this.message});

  final String message;

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
              const Text(
                'Sign-in unsuccessful',
                style: TextStyle(
                  color: red,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '$message Check your email and password, or use the testing account below.',
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

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int index = 0;
  final pages = const [
    HomePage(),
    MapPage(),
    ReportPage(),
    NewsPage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(index: index, children: pages),
      ),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .72),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: .85)),
          boxShadow: [
            BoxShadow(
              color: navy.withValues(alpha: .14),
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
                    indicatorColor: teal.withValues(alpha: .20),
                    indicatorShape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    labelTextStyle: WidgetStateProperty.resolveWith(
                      (states) => TextStyle(
                        color: states.contains(WidgetState.selected)
                            ? navy
                            : inkSoft,
                        fontSize: 10,
                        fontWeight: states.contains(WidgetState.selected)
                            ? FontWeight.w800
                            : FontWeight.w600,
                      ),
                    ),
                    iconTheme: WidgetStateProperty.resolveWith(
                      (states) => IconThemeData(
                        color: states.contains(WidgetState.selected)
                            ? navy
                            : inkSoft,
                        size: 22,
                      ),
                    ),
                  ),
                  child: NavigationBar(
                    labelBehavior:
                        NavigationDestinationLabelBehavior.alwaysShow,
                    selectedIndex: index,
                    onDestinationSelected: (value) =>
                        setState(() => index = value),
                    destinations: const [
                      NavigationDestination(
                        icon: Icon(Icons.home_outlined),
                        selectedIcon: Icon(Icons.home),
                        label: 'Home',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.map_outlined),
                        selectedIcon: Icon(Icons.map),
                        label: 'Map',
                      ),
                      NavigationDestination(
                        icon: SizedBox(width: 24, height: 24),
                        selectedIcon: SizedBox(width: 24, height: 24),
                        label: 'Report',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.newspaper_outlined),
                        selectedIcon: Icon(Icons.newspaper),
                        label: 'News',
                      ),
                      NavigationDestination(
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
                  selected: index == 2,
                  onPressed: () => setState(() => index = 2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FloatingReportButton extends StatelessWidget {
  const _FloatingReportButton({
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
  const AppScroll({super.key, required this.child, this.paddingTop = 12});
  final Widget child;
  final double paddingTop;
  @override
  Widget build(BuildContext context) => ListView.builder(
    padding: EdgeInsets.fromLTRB(20, paddingTop, 20, 30),
    physics: const _FastBouncingScrollPhysics(
      parent: AlwaysScrollableScrollPhysics(),
    ),
    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
    clipBehavior: Clip.none,
    itemCount: 1,
    itemBuilder: (context, index) => child,
  );
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
    this.trailing,
  });
  final String eyebrow;
  final String title;
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
                style: const TextStyle(
                  color: teal,
                  fontSize: 10,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: infraHeading(
                  color: navy,
                  fontSize: 24,
                  weight: FontWeight.w800,
                ),
              ),
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
      side: const BorderSide(color: line),
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
              style: infraHeading(color: ink, weight: FontWeight.w700),
            ),
          ),
          StatusPill(label: status, color: color),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          location,
          style: const TextStyle(color: inkSoft, fontSize: 11),
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
                    color: destructive ? red : navy,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ],
            )
          : Text(
              title,
              style: TextStyle(
                color: destructive ? red : navy,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: const TextStyle(fontSize: 11, color: inkSoft, height: 1.3),
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
                      color: sand,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.chevron_right,
                      color: inkSoft,
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
        color: Colors.white.withValues(alpha: .78),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: line),
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
