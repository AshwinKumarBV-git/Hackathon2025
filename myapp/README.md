# STEM Assist

An assistive STEM learning application designed for visually impaired users, providing image capturing, PDF processing, and accessible explanations of mathematical content.

## Features

- **Image Capture & Processing**: Take photos of textbooks, equations, or diagrams and extract text via OCR
- **PDF Import**: Upload PDF documents and extract text for TTS reading
- **Accessibility Features**: 
  - High-contrast UI with large text
  - TalkBack/screen reader compatibility 
  - Text-to-speech (TTS) for all content
  - Haptic feedback patterns for different content types
  - Semantic labeling for improved screen reader navigation

## Getting Started

### Prerequisites

- Flutter 3.7.0 or higher
- Dart 3.0.0 or higher
- Android SDK 21+ or iOS 12+
- Backend server for OCR and PDF processing

### Installation

1. Clone the repository:
   ```
   git clone https://github.com/yourusername/stem-assist.git
   ```

2. Install dependencies:
   ```
   cd myapp
   flutter pub get
   ```

3. Run the app:
   ```
   flutter run
   ```

### Backend Setup

The app requires a FastAPI backend for OCR and PDF processing:

1. Navigate to the backend directory:
   ```
   cd backend
   ```

2. Install Tesseract OCR:
   - Windows: Download from [https://github.com/UB-Mannheim/tesseract/wiki](https://github.com/UB-Mannheim/tesseract/wiki)
   - Linux: `sudo apt install tesseract-ocr`
   - macOS: `brew install tesseract`

3. Install Python dependencies:
   ```
   pip install -r requirements.txt
   ```

4. Run the backend server:
   ```
   python -m uvicorn app.api:app --reload
   ```

5. The backend server will be available at http://127.0.0.1:8000

## App Structure

- **Home Screen**: Three main functions - Capture Image, Import PDF, Get Help
- **Image Capture Screen**: Camera and gallery options with upload functionality
- **PDF Import Screen**: File selection and text extraction with TTS playback
- **Accessibility Demo**: Showcases various TTS and haptic feedback patterns

## Technologies Used

### Frontend (Flutter)
- `image_picker`: Camera and gallery image selection
- `file_picker`: PDF file selection
- `flutter_tts`: Text-to-speech capabilities
- `vibration`: Haptic feedback
- `http`: API communication

### Backend (FastAPI)
- `pytesseract`: OCR processing
- `PyMuPDF`: PDF text extraction
- `sympy`: Mathematical expression parsing
- `fastapi`: REST API framework

## Configuration

- Update the server URL in `lib/services/api_service.dart` if needed
- For physical devices, set your computer's IP address in `api_service.dart`

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- This app was created to improve STEM education accessibility for visually impaired users
- Special thanks to the Flutter and FastAPI communities for their excellent documentation
