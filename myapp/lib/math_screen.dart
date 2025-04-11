import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:vibration/vibration.dart';
import 'package:http/http.dart' as http;
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
          ? '${ApiService.baseUrl}/process-math-image'
          : '${ApiService.baseUrl}/process-plot-image';
      
      print("Sending request to: $endpoint");
      
      // Create multipart request
      var request = http.MultipartRequest('POST', Uri.parse(endpoint));
      
      // Add the image file
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          imageFile.path,
          filename: '${type.toLowerCase()}_image.jpg',
        ),
      );
      
      // Send the request
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      
      print("Response status: ${response.statusCode}");
      print("Response body: ${response.body}");
      
      setState(() {
        _isProcessing = false;
      });
      
      if (response.statusCode == 200) {
        try {
          // Parse the JSON response
          final Map<String, dynamic> data = jsonDecode(response.body);
          final String explanation = data['explanation'] ?? 'No explanation provided';
          
          setState(() {
            _responseText = explanation;
            _hasResponse = true;
          });
          
          // Provide haptic and auditory feedback for success
          if (await Vibration.hasVibrator() ?? false) {
            Vibration.vibrate(pattern: [0, 100, 50, 100]);
          }
          
          // Add a slight delay before speaking to ensure UI is updated
          await Future.delayed(const Duration(milliseconds: 300));
          
          // Speak the explanation
          _speak("Analysis complete. $explanation");
          
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
          _responseText = "Error ${response.statusCode}: ${response.reasonPhrase}";
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
      final ImageSource? source = await _showImageSourceDialog("Equation Analysis");
      
      if (source == null) {
        _speak("Image selection cancelled");
        return;
      }
      
      setState(() {
        _isEquationLoading = true;
      });
      
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 90,
      );
      
      setState(() {
        _isEquationLoading = false;
      });
      
      if (image != null) {
        setState(() {
          _equationImage = File(image.path);
          _plotImage = null; // Clear the other image if any
        });
        _speak("Equation image selected successfully.");
        
        // Provide haptic feedback
        if (await Vibration.hasVibrator() ?? false) {
          Vibration.vibrate(duration: 200);
        }
        
        // Process the equation image with the backend
        await _analyzeMathImage(_equationImage!, "Equation");
      } else {
        _speak("No image selected.");
      }
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
      final ImageSource? source = await _showImageSourceDialog("Plot Analysis");
      
      if (source == null) {
        _speak("Image selection cancelled");
        return;
      }
      
      setState(() {
        _isPlotLoading = true;
      });
      
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 90,
      );
      
      setState(() {
        _isPlotLoading = false;
      });
      
      if (image != null) {
        setState(() {
          _plotImage = File(image.path);
          _equationImage = null; // Clear the other image if any
        });
        _speak("Plot image selected successfully.");
        
        // Provide haptic feedback
        if (await Vibration.hasVibrator() ?? false) {
          Vibration.vibrate(duration: 200);
        }
        
        // Process the plot image with the backend
        await _analyzeMathImage(_plotImage!, "Plot");
      } else {
        _speak("No image selected.");
      }
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
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
      child: SizedBox(
        width: double.infinity,
        height: 100,
        child: Semantics(
          label: semanticLabel,
          hint: semanticHint,
          button: true,
          enabled: !isLoading && onPressed != null,
          onTap: isLoading ? () {} : onPressed ?? () {},
          child: ElevatedButton(
            onPressed: isLoading ? null : onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 8,
            ),
            child: isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, size: 32),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          text,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
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
          "Math Assistant",
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Semantics(
                header: true,
                label: 'Math Assistant Options',
                child: const Text(
                  'Choose an option:',
                  style: TextStyle(
                    fontSize: 24, 
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
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
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Semantics(
                              label: _equationImage != null 
                                  ? 'Equation Analysis Result' 
                                  : 'Plot Analysis Result',
                              header: true,
                              child: Text(
                                _equationImage != null 
                                    ? "Equation Analysis" 
                                    : "Plot Analysis",
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.purple,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: SingleChildScrollView(
                                child: Semantics(
                                  label: 'Analysis result',
                                  child: SelectableText(
                                    _responseText,
                                    style: const TextStyle(
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // Speech controls
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Column(
                                children: [
                                  // Speech rate slider
                                  Semantics(
                                    label: 'Adjust speech rate',
                                    slider: true,
                                    value: "Speech rate: ${(_speechRate * 100).round()}%",
                                    child: Row(
                                      children: [
                                        const Icon(Icons.speed, size: 20),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Slider(
                                            value: _speechRate,
                                            min: 0.25,
                                            max: 1.0,
                                            divisions: 15,
                                            label: "Speed: ${(_speechRate * 100).round()}%",
                                            onChanged: (value) => _adjustSpeechRate(value),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Playback controls
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      if (_isSpeaking)
                                        IconButton(
                                          icon: const Icon(Icons.stop_circle),
                                          onPressed: () { _stopSpeaking(); },
                                          tooltip: 'Stop speaking',
                                          color: Colors.red,
                                        ),
                                      const SizedBox(width: 8),
                                      TextButton.icon(
                                        onPressed: () { _speak(_responseText); },
                                        icon: const Icon(Icons.volume_up),
                                        label: const Text("Read Explanation"),
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.purple,
                                        ),
                                      ),
                                    ],
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
  
  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }
} 