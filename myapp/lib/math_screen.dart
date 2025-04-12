import 'package:flutter/material.dart';
import 'package:flutter/services.dart';  // Add this import for HapticFeedback
import 'package:flutter_tts/flutter_tts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:vibration/vibration.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:convert';
import 'services/api_service.dart';

class MathScreen extends StatefulWidget {
  const MathScreen({super.key});

  @override
  State<MathScreen> createState() => _MathScreenState();
}

class _MathScreenState extends State<MathScreen> {
  final FlutterTts _flutterTts = FlutterTts();
  final ImagePicker _picker = ImagePicker();

  // Image files for equation and plot
  File? _equationImage;
  File? _plotImage;

  // Loading state indicators
  bool _isEquationLoading = false;
  bool _isPlotLoading = false;
  bool _isProcessing = false;
  bool _isSpeaking = false;

  // Response data
  String _responseText = '';
  bool _hasResponse = false;

  // TTS settings
  double _speechRate = 0.5;
  double _speechPitch = 1.0;

  @override
  void initState() {
    super.initState();
    _initTts();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _speak("Math Assistant screen opened. You can analyze math equations or plots from images.");

      // Test the connection to the backend server
      _testBackendConnection();
    });
  }

  Future<void> _initTts() async {
    try {
      print("Initializing TTS...");
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setSpeechRate(_speechRate);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(_speechPitch);

      // Add TTS completion and error handlers
      _flutterTts.setCompletionHandler(() {
        setState(() => _isSpeaking = false);
        print("TTS completed");
      });

      _flutterTts.setErrorHandler((msg) {
        setState(() => _isSpeaking = false);
        print("TTS error: $msg");
      });

      // Set start handler
      _flutterTts.setStartHandler(() {
        setState(() => _isSpeaking = true);
      });

      print("TTS initialized successfully");
    } catch (e) {
      print("TTS initialization error: $e");
    }
  }

  Future<void> _speak(String text) async {
    try {
      print("Speaking text: $text");
      await _flutterTts.stop();
      await _flutterTts.setSpeechRate(_speechRate);
      await _flutterTts.setPitch(_speechPitch);
      await _flutterTts.speak(text);
      setState(() => _isSpeaking = true);
    } catch (e) {
      print("TTS Error: $e");
    }
  }

  Future<void> _stopSpeaking() async {
    if (_isSpeaking) {
      await _flutterTts.stop();
      setState(() => _isSpeaking = false);
    }
  }

  Future<void> _adjustSpeechRate(double rate) async {
    setState(() => _speechRate = rate);
    await _flutterTts.setSpeechRate(rate);
    if (_isSpeaking) {
      // Restart speaking with new rate
      await _flutterTts.stop();
      await _speak(_responseText);
    }
  }

  // Method to show image source selection dialog
  Future<ImageSource?> _showImageSourceDialog(String purpose) async {
    _speak("Would you like to use the camera or select from gallery?");

    return showDialog<ImageSource>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          semanticLabel: "Choose image source for $purpose",
          title: Text("Choose Image Source for $purpose"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                button: true,
                label: "Use Camera",
                child: ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: const Text("Take a Photo"),
                  onTap: () {
                    Navigator.of(context).pop(ImageSource.camera);
                  },
                ),
              ),
              Semantics(
                button: true,
                label: "Select from Gallery",
                child: ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text("Choose from Gallery"),
                  onTap: () {
                    Navigator.of(context).pop(ImageSource.gallery);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Method to analyze math image with the backend API
  Future<void> _analyzeMathImage(File imageFile, String type) async {
    try {
      // Clear any previous response data
      setState(() {
        _isProcessing = true;
        _responseText = '';
        _hasResponse = false;
        _stopSpeaking();
      });

      _speak("Processing ${type.toLowerCase()} image. Please wait...");

      // Define the API endpoint based on image type
      final String endpoint = type == "Equation"
          ? ApiService.mathEquationEndpoint
          : ApiService.mathPlotEndpoint;

      print("🔍 DEBUG: Sending request to endpoint: $endpoint");
      print("🔍 DEBUG: Image file path: ${imageFile.path}");
      print("🔍 DEBUG: Image file size: ${await imageFile.length()} bytes");
      
      // Get file extension for proper content type
      final String extension = imageFile.path.split('.').last.toLowerCase();
      final String contentType = extension == 'png' 
          ? 'image/png' 
          : (extension == 'jpg' || extension == 'jpeg') 
              ? 'image/jpeg' 
              : 'application/octet-stream';
      
      print("🔍 DEBUG: File extension: $extension, Content-Type: $contentType");
      
      // Create multipart request
      var request = http.MultipartRequest('POST', Uri.parse(endpoint));
      
      // Add the image file with proper content type
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          imageFile.path,
          filename: '${type.toLowerCase()}_image.$extension',
          contentType: MediaType.parse(contentType),
        ),
      );

      // Add additional headers if needed
      request.headers['Accept'] = 'application/json';

      print("🔍 DEBUG: Request prepared, sending...");

      // Send the request
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      print("🔍 DEBUG: Response status: ${response.statusCode}");
      print("🔍 DEBUG: Response headers: ${response.headers}");
      print("🔍 DEBUG: Response body: ${response.body}");

      setState(() {
        _isProcessing = false;
      });

      if (response.statusCode == 200) {
        try {
          // Parse the JSON response
          final Map<String, dynamic> data = jsonDecode(response.body);
          print("🔍 DEBUG: Parsed JSON data: $data");

          // Check if the response has the success flag
          final bool success = data['success'] ?? true;
          final String explanation = data['explanation'] ?? 'No explanation provided';
          final String? latex = data['latex'];
          final double confidence = (data['confidence'] as num?)?.toDouble() ?? 0.0;
          final String? errorMsg = data['error'];

          print("🔍 DEBUG: Success: $success, Confidence: $confidence");
          print("🔍 DEBUG: Has LaTeX: ${latex != null}, Has error: ${errorMsg != null}");

          if (success) {
            // Build a more accessible response text
            String formattedResponse = explanation;

            // If LaTeX is present, include it in a way that's accessible but separate
            if (latex != null && latex.isNotEmpty) {
              formattedResponse += "\n\nLaTeX representation:\n$latex";
            }

            // If confidence is present, include it
            if (confidence > 0) {
              String confidenceLevel = confidence > 0.8 ? "high" : (confidence > 0.5 ? "medium" : "low");
              formattedResponse += "\n\nConfidence level: $confidenceLevel (${(confidence * 100).round()}%)";
            }

            setState(() {
              _responseText = formattedResponse;
              _hasResponse = true;
            });

            // Provide haptic and auditory feedback for success
            if (await Vibration.hasVibrator() ?? false) {
              Vibration.vibrate(pattern: [0, 100, 50, 100]);
            }

            // Add a slight delay before speaking to ensure UI is updated
            await Future.delayed(const Duration(milliseconds: 300));

            // Speak the explanation without the LaTeX part for better TTS experience
            _speak("Analysis complete. $explanation");
          } else {
            // Handle error case when success is false but status code is 200
            setState(() {
              _responseText = errorMsg ?? "The analysis could not be completed successfully.";
              _hasResponse = true;
            });
            _speak("The analysis could not be completed successfully. ${errorMsg ?? ''}");
          }
        } catch (e) {
          setState(() {
            _responseText = "Error parsing response: $e";
            _hasResponse = true;
          });
          _speak("There was a problem understanding the server's response.");
          print("JSON parsing error: $e");
        }
      } else {
        setState(() {
          _responseText = "Error ${response.statusCode}: ${response.reasonPhrase ?? 'Unknown error'}";
          _hasResponse = true;
        });
        _speak("There was a problem with the server. Please try again later.");
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _responseText = "Network error: $e";
        _hasResponse = true;
      });
      _speak("Connection error. Please check your internet connection and try again.");
      print("Network error: $e");
    }
  }

  // Method to pick equation image
  Future<void> _pickEquationImage() async {
    try {
      // Announce button press with TTS
      _speak("Analyze Math Equation button pressed");
      
      setState(() {
        _equationImage = null;
        _isEquationLoading = true;
      });

      await Future.delayed(const Duration(milliseconds: 1000));
      _speak("Please select a mathematical equation image from camera or gallery");
      
      final ImageSource? source = await _showImageSourceDialog("Math Equation");
      
      if (source == null) {
        setState(() => _isEquationLoading = false);
        _speak("Image selection cancelled");
        return;
      }

      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 85,
      );
      
      if (pickedFile != null) {
        HapticFeedback.mediumImpact(); // Add haptic feedback for selection
        setState(() {
          _equationImage = File(pickedFile.path);
          _speak("Equation image selected. Processing will begin.");
        });
        
        // Analyze the image
        await _analyzeMathImage(_equationImage!, "Equation");
      } else {
        _speak("No image was selected");
      }
      
      setState(() {
        _isEquationLoading = false;
      });
    } catch (e) {
      setState(() {
        _isEquationLoading = false;
      });
      _speak("Error selecting image: $e");
      print("Error picking equation image: $e");
    }
  }

  // Method to pick plot image
  Future<void> _pickPlotImage() async {
    try {
      // Announce button press with TTS
      _speak("Analyze Math Plot button pressed");
      
      setState(() {
        _plotImage = null;
        _isPlotLoading = true;
      });

      await Future.delayed(const Duration(milliseconds: 1000));
      _speak("Please select a math plot or graph image from camera or gallery");
      
      final ImageSource? source = await _showImageSourceDialog("Math Plot");
      
      if (source == null) {
        setState(() => _isPlotLoading = false);
        _speak("Image selection cancelled");
        return;
      }

      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 85,
      );
      
      if (pickedFile != null) {
        HapticFeedback.mediumImpact(); // Add haptic feedback for selection
        setState(() {
          _plotImage = File(pickedFile.path);
          _speak("Plot image selected. Processing will begin.");
        });
        
        // Analyze the image
        await _analyzeMathImage(_plotImage!, "Plot");
      } else {
        _speak("No image was selected");
      }
      
      setState(() {
        _isPlotLoading = false;
      });
    } catch (e) {
      setState(() {
        _isPlotLoading = false;
      });
      _speak("Error selecting image: $e");
      print("Error picking plot image: $e");
    }
  }

  Widget _buildAccessibleButton({
    required String text,
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
    required String semanticLabel,
    required String semanticHint,
    bool isLoading = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
      child: SizedBox(
        width: double.infinity,
        height: 230,
        child: Semantics(
          label: semanticLabel,
          hint: semanticHint,
          button: true,
          enabled: !isLoading && onPressed != null,
          onTap: isLoading 
              ? () {} 
              : () {
                  HapticFeedback.mediumImpact();
                  onPressed?.call();
                },
          child: ElevatedButton(
            onPressed: isLoading 
                ? null 
                : () {
                    HapticFeedback.mediumImpact();
                    onPressed?.call();
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              elevation: 12,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 36),
            ),
            child: isLoading
                ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 4)
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, size: 84),
                      const SizedBox(height: 16),
                      Flexible(
                        child: Text(
                          text,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  // Test connection to the backend server
  Future<void> _testBackendConnection() async {
    try {
      print("🧪 Testing connection to backend server...");
      final bool isConnected = await ApiService.testConnection();
      
      if (isConnected) {
        print("✅ Backend connection successful! Server is reachable.");
      } else {
        print("❌ Backend connection failed! Please check server status and network.");
        // Show a snackbar to inform the user
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Unable to connect to server. Please check your network connection.',
                style: TextStyle(fontSize: 16),
              ),
              backgroundColor: Colors.red.shade700,
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: _testBackendConnection,
              ),
            ),
          );
        }
      }
    } catch (e) {
      print("❌ Connection test error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Math Assistant",
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Stop any ongoing speech before navigating
            _stopSpeaking();
            // Announce navigation with TTS
            _speak("Returning to home screen");
            // Navigate back to home screen using named route
            Navigator.of(context).pushReplacementNamed('/home');
          },
          tooltip: 'Back to Home',
        ),
      ),
      body: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Semantics(
                header: true,
                label: 'Math Assistant Options',
                child: const Text(
                  'Choose an option:',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
              _buildAccessibleButton(
                text: "Analyze Math Equation",
                icon: Icons.functions,
                color: Colors.blue,
                isLoading: _isEquationLoading || (_isProcessing && _equationImage != null),
                onPressed: _isProcessing ? null : () { _pickEquationImage(); },
                semanticLabel: 'Button: Analyze Math Equation Image',
                semanticHint: 'Select or capture an image of a mathematical equation for analysis',
              ),
              _buildAccessibleButton(
                text: "Analyze Math Plot",
                icon: Icons.insert_chart,
                color: Colors.green,
                isLoading: _isPlotLoading || (_isProcessing && _plotImage != null),
                onPressed: _isProcessing ? null : () { _pickPlotImage(); },
                semanticLabel: 'Button: Analyze Math Plot Image',
                semanticHint: 'Select or capture an image of a mathematical plot or graph for analysis',
              ),

              // Processing indicator
              if (_isProcessing)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Column(
                    children: [
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _equationImage != null
                            ? "Processing equation..."
                            : "Processing plot...",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple,
                        ),
                      ),
                    ],
                  ),
                ),

              // Response display
              if (_hasResponse && _responseText.isNotEmpty)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: Card(
                      elevation: 8,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.purple.shade200, width: 2),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header with result type and a border underneath
                            Container(
                              padding: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: Colors.purple.shade200,
                                    width: 2,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _equationImage != null ? Icons.functions : Icons.insert_chart,
                                    color: Colors.purple,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _equationImage != null ? "Equation Analysis" : "Plot Analysis",
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.purple.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            // Response content with scrolling
                            Expanded(
                              child: Semantics(
                                label: "Analysis result, swipe to read",
                                hint: "Double tap to hear the explanation",
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.only(top: 12.0),
                                  child: Text(
                                    _responseText,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            
                            // Speech controls
                            Padding(
                              padding: const EdgeInsets.only(top: 16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Speech rate
                                  Row(
                                    children: [
                                      const Icon(Icons.speed, size: 20, color: Colors.grey),
                                      const SizedBox(width: 8),
                                      const Text(
                                        "Speech Rate:",
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Expanded(
                                        child: Semantics(
                                          label: "Speech rate slider",
                                          value: "${(_speechRate * 100).round()}%",
                                          child: Slider(
                                            value: _speechRate,
                                            min: 0.2,
                                            max: 1.0,
                                            divisions: 8,
                                            label: "${(_speechRate * 100).round()}%",
                                            onChanged: (value) {
                                              _adjustSpeechRate(value);
                                            },
                                            activeColor: Colors.purple,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  
                                  // Speech controls
                                  Center(
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        ElevatedButton.icon(
                                          onPressed: _isSpeaking
                                              ? () {
                                                  HapticFeedback.mediumImpact();
                                                  _stopSpeaking();
                                                }
                                              : () {
                                                  HapticFeedback.mediumImpact();
                                                  _speak(_responseText.split("LaTeX representation:").first);
                                                },
                                          icon: Icon(_isSpeaking ? Icons.stop : Icons.volume_up),
                                          label: Text(_isSpeaking ? "Stop" : "Read Explanation"),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: _isSpeaking ? Colors.red : Colors.purple,
                                            foregroundColor: Colors.white,
                                          ),
                                        ),
                                      ],
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
    );
  }
}