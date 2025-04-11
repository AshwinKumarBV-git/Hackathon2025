import 'dart:io';
import 'package:http/http.dart' as http;

class ApiService {
  // Singleton pattern
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal() {
    // Print the base URL when service is initialized
    print("🌐 API Service baseUrl: $baseUrl");
  }

  // Server configuration
  static String get baseUrl {
    String url;
    
    // Smart detection for environment
    if (Platform.isAndroid) {
      // For Android emulator
      if (isEmulator()) {
        // 10.0.2.2 is the special IP for Android emulator to reach host
        url = 'http://10.0.2.2:8000';
        print("📱 Running on Android emulator, using host IP: $url");
        return url;
      }
    }
    
    // For physical devices or desktop testing, use your network IP
    // Make sure this is the correct IP address of your backend server
    url = "http://192.168.0.102:8000";
    // Uncomment and modify this line if you need to use a different IP
    // url = "http://10.0.1.15:8000";  // Example of a different IP address
    
    print("📱 Running on physical device or desktop, using network IP: $url");
    return url;
  }
  
  // Helper to detect if running in an emulator (not perfect but helps)
  static bool isEmulator() {
    // This is a simple heuristic and might not work for all emulators
    if (Platform.isAndroid) {
      return Platform.operatingSystemVersion.contains('sdk')
          || Platform.operatingSystemVersion.contains('emulator');
    }
    return false;
  }

  // API endpoints
  static String get uploadEndpoint => '$baseUrl/upload';
  static String get pdfUploadEndpoint => '$baseUrl/pdf-upload';
  static String get explainEndpoint => '$baseUrl/explain';
  
  // Math image processing endpoints
  static String get mathEquationEndpoint => '$baseUrl/process-math-image';
  static String get mathPlotEndpoint => '$baseUrl/process-plot-image';
  
  // Debug method to test connectivity
  static Future<bool> testConnection() async {
    try {
      print("🔌 Testing connection to: $baseUrl");
      final response = await http.get(Uri.parse(baseUrl));
      print("🔌 Connection test result: ${response.statusCode}");
      return response.statusCode == 200;
    } catch (e) {
      print("🔌 Connection test failed: $e");
      return false;
    }
  }
} 