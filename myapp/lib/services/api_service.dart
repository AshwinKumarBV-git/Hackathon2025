import 'dart:io';

class ApiService {
  // Singleton pattern
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // Server configuration
  static String get baseUrl {
    // Local server on your network
    // Make sure this IP is correct and the server is running
    return "http://192.168.0.102:8000";
    
    // Commented out alternative configurations
    /*
    // For Android emulator
    if (Platform.isAndroid && !Platform.isIOS) {
      // 10.0.2.2 is the special IP for Android emulator to reach host
      return 'http://10.0.2.2:8000';
    }
    
    // For desktop testing (Windows/MacOS/Linux)
    return 'http://127.0.0.1:8000';
    */
  }

  // API endpoints
  static String get uploadEndpoint => '$baseUrl/upload';
  static String get pdfUploadEndpoint => '$baseUrl/pdf-upload';
  static String get explainEndpoint => '$baseUrl/explain';
} 