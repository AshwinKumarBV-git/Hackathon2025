import 'package:flutter/material.dart';
import '../services/accessibility_service.dart';

class AccessibilityDemoScreen extends StatefulWidget {
  const AccessibilityDemoScreen({super.key});

  @override
  State<AccessibilityDemoScreen> createState() => _AccessibilityDemoScreenState();
}

class _AccessibilityDemoScreenState extends State<AccessibilityDemoScreen> {
  final AccessibilityService _accessibilityService = AccessibilityService();
  bool _isServiceInitialized = false;
  bool _isSpeaking = false;
  bool _isPaused = false;
  String _currentText = '';
  ContentType _selectedContentType = ContentType.text;

  final List<String> _demoTexts = [
    'This is a regular text that will be read using the standard text-to-speech settings.',
    'The quadratic formula is x equals negative b plus or minus the square root of b squared minus 4ac, all divided by 2a.',
    'The graph shows an increasing trend from January to June, followed by a decline in July and August.',
    'Error: Unable to process the image. Please try again with better lighting.',
    'Success! Your document has been successfully processed and saved.',
  ];

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  Future<void> _initializeService() async {
    await _accessibilityService.initialize();
    setState(() {
      _isServiceInitialized = true;
    });
  }

  void _updateSpeakingState() {
    setState(() {
      _isSpeaking = _accessibilityService.isSpeaking;
      _isPaused = _accessibilityService.isPaused;
    });
  }

  Future<void> _speakText(String text, ContentType contentType) async {
    _currentText = text;
    await _accessibilityService.speak(text, contentType: contentType);
    _updateSpeakingState();
  }

  Future<void> _stopSpeaking() async {
    await _accessibilityService.stop();
    _updateSpeakingState();
  }

  Future<void> _pauseOrResume() async {
    if (await _accessibilityService.pauseOrResume()) {
      if (_accessibilityService.isPaused) {
        // Do nothing, we've paused
      } else {
        // We need to resume by speaking again
        await _accessibilityService.speak(_currentText, contentType: _selectedContentType);
      }
    }
    _updateSpeakingState();
  }

  Widget _buildContentTypeSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select content type:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8.0,
            children: ContentType.values.map((type) {
              return ChoiceChip(
                label: Text(type.name),
                selected: _selectedContentType == type,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _selectedContentType = type;
                    });
                    // Demo the vibration
                    _accessibilityService.vibrate(type);
                  }
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeechControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_isSpeaking || _isPaused)
            IconButton(
              icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
              onPressed: _pauseOrResume,
              tooltip: _isPaused ? 'Resume' : 'Pause',
              iconSize: 36,
            ),
          if (_isSpeaking || _isPaused)
            IconButton(
              icon: const Icon(Icons.stop),
              onPressed: _stopSpeaking,
              tooltip: 'Stop',
              iconSize: 36,
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Accessibility Demo',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              label: 'Accessibility Service Demo',
              header: true,
              child: const Text(
                'Accessibility Service Demo',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            if (!_isServiceInitialized)
              const Center(child: CircularProgressIndicator())
            else
              Column(
                children: [
                  _buildContentTypeSelector(),
                  const Divider(),
                  Semantics(
                    label: 'Example text categories',
                    child: const Text(
                      'Select a text to speak:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _demoTexts.length,
                      itemBuilder: (context, index) {
                        final text = _demoTexts[index];
                        final contentType = ContentType.values[index];
                        
                        return Semantics(
                          button: true,
                          label: 'Speak ${contentType.name} example',
                          child: Card(
                            color: _selectedContentType == contentType 
                                ? Colors.purple.withOpacity(0.1) 
                                : null,
                            elevation: 2,
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            child: ListTile(
                              title: Text(
                                contentType.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                text,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.volume_up),
                                onPressed: () {
                                  setState(() {
                                    _selectedContentType = contentType;
                                  });
                                  _speakText(text, contentType);
                                },
                                tooltip: 'Speak ${contentType.name} example',
                              ),
                              onTap: () {
                                setState(() {
                                  _selectedContentType = contentType;
                                });
                                _speakText(text, contentType);
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  _buildSpeechControls(),
                ],
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _accessibilityService.stop();
    super.dispose();
  }
} 