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
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }

  Future<void> _speak(String text) async {
    await _flutterTts.speak(text);
  }

  Future<void> _captureImageFromCamera() async {
    try {
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
        _speak("Image captured. Ready to upload.");
      }
    } catch (e) {
      setState(() {
        _responseText = 'Error capturing image: $e';
      });
      _speak("Error capturing image. Falling back to gallery selection.");
      // Fall back to gallery if camera fails
      await _selectImageFromGallery();
    }
  }

  Future<void> _selectImageFromGallery() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      
      if (photo != null) {
        setState(() {
          _image = File(photo.path);
          _responseText = 'Image selected. Ready to upload.';
        });
        _speak("Image selected. Ready to upload.");
      }
    } catch (e) {
      setState(() {
        _responseText = 'Error selecting image: $e';
      });
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

    setState(() {
      _isLoading = true;
      _responseText = 'Uploading image...';
    });
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
        // Parse response
        final Map<String, dynamic> data = jsonDecode(response.body);
        setState(() {
          _responseText = data['result'] ?? 'Upload successful';
        });
        
        // Speak response
        _speak(_responseText);
        
        // Vibrate on success
        if (await Vibration.hasVibrator() ?? false) {
          Vibration.vibrate(
            pattern: [100, 200, 100, 200, 100, 200],
            intensities: [128, 255, 128, 255, 128, 255],
          );
        }
      } else {
        setState(() {
          _responseText = 'Error: ${response.statusCode} - ${response.reasonPhrase}';
        });
        _speak("Error uploading image. Server returned status code ${response.statusCode}.");
        print("Server response: ${response.body}");
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _responseText = 'Error uploading image: $e';
      });
      _speak("Error uploading image. Please check your connection and try again.");
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
        // Parse response
        final Map<String, dynamic> data = jsonDecode(response.body);
        setState(() {
          _responseText = data['result'] ?? 'Upload successful';
        });
        
        // Speak response
        _speak(_responseText);
        
        // Vibrate on success
        if (await Vibration.hasVibrator() ?? false) {
          Vibration.vibrate(
            pattern: [100, 200, 100, 200, 100, 200],
            intensities: [128, 255, 128, 255, 128, 255],
          );
        }
      } else {
        setState(() {
          _responseText = 'Error: ${response.statusCode} - ${response.reasonPhrase}';
        });
        _speak("Error uploading image. Server returned status code ${response.statusCode}.");
        print("Server response: ${response.body}");
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _responseText = 'Error uploading image: $e';
      });
      _speak("Error uploading image. Please check your connection and try again.");
      print("Upload error details: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Capture Image',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
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
                      icon: const Icon(Icons.camera_alt, size: 24),
                      label: const Text(
                        'Camera',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
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
                      icon: const Icon(Icons.photo_library, size: 24),
                      label: const Text(
                        'Gallery',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Semantics(
              label: 'Upload image button',
              hint: 'Double tap to upload the image to the server',
              button: true,
              child: ElevatedButton.icon(
                onPressed: _isLoading || _image == null ? null : _uploadImage,
                icon: const Icon(Icons.cloud_upload, size: 32),
                label: const Text(
                  'Upload Image',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
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