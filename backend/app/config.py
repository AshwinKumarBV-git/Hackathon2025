import os
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

# API settings
HOST = os.getenv("HOST", "0.0.0.0")
PORT = int(os.getenv("PORT", 8000))
DEBUG = os.getenv("DEBUG", "True").lower() in ("true", "1", "t")

# Tesseract settings
TESSERACT_CMD = os.getenv("TESSERACT_CMD", "tesseract")

# Configure tesseract path
import pytesseract
pytesseract.pytesseract.tesseract_cmd = TESSERACT_CMD