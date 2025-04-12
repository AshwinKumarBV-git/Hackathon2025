import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'services/api_service.dart';

class PDFImportScreen extends StatefulWidget {
  const PDFImportScreen({super.key});

  @override
  State<PDFImportScreen> createState() => _PDFImportScreenState();
}

class _PDFImportScreenState extends State<PDFImportScreen> {
  File? _pdfFile;
  String _fileName = '';
  bool _isLoading = false;
  String _responseText = '';
  String _extractedContent = '';
  final FlutterTts _flutterTts = FlutterTts();
  bool _isSpeaking = false;
  bool _isPaused = false;
  
  @override
  void initState() {
    super.initState();
    _initTts();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _speak("PDF import screen opened. Tap the select PDF button to choose a PDF file from your device.");
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
        setState(() {
          _isSpeaking = false;
          _isPaused = false;
        });
      });
      
      _flutterTts.setErrorHandler((message) {
        setState(() {
          _isSpeaking = false;
          _isPaused = false;
        });
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
      setState(() {
        _isSpeaking = false;
        _isPaused = false;
      });
    }
    
    if (text.isNotEmpty) {
      await _flutterTts.speak(text);
    }
  }

  Future<void> _stopSpeaking() async {
    if (_isSpeaking) {
      await _flutterTts.stop();
      setState(() {
        _isSpeaking = false;
        _isPaused = false;
      });
    }
  }

  Future<void> _pauseOrResume() async {
    if (_isSpeaking && !_isPaused) {
      await _flutterTts.stop();
      setState(() {
        _isSpeaking = false;
        _isPaused = true;
      });
    } else if (_isPaused) {
      await Future.delayed(const Duration(milliseconds: 300));
      await _flutterTts.speak(_extractedContent);
      setState(() => _isPaused = false);
    }
  }

  Future<void> _selectPDF() async {
    try {
      _speak("Select PDF button pressed. Opening file picker.");
      
      await Future.delayed(const Duration(milliseconds: 1000));
      
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      
      if (result != null && result.files.single.path != null) {
        setState(() {
          _pdfFile = File(result.files.single.path!);
          _fileName = result.files.single.name;
          _responseText = 'PDF selected: $_fileName';
          _extractedContent = '';
        });
        
        await Future.delayed(const Duration(milliseconds: 500));
        _speak("PDF selected: $_fileName. Ready to upload.");
      } else {
        await Future.delayed(const Duration(milliseconds: 500));
        _speak("No PDF was selected or operation was cancelled.");
      }
    } catch (e) {
      setState(() {
        _responseText = 'Error selecting PDF: $e';
      });
      await Future.delayed(const Duration(milliseconds: 500));
      _speak("Error selecting PDF. Please try again.");
    }
  }

  Future<void> _uploadPDF() async {
    if (_pdfFile == null) {
      _speak("No PDF selected. Please select a PDF file first.");
      setState(() {
        _responseText = 'No PDF selected. Please select a PDF file first.';
      });
      return;
    }

    _speak("Upload PDF button pressed. Starting upload process.");
    
    setState(() {
      _isLoading = true;
      _responseText = 'Uploading PDF...';
      _extractedContent = '';
    });
    
    await Future.delayed(const Duration(milliseconds: 1500));
    _speak("Uploading PDF. Please wait.");

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse(ApiService.pdfUploadEndpoint),
      );
      
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          _pdfFile!.path,
          filename: _fileName,
        ),
      );
      
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      setState(() {
        _isLoading = false;
      });

      if (response.statusCode == 200) {
        try {
          final Map<String, dynamic> data = jsonDecode(response.body);
          setState(() {
            _responseText = 'PDF processed successfully';
            _extractedContent = data['content'] ?? 'No content extracted';
          });
          
          await Future.delayed(const Duration(milliseconds: 1000));
          
          if (_extractedContent.length > 500) {
            _speak("PDF processed successfully. PDF contains ${_extractedContent.length} characters of text. Double tap the content area to hear it read aloud.");
          } else {
            _speak("PDF processed. Here is the extracted content: $_extractedContent");
          }
        } catch (e) {
          setState(() {
            _responseText = 'Error parsing response: $e';
          });
          print("Response parsing error: $e");
          print("Raw response: ${response.body}");
          
          await Future.delayed(const Duration(milliseconds: 500));
          _speak("Error processing server response.");
        }
      } else {
        setState(() {
          _responseText = 'Error: ${response.statusCode} - ${response.reasonPhrase}';
        });
        print("Server response: ${response.body}");
        
        await Future.delayed(const Duration(milliseconds: 500));
        _speak("Error processing PDF. Server returned status code ${response.statusCode}.");
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _responseText = 'Error uploading PDF: $e';
      });
      
      await Future.delayed(const Duration(milliseconds: 500));
      _speak("Error uploading PDF. Please check your connection and try again.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'PDF Import',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.redAccent,
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
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red, width: 2),
              ),
              child: Semantics(
                label: _pdfFile == null ? 'No PDF selected' : 'Selected PDF: $_fileName',
                child: Column(
                  children: [
                    Icon(
                      Icons.picture_as_pdf,
                      size: 60,
                      color: _pdfFile == null ? Colors.grey : Colors.red,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _pdfFile == null ? 'No PDF selected' : 'Selected PDF: $_fileName',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            Semantics(
              label: 'Status: $_responseText',
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      'Status:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _responseText,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.only(top: 12.0),
                        child: CircularProgressIndicator(),
                      ),
                  ],
                ),
              ),
            ),
            
            Semantics(
              label: 'Select PDF button',
              hint: 'Double tap to select a PDF file from your device',
              button: true,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _selectPDF,
                icon: const Icon(Icons.attach_file, size: 36),
                label: const Text(
                  'Select PDF',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            Semantics(
              label: 'Upload PDF button',
              hint: 'Double tap to upload the selected PDF for processing',
              button: true,
              child: ElevatedButton.icon(
                onPressed: _isLoading || _pdfFile == null ? null : _uploadPDF,
                icon: const Icon(Icons.cloud_upload, size: 36),
                label: const Text(
                  'Upload PDF',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            if (_extractedContent.isNotEmpty)
              Expanded(
                child: Semantics(
                  label: 'Extracted content from PDF',
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.3),
                          spreadRadius: 1,
                          blurRadius: 3,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Extracted Content:',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Row(
                              children: [
                                Semantics(
                                  label: _isSpeaking ? (_isPaused ? 'Resume' : 'Pause') : 'Read aloud',
                                  button: true,
                                  child: IconButton(
                                    icon: Icon(
                                      _isSpeaking
                                          ? (_isPaused ? Icons.play_arrow : Icons.pause)
                                          : Icons.volume_up,
                                    ),
                                    onPressed: _isSpeaking ? _pauseOrResume : () => _speak(_extractedContent),
                                    tooltip: _isSpeaking ? (_isPaused ? 'Resume' : 'Pause') : 'Read aloud',
                                  ),
                                ),
                                if (_isSpeaking)
                                  Semantics(
                                    label: 'Stop reading',
                                    button: true,
                                    child: IconButton(
                                      icon: const Icon(Icons.stop),
                                      onPressed: _stopSpeaking,
                                      tooltip: 'Stop reading',
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        const Divider(),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Text(
                              _extractedContent,
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
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