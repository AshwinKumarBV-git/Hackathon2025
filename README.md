# Assistive STEM Learning Platform

A comprehensive learning platform designed to make STEM education accessible to visually impaired users through a combination of mobile app and backend services.

## Project Structure

This repository contains two main components:

### 1. Flutter Mobile Application (`myapp/`)

A Flutter-based mobile application specifically designed for visually impaired users with:
- Accessible UI with high-contrast colors and large text
- Screen reader (TalkBack) compatibility
- Text-to-speech for all content
- Camera functionality for capturing images of textbooks and equations
- PDF import and processing
- Haptic feedback for different content types

For more details about the mobile app, see the [myapp README](./myapp/README.md).

### 2. Python Backend Server (`backend/`)

A FastAPI-based backend that provides:
- Optical Character Recognition (OCR) for extracting text from images
- PDF text extraction
- Mathematical expression parsing and explanation
- JSON API endpoints for the mobile app

## Getting Started

### Running the Mobile App

1. Navigate to the myapp directory:
   ```
   cd myapp
   ```

2. Install Flutter dependencies:
   ```
   flutter pub get
   ```

3. Run the app:
   ```
   flutter run
   ```

### Running the Backend Server

1. Navigate to the backend directory:
   ```
   cd backend
   ```

2. Install Python dependencies:
   ```
   pip install -r requirements.txt
   ```

3. Start the server:
   ```
   python -m uvicorn app.api:app --reload
   ```

   Or alternatively:
   ```
   cd backend
   uvicorn app.api:app --reload
   ```

4. The API will be available at http://127.0.0.1:8000

## Requirements

- Flutter 3.7+ and Dart 3.0+
- Python 3.8+
- Tesseract OCR
- Android SDK 21+ or iOS 12+ for mobile development

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

This platform was created to improve STEM education accessibility for visually impaired users by combining mobile technology with intelligent processing of educational materials. 