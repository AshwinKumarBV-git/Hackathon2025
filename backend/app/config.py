# /app/config.py

import os
import sys # Import sys to print warnings to stderr
from dotenv import load_dotenv

# Load environment variables from .env file if it exists
# Useful for local development
dotenv_path = os.path.join(os.path.dirname(__file__), '..', '.env') # Assumes .env is in the parent directory of app/
if os.path.exists(dotenv_path):
    load_dotenv(dotenv_path=dotenv_path)
else:
    # Attempt to load from the current directory as a fallback
    load_dotenv()

# --- General API Settings ---
HOST = os.getenv("HOST", "0.0.0.0")
PORT = int(os.getenv("PORT", 8000))

# --- Debug Mode ---
# More robust boolean check for DEBUG environment variable
DEBUG_STR = os.getenv("DEBUG", "False").lower()
DEBUG = DEBUG_STR in ("true", "1", "t", "yes", "y")

# --- Tesseract OCR Settings ---
# Default to 'tesseract' command if not specified in .env
TESSERACT_CMD = os.getenv("TESSERACT_CMD")
# Configure pytesseract path only if TESSERACT_CMD is explicitly set
# Otherwise, assume it's in the system PATH
if TESSERACT_CMD:
    try:
        import pytesseract
        pytesseract.pytesseract.tesseract_cmd = TESSERACT_CMD
        print(f"Configured pytesseract command path to: {TESSERACT_CMD}")
    except ImportError:
        print("Warning: pytesseract library not found. Cannot configure TESSERACT_CMD.", file=sys.stderr)
    except Exception as e:
        print(f"Warning: Failed to set TESSERACT_CMD '{TESSERACT_CMD}'. Error: {e}", file=sys.stderr)
else:
    # Check if tesseract is callable from PATH (optional check)
    # import shutil
    # if shutil.which("tesseract"):
    #     print("Using 'tesseract' command found in system PATH.")
    # else:
    #     print("Warning: TESSERACT_CMD not set and 'tesseract' not found in PATH. OCR might fail.", file=sys.stderr)
    pass # Assume tesseract is in PATH if TESSERACT_CMD is not set


# --- Google Generative AI (Gemini) Settings ---
GOOGLE_API_KEY = os.getenv("GOOGLE_API_KEY")

# Add a warning during startup if the API key is missing, as Gemini features will be disabled.
if not GOOGLE_API_KEY and DEBUG: # Only show warning in debug mode or always? Let's make it always for clarity.
    print("Warning: GOOGLE_API_KEY environment variable not set. Google Gemini features will be disabled, falling back to OCR where applicable.", file=sys.stderr)


# --- You could add other configurations here as needed ---
# Example: Allowed origins for CORS (though handled in main app middleware now)
# ALLOWED_ORIGINS = os.getenv("ALLOWED_ORIGINS", "*").split(",")

# Example: Rate limiting settings
# RATE_LIMIT_REQUESTS = int(os.getenv("RATE_LIMIT_REQUESTS", 100))
# RATE_LIMIT_WINDOW = int(os.getenv("RATE_LIMIT_WINDOW", 60)) # seconds