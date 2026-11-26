import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/firebase_service.dart';
import '../home_screen.dart';
import 'phone_auth_screen.dart';

const String _kLogoAsset = 'assets/logo/modychat_logo.png';

class _SplashPalette {
  static const Color navyTop = Color(0xFF080D1F);
  static const Color navyBottom = Color(0xFF1B2038);
  static const Color blue = Color(0xFF3B82F6);
  static const Color cyan = Color(0xFF22D3EE);
  static const Color indigo = Color(0xFF6366F1);
  static const Color purple = Color(0xFFA855F7);
  static const Color shine = Color(0xFFE9D5FF);
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _introController;
  late final AnimationController _orbController;
  late final AnimationController _floatController;
  late final AnimationController _shimmerController;
  late final AnimationController _spinController;

  late final Animation<double> _logoOpacity;
  late final Animation<double> _logoScale;
  late final Animation<double> _titleOpacity;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _taglineOpacity;
  late final Animation<double> _loaderOpacity;

  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();

    // One-shot entrance sequence.
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    // Slow, continuous background orb drift.
    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 12000),
    )..repeat();

    // Subtle logo float + glow pulse.
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat(reverse: true);

    // "Chat" gradient shimmer.
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();

    // Gradient loader spin.
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();

    _logoOpacity = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.0, 0.55, curve: Curves.easeOut),
    );

    _logoScale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.0, 0.85, curve: Curves.easeOutCubic),
      ),
    );

    _titleOpacity = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.45, 0.95, curve: Curves.easeOut),
    );

    _titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.30),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.45, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _taglineOpacity = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.70, 1.0, curve: Curves.easeOut),
    );

    _loaderOpacity = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.60, 1.0, curve: Curves.easeOut),
    );

    _introController.forward();

    // Check onboarding completion and auto-navigate after 2.8 seconds
    _navigationTimer =
        Timer(const Duration(milliseconds: 5000), () async {
      if (!mounted) return;

      final prefs = await SharedPreferences.getInstance();
      final isCompleted = prefs.getBool('onboarding_completed') ?? false;
      final savedPhone = prefs.getString('user_phone');
      final savedName = prefs.getString('user_name');

      if (!mounted) return;

      Widget targetScreen;
      if (isCompleted && savedPhone != null && savedPhone.isNotEmpty) {
        FirebaseService.setCurrentUser(savedPhone, savedName ?? savedPhone);
        targetScreen = const HomeScreen();
      } else {
        targetScreen = const PhoneAuthScreen();
      }

      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => targetScreen,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 600),
        ),
      );
    });
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _introController.dispose();
    _orbController.dispose();
    _floatController.dispose();
    _shimmerController.dispose();
    _spinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _SplashPalette.navyTop,
      body: Stack(
        children: [
          // Deep navy base gradient
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    _SplashPalette.navyTop,
                    Color(0xFF101636),
                    _SplashPalette.navyBottom,
                  ],
                ),
              ),
            ),
          ),

          // Atmospheric glow orbs, partially off-canvas
          AnimatedBuilder(
            animation: _orbController,
            builder: (context, _) => _buildOrbs(_orbController.value),
          ),

          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Responsive sizing so nothing overflows on small/short screens.
                final width = constraints.maxWidth;
                final height = constraints.maxHeight;
                final logoSize = (height * 0.26).clamp(84.0, 168.0);
                final titleSize = (width * 0.098).clamp(26.0, 42.0);

                return Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          physics: const NeverScrollableScrollPhysics(),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildLogo(logoSize),
                              SizedBox(height: (logoSize * 0.22).clamp(20.0, 34.0)),
                              _buildTitle(titleSize),
                              SizedBox(height: (titleSize * 0.34).clamp(10.0, 16.0)),
                              _buildTagline(),
                            ],
                          ),
                        ),
                      ),
                    ),
                    _buildFooter(),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrbs(double t) {
    final wave = math.sin(t * math.pi * 2);
    final wave2 = math.cos(t * math.pi * 2);
    final size = MediaQuery.of(context).size;

    return Stack(
      children: [
        // Top-right: blue/cyan glow
        Positioned(
          top: -size.height * 0.16 + wave * 14,
          right: -size.width * 0.22 + wave2 * 18,
          child: _orb(
            size.width * 0.86,
            const [
              Color(0xFF3B82F6),
              Color(0xFF22D3EE),
              Color(0xFF1B2038),
            ],
            0.85,
            0.5,
          ),
        ),

        // Bottom-left: purple/indigo glow
        Positioned(
          bottom: -size.height * 0.20 - wave * 16,
          left: -size.width * 0.26 - wave2 * 20,
          child: _orb(
            size.width * 0.94,
            const [
              Color(0xFFA855F7),
              Color(0xFF6366F1),
              Color(0xFF1B2038),
            ],
            0.8,
            0.8,
          ),
        ),

        // Small purple accent glow, mid-right
        Positioned(
          top: size.height * 0.34 + wave2 * 22,
          right: -size.width * 0.16,
          child: _orb(
            size.width * 0.46,
            const [
              Color(0xFFA855F7),
              Color(0xFF6366F1),
              Color(0xFF1B2038),
            ],
            0.5,
            1.0,
          ),
        ),
      ],
    );
  }

  Widget _orb(
    double diameter,
    List<Color> colors,
    double centerAlpha,
    double edgeAlpha,
  ) {
    return IgnorePointer(
      child: Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              colors[0].withValues(alpha: centerAlpha),
              colors[1].withValues(alpha: centerAlpha * 0.45),
              colors[2].withValues(alpha: edgeAlpha * 0.0),
            ],
            stops: const [0.0, 0.55, 1.0],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo(double logoSize) {
    return FadeTransition(
      opacity: _logoOpacity,
      child: ScaleTransition(
        scale: _logoScale,
        child: AnimatedBuilder(
          animation: _floatController,
          builder: (context, child) {
            final v = _floatController.value;
            final lift = -8.0 * math.sin(v * math.pi);
            final glow = 0.30 + 0.22 * math.sin(v * math.pi);

            return Transform.translate(
              offset: Offset(0, lift),
              child: Container(
                width: logoSize,
                height: logoSize,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(logoSize * 0.26),
                  boxShadow: [
                    BoxShadow(
                      color: _SplashPalette.purple
                          .withValues(alpha: glow * 0.55),
                      blurRadius: 52,
                      spreadRadius: 4,
                    ),
                    BoxShadow(
                      color: _SplashPalette.cyan
                          .withValues(alpha: glow * 0.40),
                      blurRadius: 72,
                      spreadRadius: -4,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(logoSize * 0.26),
                  child: Image.asset(
                    _kLogoAsset,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTitle(double titleSize) {
    final baseStyle = TextStyle(
      color: Colors.white,
      fontSize: titleSize,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.5,
      height: 1.1,
    );

    return FadeTransition(
      opacity: _titleOpacity,
      child: SlideTransition(
        position: _titleSlide,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            // "Mody" — white
            Text('Mody', style: baseStyle),
            // "Chat" — animated blue/cyan -> purple gradient
            AnimatedBuilder(
              animation: _shimmerController,
              builder: (context, child) {
                final t = _shimmerController.value;
                final start = -1.8 + 2.6 * t;
                return ShaderMask(
                  blendMode: BlendMode.srcIn,
                  shaderCallback: (bounds) => LinearGradient(
                    begin: Alignment(start, 0),
                    end: Alignment(start + 1.8, 0),
                    colors: const [
                      _SplashPalette.cyan,
                      _SplashPalette.indigo,
                      _SplashPalette.shine,
                      _SplashPalette.indigo,
                      _SplashPalette.purple,
                    ],
                    stops: const [0.0, 0.36, 0.5, 0.64, 1.0],
                  ).createShader(bounds),
                  child: child,
                );
              },
              child: Text('Chat', style: baseStyle),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagline() {
    return FadeTransition(
      opacity: _taglineOpacity,
      // child: const Text(
      //   'Simple. Secure. Real-Time Chat.',
      //   textAlign: TextAlign.center,
      //   style: TextStyle(
      //     color: Color(0xFFD6DEF7),
      //     fontSize: 15,
      //     fontWeight: FontWeight.w500,
      //     letterSpacing: 0.6,
      //     height: 1.3,
      //   ),
      // ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 36),
      child: FadeTransition(
        opacity: _loaderOpacity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Small premium blue/purple gradient ring loader
            RotationTransition(
              turns: _spinController,
              child: SizedBox(
                width: 26,
                height: 26,
                child: CustomPaint(
                  painter: _GradientRingPainter(),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'from ModyTech',
              style: TextStyle(
                color: Color(0xFF8E97B8),
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small circular gradient loader — replaces the default
/// CircularProgressIndicator. The gradient lives in the paint shader, so the
/// ring itself is a single smooth blue -> cyan -> purple sweep.
class _GradientRingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: math.pi * 1.5,
        colors: const [
          _SplashPalette.cyan,
          _SplashPalette.blue,
          _SplashPalette.indigo,
          _SplashPalette.purple,
          _SplashPalette.cyan,
        ],
        stops: const [0.0, 0.28, 0.55, 0.8, 1.0],
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(Offset.zero & size);

    final rect = Offset.zero & size;
    canvas.drawArc(
      rect.deflate(1.5),
      0,
      math.pi * 2,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
