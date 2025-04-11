import 'package:flutter_tts/flutter_tts.dart';
import 'package:vibration/vibration.dart';

enum ContentType {
  text,
  math,
  graph,
  error,
  success
}

class AccessibilityService {
  // Singleton pattern
  static final AccessibilityService _instance = AccessibilityService._internal();
  factory AccessibilityService() => _instance;
  AccessibilityService._internal();

  final FlutterTts _flutterTts = FlutterTts();
  bool _isSpeaking = false;
  bool _isPaused = false;
  bool _hasVibrator = false;
  bool _initialized = false;

  // Initialize the service
  Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      // Setup TTS
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      
      _flutterTts.setStartHandler(() {
        _isSpeaking = true;
      });
      
      _flutterTts.setCompletionHandler(() {
        _isSpeaking = false;
        _isPaused = false;
      });
      
      _flutterTts.setErrorHandler((message) {
        print("TTS Error: $message");
        _isSpeaking = false;
        _isPaused = false;
      });
      
      // Check for vibration support
      _hasVibrator = await Vibration.hasVibrator() ?? false;
      
      _initialized = true;
    } catch (e) {
      print("Failed to initialize AccessibilityService: $e");
      _initialized = false;
    }
  }
  
  // Get speaking status
  bool get isSpeaking => _isSpeaking;
  bool get isPaused => _isPaused;
  
  // Speak text with optional vibration feedback
  Future<bool> speak(String text, {ContentType contentType = ContentType.text}) async {
    if (!_initialized) {
      await initialize();
    }
    
    try {
      // Stop any ongoing speech
      if (_isSpeaking) {
        await _flutterTts.stop();
        _isSpeaking = false;
        _isPaused = false;
      }
      
      // Vibrate based on content type
      _vibrateByContentType(contentType);
      
      // Speak the text
      if (text.isNotEmpty) {
        await _flutterTts.speak(text);
        return true;
      }
      return false;
    } catch (e) {
      print("TTS Error: $e");
      return false;
    }
  }
  
  // Stop speaking
  Future<bool> stop() async {
    if (!_initialized) return false;
    
    try {
      if (_isSpeaking) {
        await _flutterTts.stop();
        _isSpeaking = false;
        _isPaused = false;
        return true;
      }
      return false;
    } catch (e) {
      print("TTS Error: $e");
      return false;
    }
  }
  
  // Pause or resume speech
  Future<bool> pauseOrResume() async {
    if (!_initialized) return false;
    
    try {
      if (_isSpeaking && !_isPaused) {
        // On Windows, pause() is not supported, so we use stop() instead
        await _flutterTts.stop();
        _isSpeaking = false;
        _isPaused = true;
        return true;
      } else if (_isPaused) {
        // Resume is not directly supported on all platforms, so we re-speak
        // This would require tracking the current text and position
        // For simplicity, this implementation just signals that we should re-speak
        _isPaused = false;
        return true;
      }
      return false;
    } catch (e) {
      print("TTS Error: $e");
      return false;
    }
  }
  
  // Vibrate using different patterns based on content type
  Future<bool> vibrate(ContentType contentType) async {
    if (!_initialized) {
      await initialize();
    }
    
    return _vibrateByContentType(contentType);
  }
  
  bool _vibrateByContentType(ContentType contentType) {
    if (!_hasVibrator) return false;
    
    try {
      switch (contentType) {
        case ContentType.text:
          // Short vibration for text
          Vibration.vibrate(duration: 100);
          break;
        case ContentType.math:
          // Pulsing pattern for math content
          Vibration.vibrate(
            pattern: [100, 100, 100, 100, 200],
            intensities: [128, 0, 128, 0, 255],
          );
          break;
        case ContentType.graph:
          // Long vibration pattern for graphs/charts
          Vibration.vibrate(
            pattern: [100, 200, 300, 200, 100, 500],
            intensities: [50, 100, 150, 200, 255, 0],
          );
          break;
        case ContentType.error:
          // Short strong pulses for errors
          Vibration.vibrate(
            pattern: [50, 100, 50, 100, 50],
            intensities: [255, 0, 255, 0, 255],
          );
          break;
        case ContentType.success:
          // Single medium vibration for success
          Vibration.vibrate(duration: 300, amplitude: 128);
          break;
      }
      return true;
    } catch (e) {
      print("Vibration Error: $e");
      return false;
    }
  }
  
  // Dispose resources
  Future<void> dispose() async {
    if (_isSpeaking) {
      await _flutterTts.stop();
    }
    _isSpeaking = false;
    _isPaused = false;
  }
} 