# STEM Assistant Backend

This is the FastAPI backend for the STEM Assistant application, featuring OCR, PDF processing, and multimodal AI for mathematical content analysis.

## Features

- OCR processing for general text and mathematical equations
- PDF text extraction
- Mathematical expression explanation
- Google Gemini integration for analyzing math equations and plots in images
- TTS-ready API responses for accessibility

## Installation

### Prerequisites

- Python 3.8+ 
- Tesseract OCR installed on your system
  - [Windows](https://github.com/UB-Mannheim/tesseract/wiki)
  - [macOS](https://brew.sh/): `brew install tesseract`
  - [Linux](https://tesseract-ocr.github.io/tessdoc/Installation.html): `sudo apt install tesseract-ocr`
- Google AI API key for Gemini Pro Vision (get it from [Google AI Studio](https://aistudio.google.com/app/apikey))

### Setup

1. Clone the repository and navigate to the backend directory:

```bash
cd backend
```

2. Create a virtual environment:

```bash
python -m venv venv
```

3. Activate the virtual environment:

- Windows: `venv\Scripts\activate`
- macOS/Linux: `source venv/bin/activate`

4. Install dependencies:

```bash
pip install -r requirements.txt
```

5. Configure your environment by creating or updating the `.env` file:

```
DEBUG=True
HOST=0.0.0.0
PORT=8000
TESSERACT_CMD=/path/to/tesseract  # Optional: only if not in system PATH
GOOGLE_API_KEY=your_api_key_here  # Required for Gemini Vision API
```

## Usage

### Starting the Server

```bash
uvicorn app.api:app --host 0.0.0.0 --port 8000
```

This will start the FastAPI server at `http://localhost:8000`.

### Testing the Gemini Integration

To test if Gemini Vision is working correctly with your setup:

```bash
python test_gemini.py path/to/test_image.jpg
```

### API Endpoints

- **`GET /`**: Health check endpoint
- **`POST /upload`**: Process an image with OCR
- **`POST /explain`**: Explain a mathematical expression
- **`POST /pdf-upload`**: Extract text from a PDF
- **`POST /process-math-image`**: Process a mathematical equation image using Gemini
- **`POST /process-plot-image`**: Process a mathematical plot/graph image using Gemini

For detailed API documentation, visit `http://localhost:8000/docs` after starting the server.

## Configuration

The API can be configured via environment variables (create a `.env` file in the backend directory):

```
DEBUG=True
HOST=0.0.0.0
PORT=8000
TESSERACT_CMD=/path/to/tesseract  # Adjust for your OS
GOOGLE_API_KEY=your_api_key_here  # Required for Gemini features
```

## Troubleshooting

### API Key Issues

If you encounter errors related to the Gemini API:

1. Verify your API key is correct and has been properly added to the `.env` file
2. Ensure the API key has access to the Gemini Pro Vision model
3. Check for any usage limits or quotas on your Google AI Studio account

### OCR Quality Issues

If OCR results are poor:

1. Ensure you have the latest version of Tesseract installed
2. Try adjusting the preprocessing parameters in the `ocr_image` function
3. For math-specific content, consider using specialized OCR tools or tune the Gemini prompts

## License

MIT