import 'dart:io';

class ApiService {
  // Singleton pattern
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // Server configuration
  static String get baseUrl {
    // Check if running on Android emulator
    if (Platform.isAndroid) {
      // 10.0.2.2 is the special IP for Android emulator to reach host
      return 'http://10.0.2.2:8000';
    }
    
    // For physical devices, use your computer's actual IP address
    // const String computerIp = '192.168.1.100'; // Change this to your computer's IP
    // return 'http://$computerIp:8000';
    
    // For testing on the same machine (Windows/MacOS/Linux desktop)
    return 'http://127.0.0.1:8000';
  }

  // API endpoints
  static String get uploadEndpoint => '$baseUrl/upload';
  static String get pdfUploadEndpoint => '$baseUrl/pdf-upload';
  static String get explainEndpoint => '$baseUrl/explain';
} 