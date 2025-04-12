import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'dart:ui';
import 'camera_screen.dart';
import 'pdf_screen.dart';
import 'screens/accessibility_demo_screen.dart';
import 'math_screen.dart';
import 'eye_splash_screen.dart';

void main() {
  runApp(const STEMAssistApp());
}

class STEMAssistApp extends StatelessWidget {
  const STEMAssistApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'STEM Assist',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark, // Using dark theme for better contrast
          primary: Colors.deepPurpleAccent,
          onPrimary: Colors.white,
          secondary: Colors.amberAccent,
          onSecondary: Colors.black,
          background: Colors.grey.shade900, // Dark background
        ),
        useMaterial3: true,
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          bodyMedium: TextStyle(fontSize: 22),
        ),
      ),
      home: const EyeSplashScreen(),
      routes: {
        '/home': (context) => const HomePage(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  final PageController _pageController = PageController();
  int _currentPage = 0;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this, 
      duration: const Duration(seconds: 20),
    )..repeat(reverse: true);
    
    // Set up accessibility announcement for swipe navigation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SemanticsService.announce(
        "Swipe right to access Math Assistant screen",
        TextDirection.ltr,
      );
    });
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _navigateToPage(int page) {
    if (page == 1) {
      Navigator.pushReplacement(
        context, 
        MaterialPageRoute(builder: (context) => const MathScreen())
      );
      SemanticsService.announce(
        "Navigating to Math Assistant",
        TextDirection.ltr,
      );
    }
  }

  Widget _buildAccessibleButton({
    required String text,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    required String semanticLabel,
    required String semanticHint,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15.0, horizontal: 24.0),
      child: SizedBox(
        width: double.infinity,
        height: 120,
        child: Semantics(
          label: semanticLabel,
          hint: semanticHint,
          button: true,
          enabled: true,
          onTap: onPressed,
          child: Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001) // Perspective effect
              ..rotateX(0.01 * _animationController.value),
            alignment: Alignment.center,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        color.withOpacity(0.3),
                        color.withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 2.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.5),
                        blurRadius: 15,
                        spreadRadius: -5,
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onPressed,
                      splashColor: Colors.white.withOpacity(0.2),
                      hoverColor: Colors.transparent,
                      highlightColor: Colors.white.withOpacity(0.1),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              icon, 
                              size: 42,
                              color: Colors.white.withOpacity(0.9),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                text,
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white.withOpacity(0.9),
                                  shadows: [
                                    Shadow(
                                      color: color.withOpacity(0.5),
                                      blurRadius: 10,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Semantics(
          header: true,
          label: 'STEM Assist Home Page',
          child: const Text(
            'STEM Assist',
            style: TextStyle(
              fontSize: 32, 
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(
                  color: Colors.black54,
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.deepPurple.withOpacity(0.3),
                    Colors.deepPurple.withOpacity(0.1),
                  ],
                ),
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withOpacity(0.2),
                    width: 1,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity! > 0) {
            // Navigate to Math Assistant
            _navigateToPage(1);
            SemanticsService.announce(
              "Swiped right, navigating to Math Assistant",
              TextDirection.ltr,
            );
          }
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.deepPurple.shade900,
                Colors.black,
              ],
            ),
          ),
          child: SafeArea(
            child: Stack(
              children: [
                // Animated background particles
                ...List.generate(12, (index) {
                  final size = 100.0 + (index * 15);
                  return AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      final xOffset = index % 2 == 0 
                          ? _animationController.value * 20 
                          : -_animationController.value * 30;
                      final yOffset = _animationController.value * 15;
                      
                      return Positioned(
                        left: (index * 30) + xOffset - size/2,
                        top: (index * 40) + yOffset - size/2,
                        child: Container(
                          width: size,
                          height: size,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                Colors.deepPurple.withOpacity(0.2),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                }),
                
                // Content
                SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: MediaQuery.of(context).size.height - 
                                MediaQuery.of(context).padding.top - 
                                kToolbarHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 16),
                            Semantics(
                              label: 'Swipe right to navigate to Math Assistant',
                              hint: 'Accessibility navigation option',
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 16),
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                decoration: BoxDecoration(
                                  color: Colors.purple.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.swipe_right_alt,
                                      color: Colors.white70,
                                      size: 28,
                                    ),
                                    const SizedBox(width: 12),
                                    const Text(
                                      'Swipe right for Math Assistant',
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Colors.white70,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            
                            // Put buttons in a column with evenly distributed spacing
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  _buildAccessibleButton(
                                    text: 'Capture Image',
                                    icon: Icons.camera_alt,
                                    color: Colors.blueAccent,
                                    onPressed: () {
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(builder: (context) => const CameraScreen()),
                                      );
                                      SemanticsService.announce(
                                        "Opens Capture Image screen",
                                        TextDirection.ltr,
                                      );
                                    },
                                    semanticLabel: 'Capture Image',
                                    semanticHint: 'Opens camera interface to capture or select an image for analysis',
                                  ),
                                  
                                  _buildAccessibleButton(
                                    text: 'Import PDF',
                                    icon: Icons.picture_as_pdf,
                                    color: Colors.redAccent,
                                    onPressed: () {
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(builder: (context) => const PDFImportScreen()),
                                      );
                                      SemanticsService.announce(
                                        "Opens Import PDF screen",
                                        TextDirection.ltr,
                                      );
                                    },
                                    semanticLabel: 'Import PDF',
                                    semanticHint: 'Opens file picker to select and process a PDF document',
                                  ),
                                  
                                  _buildAccessibleButton(
                                    text: 'Get Help',
                                    icon: Icons.help_outline,
                                    color: Colors.greenAccent,
                                    onPressed: () {
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(builder: (context) => const AccessibilityDemoScreen()),
                                      );
                                      SemanticsService.announce(
                                        "Opens Get Help screen",
                                        TextDirection.ltr,
                                      );
                                    },
                                    semanticLabel: 'Get Help',
                                    semanticHint: 'Opens help and instructions for using the application',
                                  ),
                                ],
                              ),
                            ),
                            
                            // Add decorative element at bottom
                            Container(
                              margin: const EdgeInsets.only(top: 16),
                              height: 40,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(30),
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.white.withOpacity(0.1),
                                              Colors.white.withOpacity(0.05),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(30),
                                        ),
                                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.swipe, color: Colors.white54, size: 20),
                                            SizedBox(width: 8),
                                            Text(
                                              'STEM Assist',
                                              style: TextStyle(
                                                color: Colors.white54,
                                                fontWeight: FontWeight.w500,
                                                fontSize: 14,
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
                          ],
                        ),
                      ),
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