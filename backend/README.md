# STEM Assistant Backend API

A FastAPI-based backend for processing images, PDFs, and math expressions to support an assistive STEM learning application.

## Features

- **OCR Processing**: Extract text from images using Tesseract OCR
- **Math Expression Explanation**: Convert LaTeX or math expressions to plain English explanations
- **PDF Text Extraction**: Extract text content from PDF files

## Requirements

- Python 3.8+
- Tesseract OCR must be installed on the system

## Installation

1. Install Tesseract OCR:
   - Windows: Download from https://github.com/UB-Mannheim/tesseract/wiki
   - Linux: `sudo apt install tesseract-ocr`
   - macOS: `brew install tesseract`

2. Install Python dependencies:
   ```
   pip install -r requirements.txt
   ```

## Usage

Start the server:

```
python main.py
```

The API will be available at http://localhost:8000

API documentation is available at:
- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

## API Endpoints

### 1. `/upload`

Process an image to extract text using OCR.

- Method: POST
- Accepts: Image file or base64-encoded image
- Returns: Extracted text

### 2. `/explain`

Explain a mathematical expression in plain English.

- Method: POST
- Accepts: LaTeX or math expression
- Returns: Plain English explanation

### 3. `/pdf-upload`

Extract text from a PDF file.

- Method: POST
- Accepts: PDF file
- Returns: Extracted text and page count

## License

MIT