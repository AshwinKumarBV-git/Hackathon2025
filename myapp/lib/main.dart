import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'camera_screen.dart';
import 'pdf_screen.dart';
import 'screens/accessibility_demo_screen.dart';

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
          seedColor: Colors.blue,
          brightness: Brightness.light,
          primary: Colors.blue,
          onPrimary: Colors.white,
          secondary: Colors.orange,
          onSecondary: Colors.black,
          background: Colors.white,
        ),
        useMaterial3: true,
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          bodyMedium: TextStyle(fontSize: 20),
        ),
      ),
      home: const HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  
  Widget _buildAccessibleButton({
    required String text, 
    required IconData icon, 
    required Color color, 
    required VoidCallback onPressed,
    required String semanticLabel,
    required String semanticHint,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: SizedBox(
        width: double.infinity,
        height: 100,
        child: Semantics(
          label: semanticLabel,
          hint: semanticHint,
          button: true,
          enabled: true,
          onTap: onPressed,
          child: ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: color == Colors.yellow ? Colors.black : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 8,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 36),
                const SizedBox(width: 16),
                Text(
                  text,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'STEM Assist',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: Container(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Semantics(
              header: true,
              label: 'What would you like to do?',
              child: Text(
                'What would you like to do?',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 36),
            _buildAccessibleButton(
              text: 'Capture Image',
              icon: Icons.camera_alt,
              color: Colors.blue,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CameraScreen()),
                );
              },
              semanticLabel: 'Capture Image',
              semanticHint: 'Opens camera interface to capture or select an image for analysis',
            ),
            _buildAccessibleButton(
              text: 'Import PDF',
              icon: Icons.picture_as_pdf,
              color: Colors.red,
              onPressed: () {
                // PDF import functionality would be implemented here
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PDFImportScreen()),
                );
              },
              semanticLabel: 'Import PDF',
              semanticHint: 'Opens file picker to select and process a PDF document',
            ),
            _buildAccessibleButton(
              text: 'Get Help',
              icon: Icons.help,
              color: Colors.green,
              onPressed: () {
                // Help functionality would be implemented here
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AccessibilityDemoScreen()),
                );
              },
              semanticLabel: 'Get Help',
              semanticHint: 'Opens help and instructions for using the application',
            ),
          ],
        ),
      ),
    );
  }
}
