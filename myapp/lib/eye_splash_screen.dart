import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:ui' as ui; // Needed for ImageFilter
import 'package:vector_math/vector_math_64.dart' show radians; // Add dependency: vector_math
import 'main.dart'; // Import main.dart for HomePage reference

class EyeSplashScreen extends StatefulWidget {
  const EyeSplashScreen({super.key});

  @override
  State<EyeSplashScreen> createState() => _EyeSplashScreenState();
}

class _EyeSplashScreenState extends State<EyeSplashScreen> with TickerProviderStateMixin {
  // Animation controllers
  late AnimationController _blinkController;
  late AnimationController _focusController;
  late AnimationController _fadeController;
  late AnimationController _rotateController; // For 3D rotation
  late AnimationController _scanLineController; // For scan line effect
  late AnimationController _particleController; // For background particles

  // Animations
  late Animation<double> _blinkAnimation;
  late Animation<double> _focusAnimation; // Can be used for pulsing iris
  late Animation<double> _fadeAnimation;
  late Animation<double> _rotateAnimation;
  late Animation<double> _scanLineAnimation;

  // Particle data
  final List<Particle> particles = [];
  final int numberOfParticles = 30;

  @override
  void initState() {
    super.initState();

    // Initialize controllers
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000), // Faster fade in
    );
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250), // Faster blink
    );
    _focusController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500), // Rotation duration
    );
    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000), // Scan line sweep time
    );
     _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15), // Slow particle movement
    )..repeat(); // Particles move continuously


    // Setup animations
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );
    _blinkAnimation = Tween<double>(begin: 1.0, end: 0.05).animate( // Blink almost closed
      CurvedAnimation(parent: _blinkController, curve: Curves.easeInOut),
    );
    _focusAnimation = Tween<double>(begin: 0.7, end: 1.0).animate( // Iris pulse/focus
      CurvedAnimation(parent: _focusController, curve: Curves.elasticOut), // Bouncier focus
    );
     _rotateAnimation = Tween<double>(begin: 0.0, end: radians(15.0)).animate( // Rotate 15 degrees on Y
      CurvedAnimation(parent: _rotateController, curve: Curves.easeInOutSine),
    );
    _scanLineAnimation = Tween<double>(begin: -0.1, end: 1.1).animate( // From above top to below bottom
       CurvedAnimation(parent: _scanLineController, curve: Curves.linear),
    );


    // Initialize particles
    final random = math.Random();
    final screenWidth = MediaQueryData.fromView(ui.PlatformDispatcher.instance.views.first).size.width;
    final screenHeight = MediaQueryData.fromView(ui.PlatformDispatcher.instance.views.first).size.height;
    for (int i = 0; i < numberOfParticles; i++) {
      particles.add(Particle(
        position: Offset(random.nextDouble() * screenWidth, random.nextDouble() * screenHeight),
        radius: random.nextDouble() * 1.5 + 0.5, // Small particles
        color: Colors.cyan.withOpacity(random.nextDouble() * 0.3 + 0.1),
        speed: Offset((random.nextDouble() - 0.5) * 0.5, (random.nextDouble() - 0.5) * 0.5), // Slow random speed
      ));
    }


    // Start animation sequence
    _startAnimationSequence();

    // Navigate to home screen after animation completes
    // Increased duration to allow for more complex animation
    Future.delayed(const Duration(milliseconds: 4500), () {
      // Fix navigation issues by checking mount state and using try-catch
      if (mounted) {
        try {
          Navigator.of(context).pushReplacementNamed('/home');
        } catch (e) {
          // Fallback if named route fails
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) {
              // Import the HomePage class directly to avoid circular dependencies
              return const HomePage();
            }),
          );
        }
      }
    });
  }

  void _startAnimationSequence() async {
    // Initial fade in and rotate
    await Future.wait([
       _fadeController.forward(),
       _rotateController.forward(),
    ]);

    // Start scan line after fade/rotate start
    _scanLineController.repeat(); // Loop the scan line

    await Future.delayed(const Duration(milliseconds: 300));

    // First blink
    await _blinkController.forward();
    await _blinkController.reverse();
    await Future.delayed(const Duration(milliseconds: 400));

    // Second blink (quicker)
    await _blinkController.forward();
    await _blinkController.reverse();

    // Iris focusing/pulsing
    await Future.delayed(const Duration(milliseconds: 100));
    _focusController.forward(); // Start focus/pulse

    // Optionally make focus pulse:
    // _focusController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _blinkController.dispose();
    _focusController.dispose();
    _fadeController.dispose();
    _rotateController.dispose();
    _scanLineController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final shortestSide = size.shortestSide * 0.65; // Slightly larger eye
    final eyeHeight = shortestSide * 0.5; // Maintain aspect ratio

    return Scaffold(
      backgroundColor: Colors.black, // Darker background
      body: Stack( // Use Stack for background particles
        children: [
          // Particle Layer
          AnimatedBuilder(
            animation: _particleController,
            builder: (context, child) {
              // Update particle positions (simple linear movement with wrap around)
              for (var p in particles) {
                p.position += p.speed * _particleController.value * 10; // Adjust multiplier for speed
                // Basic wrap around logic
                if (p.position.dx < 0) p.position = Offset(size.width, p.position.dy);
                if (p.position.dx > size.width) p.position = Offset(0, p.position.dy);
                if (p.position.dy < 0) p.position = Offset(p.position.dx, size.height);
                if (p.position.dy > size.height) p.position = Offset(p.position.dx, 0);
              }
              return CustomPaint(
                size: size,
                painter: ParticlePainter(particles: particles),
              );
            }
          ),

          // Eye Layer
          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: AnimatedBuilder(
                animation: _rotateAnimation,
                builder: (context, child) {
                   // Apply 3D perspective rotation
                   return Transform(
                     alignment: Alignment.center,
                     transform: Matrix4.identity()
                       ..setEntry(3, 2, 0.001) // Perspective
                       ..rotateY(_rotateAnimation.value),
                     child: child,
                   );
                },
                child: Container( // Container for sizing and potential background glow
                  width: shortestSide,
                  height: eyeHeight,
                   // Optional outer glow for the whole eye area
                   // decoration: BoxDecoration(boxShadow: [
                   //   BoxShadow(
                   //     color: Colors.purpleAccent.withOpacity(0.3),
                   //     blurRadius: 50,
                   //     spreadRadius: 10,
                   //   )
                   // ]),
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none, // Allow overflow for glow?
                    children: [
                      // The eye shape (sclera) - Animated
                      AnimatedBuilder(
                        animation: _blinkAnimation,
                        builder: (context, child) {
                          return CustomPaint(
                            size: Size(shortestSide, eyeHeight),
                            painter: FuturisticEyePainter(
                              openRatio: _blinkAnimation.value,
                              glowColor: Colors.cyanAccent,
                            ),
                          );
                        },
                      ),

                      // The iris and pupil - Animated
                      AnimatedBuilder(
                        animation: Listenable.merge([_blinkAnimation, _focusAnimation]),
                        builder: (context, child) {
                          final currentFocus = _focusAnimation.value;
                          final irisSize = shortestSide * 0.4 * currentFocus;
                           // Make iris/pupil disappear when blinked
                          final opacity = (_blinkAnimation.value > 0.1) ? 1.0 : _blinkAnimation.value * 10;

                          return Opacity(
                             opacity: opacity,
                             child: Container(
                               width: irisSize,
                               height: irisSize,
                               decoration: BoxDecoration(
                                 shape: BoxShape.circle,
                                 gradient: RadialGradient(
                                   colors: [
                                     Colors.cyanAccent.withOpacity(0.8), // Bright center
                                     Colors.blueAccent.shade700,       // Mid color
                                     Colors.deepPurple.shade900,       // Dark edge
                                   ],
                                   stops: const [0.0, 0.6, 1.0],
                                 ),
                                 boxShadow: [
                                   // Inner glow
                                   BoxShadow(
                                     color: Colors.cyanAccent.withOpacity(0.7),
                                     blurRadius: irisSize * 0.3,
                                     spreadRadius: irisSize * 0.05,
                                   ),
                                   // Outer faint glow
                                   BoxShadow(
                                     color: Colors.purpleAccent.withOpacity(0.5),
                                     blurRadius: irisSize * 0.5,
                                     spreadRadius: 0,
                                   ),
                                 ],
                               ),
                               // Pupil
                               child: Center(
                                 child: Container(
                                   width: irisSize * 0.4, // Pupil size relative to iris
                                   height: irisSize * 0.4,
                                   decoration: BoxDecoration(
                                     shape: BoxShape.circle,
                                     color: Colors.black,
                                      boxShadow: [ // Subtle inner shadow for depth
                                         BoxShadow(
                                           color: Colors.black.withOpacity(0.5),
                                           blurRadius: irisSize * 0.1,
                                           spreadRadius: 1,
                                         ),
                                      ],
                                   ),
                                 ),
                               ),
                             ),
                           );
                        },
                      ),

                       // Scan Line Effect - Needs clipping
                       Positioned.fill(
                         child: ClipPath( // Clip the scan line to the eye shape
                            clipper: EyeShapeClipper(_blinkAnimation), // Use Animation directly
                           child: AnimatedBuilder(
                             animation: _scanLineAnimation,
                             builder: (context, child) {
                               final scanPosition = _scanLineAnimation.value * eyeHeight;
                               // Only show scan line when eye is mostly open
                               final opacity = (_blinkAnimation.value > 0.2) ? (1.0 - (_scanLineAnimation.value - 0.5).abs() * 2).clamp(0.0, 0.5) : 0.0;

                               return Stack(
                                 children: [
                                   Positioned(
                                     left: 0,
                                     right: 0,
                                     top: scanPosition - 1, // Center the line thickness
                                     child: Opacity(
                                       opacity: opacity,
                                       child: Container(
                                         height: 2, // Thickness of scan line
                                         decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.7),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.cyanAccent.withOpacity(0.8),
                                                blurRadius: 4,
                                                spreadRadius: 1,
                                              )
                                            ]
                                         ),
                                       ),
                                     ),
                                   ),
                                 ],
                               );
                             },
                           ),
                         ),
                       ),


                      // App name appearing below the eye
                      Positioned(
                        // Position below the eye container, adjust based on eye size
                        bottom: -eyeHeight * 0.6, // Adjust distance from eye
                        child: AnimatedBuilder(
                          animation: _focusController, // Fade in with focus animation
                          builder: (context, child){
                             // Slight delay and fade based on focus animation progress
                            final focusProgress = Curves.easeOut.transform(_focusController.value);
                            return Opacity(
                              opacity: (focusProgress * 1.5 - 0.5).clamp(0.0, 1.0), // Start fading in later
                              child: child,
                            );
                          },
                          child: Text(
                            'STEM Assist',
                            style: TextStyle(
                              color: Colors.cyanAccent.withOpacity(0.9),
                              fontSize: 26, // Slightly larger font
                              fontWeight: FontWeight.bold,
                              letterSpacing: 3.0,
                              shadows: [ // Neon glow effect for text
                                Shadow(
                                  color: Colors.cyanAccent.withOpacity(0.7),
                                  blurRadius: 10.0,
                                ),
                                Shadow(
                                  color: Colors.blueAccent.withOpacity(0.5),
                                  blurRadius: 15.0,
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
        ],
      ),
    );
  }
}

// Custom painter for the futuristic eye shape (Sclera)
class FuturisticEyePainter extends CustomPainter {
  final double openRatio;
  final Color glowColor;

  FuturisticEyePainter({required this.openRatio, this.glowColor = Colors.cyan});

  @override
  void paint(Canvas canvas, Size size) {
     final width = size.width;
     final height = size.height;

     // Calculate height adjustment based on eye openness
     // Make the closing more pronounced
     final adjustedHeight = height * math.max(0.01, openRatio); // Ensure minimum height
     final verticalOffset = (height - adjustedHeight) / 2;

     final rect = Rect.fromLTWH(0, verticalOffset, width, adjustedHeight);
     final path = Path()..addOval(rect); // Use path for potential clipping/masking


     // 1. Sclera Base (Darker, slightly transparent)
     final scleraPaint = Paint()
       ..color = Colors.deepPurple.shade900.withOpacity(0.5) // Darker base
       ..style = PaintingStyle.fill;
     canvas.drawPath(path, scleraPaint);


     // 2. Inner Glow/Highlight (Subtle)
     final innerGlowPaint = Paint()
       ..shader = RadialGradient(
         center: Alignment.center,
         radius: 0.7,
         colors: [
           Colors.white.withOpacity(0.15 * openRatio),
           Colors.transparent,
         ],
         stops: const [0.0, 1.0],
       ).createShader(rect)
       ..style = PaintingStyle.fill;
     canvas.drawPath(path, innerGlowPaint);


     // 3. Outline Glow
     final outlineGlowPaint = Paint()
       ..color = glowColor.withOpacity(0.8 * openRatio) // Fade glow when closed
       ..style = PaintingStyle.stroke
       ..strokeWidth = 4.0 // Thicker glow base
       ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0); // Blur for glow
     canvas.drawPath(path, outlineGlowPaint);


     // 4. Sharp Outline
     final outlinePaint = Paint()
       ..color = glowColor.withOpacity(0.9 * openRatio) // Fade outline when closed
       ..style = PaintingStyle.stroke
       ..strokeWidth = 1.5; // Sharp edge
     canvas.drawPath(path, outlinePaint);

  }

  @override
  bool shouldRepaint(FuturisticEyePainter oldDelegate) =>
      oldDelegate.openRatio != openRatio || oldDelegate.glowColor != glowColor;
}


// Clipper to constrain the scan line within the animated eye shape
class EyeShapeClipper extends CustomClipper<Path> {
  final Animation<double> blinkAnimation;

  EyeShapeClipper(this.blinkAnimation) : super(reclip: blinkAnimation); // Reclip when animation changes

  @override
  Path getClip(Size size) {
    final width = size.width;
    final height = size.height;
    final openRatio = blinkAnimation.value;

    final adjustedHeight = height * math.max(0.01, openRatio);
    final verticalOffset = (height - adjustedHeight) / 2;

    final rect = Rect.fromLTWH(0, verticalOffset, width, adjustedHeight);
    return Path()..addOval(rect);
  }

  @override
  bool shouldReclip(covariant EyeShapeClipper oldClipper) {
    // No need to compare animation objects themselves if reclip is handled by super
    return true; // Let the listener handle reclipping check
  }
}


// --- Particle Data Structure and Painter ---

class Particle {
  Offset position;
  double radius;
  Color color;
  Offset speed; // Added for movement

  Particle({
    required this.position,
    required this.radius,
    required this.color,
    required this.speed,
  });
}

class ParticlePainter extends CustomPainter {
  final List<Particle> particles;

  ParticlePainter({required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (final particle in particles) {
      paint.color = particle.color;
      canvas.drawCircle(particle.position, particle.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true; // Repaint every frame for animation
}