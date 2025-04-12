import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/api_service.dart';
import 'package:flutter/services.dart';

class AccessibilityDemoScreen extends StatefulWidget {
  const AccessibilityDemoScreen({Key? key}) : super(key: key);

  @override
  State<AccessibilityDemoScreen> createState() => _AccessibilityDemoScreenState();
}

class _AccessibilityDemoScreenState extends State<AccessibilityDemoScreen> {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isSpeaking = false;
  bool _isLoading = false;
  String _statusMessage = '';
  bool _isUrgent = false;

  @override
  void initState() {
    super.initState();
    _initTts();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _speak("Help screen opened. Tap the large button to send a help request.");
    });
  }

  Future<void> _initTts() async {
    try {
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setSpeechRate(0.45);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      
      _flutterTts.setStartHandler(() {
        setState(() => _isSpeaking = true);
      });
      
      _flutterTts.setCompletionHandler(() {
        setState(() => _isSpeaking = false);
      });
      
      _flutterTts.setErrorHandler((message) {
        setState(() => _isSpeaking = false);
        print("TTS Error: $message");
      });
    } catch (e) {
      print("TTS initialization error: $e");
    }
  }

  Future<void> _speak(String text) async {
    if (_isSpeaking) {
      await _flutterTts.stop();
      await Future.delayed(const Duration(milliseconds: 300));
    }
    
    if (text.isNotEmpty) {
      await _flutterTts.speak(text);
    }
  }

  Future<void> _stopSpeaking() async {
    if (_isSpeaking) {
      await _flutterTts.stop();
      setState(() => _isSpeaking = false);
    }
  }

  Future<void> _sendHelpRequest() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Sending help request...';
    });
    
    // Speak with specific timing to ensure user knows what's happening
    _speak("Sending help request. Please wait.");
    
    // Small delay to ensure TTS finishes before network activity
    await Future.delayed(const Duration(milliseconds: 1500));

    try {
      // Create request payload with default message
      final payload = {
        'user_name': 'User',
        'location': 'Unknown',
        'message': 'Your friend needs your help',
        'urgent': _isUrgent,
      };

      print("Sending help request to: ${ApiService.helpSmsEndpoint}");
      print("Request payload: $payload");
      
      // Send request to API
      final response = await http.post(
        Uri.parse(ApiService.helpSmsEndpoint),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      print("Response status code: ${response.statusCode}");
      print("Response body: ${response.body}");
      
      setState(() {
        _isLoading = false;
      });

      final data = jsonDecode(response.body);
      final bool success = data['success'] ?? false;
      final String message = data['message'] ?? 'Unknown response from server';
      
      setState(() {
        _statusMessage = message;
      });
      
      if (success) {
        // Provide haptic feedback first
        HapticFeedback.heavyImpact();
        
        // Short delay before speaking success message
        await Future.delayed(const Duration(milliseconds: 500));
        _speak("Your help request was sent successfully. Assistance is on the way.");
      } else {
        // Vibration for error
        HapticFeedback.vibrate();
        
        // Clean up the error message for TTS
        String cleanMessage = message.replaceAll(RegExp(r'\[.*?\]'), ''); // Remove color codes
        cleanMessage = cleanMessage.replaceAll(RegExp(r'https?:\/\/\S+'), ''); // Remove URLs
        
        // Get a simplified message for TTS
        String ttsMessage = "Failed to send help request.";
        
        if (message.contains("Authentication failed") || 
            message.contains("not properly configured")) {
          ttsMessage = "The help system is not properly set up. Please contact support.";
        } else if (message.contains("verified")) {
          ttsMessage = "The help system is in test mode and cannot send messages to your contact.";
        }
        
        // Short delay before speaking error message
        await Future.delayed(const Duration(milliseconds: 500));
        _speak(ttsMessage);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Network error: Unable to connect to server';
      });
      
      // Vibration for error
      HapticFeedback.vibrate();
      
      // Short delay before speaking error message
      await Future.delayed(const Duration(milliseconds: 500));
      _speak("Error connecting to server. Please check your internet connection and try again.");
      print("Error sending help request: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Get Help'),
        backgroundColor: Colors.greenAccent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            _stopSpeaking();
            _speak("Returning to home screen");
            Navigator.pushReplacementNamed(context, '/home');
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Semantics(
                  header: true,
                  label: 'Emergency Help Request',
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.green, width: 3),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.support_agent,
                          size: 70,
                          color: Colors.green.shade700,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Request Assistance',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Tap the button below to send an emergency help request',
                          style: TextStyle(
                            fontSize: 20,
                            color: Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 30),
                
                // Urgent checkbox
                Semantics(
                  label: 'Urgent request checkbox',
                  hint: 'Mark as urgent if you need immediate assistance',
                  child: CheckboxListTile(
                    title: const Text(
                      'This is an URGENT request',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    value: _isUrgent,
                    onChanged: (value) {
                      setState(() {
                        _isUrgent = value ?? false;
                      });
                      if (_isUrgent) {
                        _speak("Marked as urgent request");
                      } else {
                        _speak("Unmarked as urgent request");
                      }
                    },
                    activeColor: Colors.red,
                    checkColor: Colors.white,
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  ),
                ),
                
                const SizedBox(height: 30),
                
                // Submit button - Much larger for easy access
                Semantics(
                  label: 'Send help request button',
                  hint: 'Double tap to send your emergency help request',
                  button: true,
                  enabled: !_isLoading,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _sendHelpRequest,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 25),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      minimumSize: const Size(double.infinity, 110),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 4.0)
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.emergency, size: 50),
                              const SizedBox(height: 12),
                              Text(
                                'SEND HELP REQUEST',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  shadows: [
                                    Shadow(
                                      blurRadius: 6,
                                      color: Colors.black.withOpacity(0.5),
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                
                const SizedBox(height: 25),
                
                // Status message
                if (_statusMessage.isNotEmpty)
                  Semantics(
                    label: 'Status: $_statusMessage',
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _statusMessage.contains('success')
                            ? Colors.green.withOpacity(0.2)
                            : Colors.red.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _statusMessage.contains('success')
                              ? Colors.green
                              : Colors.red,
                          width: 2,
                        ),
                      ),
                      child: Text(
                        _statusMessage,
                        style: TextStyle(
                          fontSize: 20,
                          color: _statusMessage.contains('success')
                              ? Colors.green.shade800
                              : Colors.red.shade800,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }
} 