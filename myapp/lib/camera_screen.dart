import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:vibration/vibration.dart';
import 'services/api_service.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final ImagePicker _picker = ImagePicker();
  File? _image;
  bool _isLoading = false;
  String _responseText = '';
  final FlutterTts _flutterTts = FlutterTts();
  
  @override
  void initState() {
    super.initState();
    _initTts();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _speak("Image capture screen opened. You can capture a new image or select from gallery.");
    });
  }

  Future<void> _initTts() async {
    try {
      print("Initializing TTS...");
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setSpeechRate(0.45);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      
      // Add TTS completion and error handlers
      _flutterTts.setCompletionHandler(() {
        print("TTS completed");
      });
      
      _flutterTts.setErrorHandler((msg) {
        print("TTS error: $msg");
      });
      
      print("TTS initialized successfully");
    } catch (e) {
      print("TTS initialization error: $e");
    }
  }

  Future<void> _speak(String text) async {
    try {
      print("Speaking text: $text");
      await _flutterTts.stop(); // Stop any ongoing speech first
      
      // Add a small delay after stopping to ensure clean start
      await Future.delayed(const Duration(milliseconds: 300));
      
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setSpeechRate(0.45); // Consistent with initialization
      await _flutterTts.setVolume(1.0);
      
      var result = await _flutterTts.speak(text);
      print("TTS result: $result");
    } catch (e) {
      print("TTS Error: $e");
    }
  }

  Future<void> _stopSpeaking() async {
    try {
      await _flutterTts.stop();
      print("Speech stopped");
    } catch (e) {
      print("Error stopping speech: $e");
    }
  }

  Future<void> _captureImageFromCamera() async {
    try {
      // Announce button press clearly
      _speak("Camera button pressed. Opening camera.");
      
      // Add delay to ensure the announcement is heard before camera opens
      await Future.delayed(const Duration(milliseconds: 1000));
      
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 80,
      );
      
      if (photo != null) {
        setState(() {
          _image = File(photo.path);
          _responseText = 'Image captured. Ready to upload.';
        });
        
        // Vibrate for feedback
        Vibration.vibrate(duration: 100);
        
        // Delay for better user experience
        await Future.delayed(const Duration(milliseconds: 500));
        _speak("Image captured successfully. Ready to upload.");
      } else {
        await Future.delayed(const Duration(milliseconds: 500));
        _speak("No image was captured or operation was cancelled.");
      }
    } catch (e) {
      setState(() {
        _responseText = 'Error capturing image: $e';
      });
      
      // Vibrate for error
      Vibration.vibrate(duration: 300);
      
      await Future.delayed(const Duration(milliseconds: 500));
      _speak("Error using camera. Falling back to gallery selection.");
      
      // Delay before fallback
      await Future.delayed(const Duration(milliseconds: 1500));
      
      // Fall back to gallery if camera fails
      await _selectImageFromGallery();
    }
  }

  Future<void> _selectImageFromGallery() async {
    try {
      // Announce button press clearly
      _speak("Gallery button pressed. Opening image picker.");
      
      // Add delay to ensure the announcement is heard before gallery opens
      await Future.delayed(const Duration(milliseconds: 1000));
      
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      
      if (photo != null) {
        setState(() {
          _image = File(photo.path);
          _responseText = 'Image selected. Ready to upload.';
        });
        
        // Vibrate for feedback
        Vibration.vibrate(duration: 100);
        
        // Delay for better user experience
        await Future.delayed(const Duration(milliseconds: 500));
        _speak("Image selected successfully. Ready to upload.");
      } else {
        await Future.delayed(const Duration(milliseconds: 500));
        _speak("No image was selected or operation was cancelled.");
      }
    } catch (e) {
      setState(() {
        _responseText = 'Error selecting image: $e';
      });
      
      // Vibrate for error
      Vibration.vibrate(duration: 300);
      
      await Future.delayed(const Duration(milliseconds: 500));
      _speak("Error selecting image. Please try again.");
    }
  }

  Future<void> _uploadImage() async {
    if (_image == null) {
      _speak("No image to upload. Please capture an image first.");
      setState(() {
        _responseText = 'No image to upload. Please capture an image first.';
      });
      return;
    }

    // Announce button press clearly
    _speak("Upload button pressed. Starting upload process.");
    
    setState(() {
      _isLoading = true;
      _responseText = 'Uploading image...';
    });
    await Future.delayed(const Duration(milliseconds: 1000));
    _speak("Uploading image. Please wait.");

    try {
      // Try using multipart form upload instead of base64 JSON
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiService.baseUrl}/upload'),
      );
      
      // Add the image file
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          _image!.path,
          filename: 'image.jpg',
        ),
      );
      
      print("Sending multipart request to: ${ApiService.baseUrl}/upload");
      
      // Send the multipart request
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      
      setState(() {
        _isLoading = false;
      });
      
      print("Response status: ${response.statusCode}");
      print("Response body: ${response.body}");
      
      if (response.statusCode == 200) {
        try {
          // Parse response
          final Map<String, dynamic> data = jsonDecode(response.body);
          final String resultText = data['result'] ?? 'Upload successful';
          
          setState(() {
            _responseText = resultText;
          });
          
          // Add a delay before speaking to ensure TTS works properly
          await Future.delayed(const Duration(milliseconds: 500));
          
          // Speak the OCR result
          if (resultText.isNotEmpty) {
            print("Speaking OCR result: $resultText");
            _speak("Text extracted from image: $resultText");
          } else {
            _speak("The image was processed successfully, but no text was found.");
          }
          
          // Vibrate on success
          if (await Vibration.hasVibrator() ?? false) {
            Vibration.vibrate(
              pattern: [100, 200, 100, 200, 100, 200],
              intensities: [128, 255, 128, 255, 128, 255],
            );
          }
        } catch (e) {
          print("Error processing response: $e");
          setState(() {
            _responseText = "Error parsing response: $e";
          });
          _speak("There was a problem processing the server response.");
        }
      } else {
        setState(() {
          _responseText = 'Error: ${response.statusCode} - ${response.reasonPhrase}';
        });
        _speak("Error uploading image. The server returned status code ${response.statusCode}. Please try again or use a different image.");
        print("Server response: ${response.body}");
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _responseText = 'Error uploading image: $e';
      });
      _speak("There was a problem uploading the image. Please check your internet connection and try again.");
      print("Upload error details: $e");
    }
  }

  // Original base64 JSON upload method as backup
  Future<void> _uploadImageBase64() async {
    if (_image == null) {
      _speak("No image to upload. Please capture an image first.");
      setState(() {
        _responseText = 'No image to upload. Please capture an image first.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _responseText = 'Uploading image...';
    });
    _speak("Uploading image. Please wait.");

    try {
      // Convert image to base64
      List<int> imageBytes = await _image!.readAsBytes();
      String base64Image = base64Encode(imageBytes);
      
      print("Image size: ${imageBytes.length} bytes");
      print("Base64 length: ${base64Image.length} characters");
      
      // Create the payload as a proper ImagePayload object matching the server model
      final payload = {
        'image': base64Image,
        'format': 'base64'
      };
      
      print("Sending request to: ${ApiService.uploadEndpoint}");
      
      // Use ApiService for endpoint URL
      final response = await http.post(
        Uri.parse(ApiService.uploadEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(payload),
      );

      setState(() {
        _isLoading = false;
      });

      print("Response status: ${response.statusCode}");
      print("Response body: ${response.body}");

      if (response.statusCode == 200) {
        try {
          // Parse response
          final Map<String, dynamic> data = jsonDecode(response.body);
          final String resultText = data['result'] ?? 'Upload successful';
          
          setState(() {
            _responseText = resultText;
          });
          
          // Add a delay before speaking to ensure TTS works properly
          await Future.delayed(const Duration(milliseconds: 500));
          
          // Speak the OCR result
          if (resultText.isNotEmpty) {
            print("Speaking OCR result: $resultText");
            _speak("Text extracted from image: $resultText");
          } else {
            _speak("The image was processed successfully, but no text was found.");
          }
          
          // Vibrate on success
          if (await Vibration.hasVibrator() ?? false) {
            Vibration.vibrate(
              pattern: [100, 200, 100, 200, 100, 200],
              intensities: [128, 255, 128, 255, 128, 255],
            );
          }
        } catch (e) {
          print("Error processing response: $e");
          setState(() {
            _responseText = "Error parsing response: $e";
          });
          _speak("There was a problem processing the server response.");
        }
      } else {
        setState(() {
          _responseText = 'Error: ${response.statusCode} - ${response.reasonPhrase}';
        });
        _speak("Error uploading image. The server returned status code ${response.statusCode}. Please try again or use a different image.");
        print("Server response: ${response.body}");
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _responseText = 'Error uploading image: $e';
      });
      _speak("There was a problem uploading the image. Please check your internet connection and try again.");
      print("Upload error details: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Capture Image'),
        backgroundColor: Colors.blueAccent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            _stopSpeaking();
            _speak("Returning to home screen");
            Navigator.pushReplacementNamed(context, '/home');
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 3,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue, width: 2),
                ),
                margin: const EdgeInsets.only(bottom: 16),
                child: _image == null
                    ? Semantics(
                        label: 'Image preview area, no image captured yet',
                        child: const Center(
                          child: Icon(
                            Icons.photo_camera,
                            size: 100,
                            color: Colors.grey,
                          ),
                        ),
                      )
                    : Semantics(
                        label: 'Captured image preview',
                        image: true,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.file(
                            _image!,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
              ),
            ),
            Semantics(
              label: 'Upload status and response',
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      'Status:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _responseText,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.only(top: 16.0),
                        child: CircularProgressIndicator(),
                      ),
                  ],
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    label: 'Capture with camera',
                    hint: 'Double tap to take a picture with the camera',
                    button: true,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _captureImageFromCamera,
                      icon: const Icon(Icons.camera_alt, size: 32),
                      label: const Text(
                        'Camera',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Semantics(
                    label: 'Select from gallery',
                    hint: 'Double tap to select a picture from your gallery',
                    button: true,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _selectImageFromGallery,
                      icon: const Icon(Icons.photo_library, size: 32),
                      label: const Text(
                        'Gallery',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Semantics(
              label: 'Upload image button',
              hint: 'Double tap to upload the image to the server',
              button: true,
              child: ElevatedButton.icon(
                onPressed: _isLoading || _image == null ? null : _uploadImage,
                icon: const Icon(Icons.cloud_upload, size: 40),
                label: const Text(
                  'Upload Image',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
            // Add a fallback upload button for testing
            const SizedBox(height: 8),
            if (_image != null)
              Semantics(
                label: 'Try alternative upload',
                hint: 'Double tap to try an alternative upload method if the main one fails',
                button: true,
                child: TextButton.icon(
                  onPressed: _isLoading ? null : _uploadImageBase64,
                  icon: const Icon(Icons.sync_problem, size: 20),
                  label: const Text(
                    'Try Alternative Upload',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ),
          ],
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