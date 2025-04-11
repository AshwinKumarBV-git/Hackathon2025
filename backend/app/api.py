import base64
import os
import io
import re  # Added for potential LaTeX extraction
from typing import Optional
from fastapi import FastAPI, File, UploadFile, Form, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import pytesseract
from PIL import Image
import fitz  # PyMuPDF
import sympy
from sympy.parsing.sympy_parser import parse_expr, standard_transformations, implicit_multiplication
import numpy as np
import google.generativeai as genai # Added for Gemini

# Import config (assuming app/config.py exists and defines DEBUG)
# If not, define it here:
# DEBUG = os.environ.get("DEBUG", "false").lower() == "true"
from app.config import DEBUG

# --- Removed LLaVA Model Loading ---

# Configure Google AI API Key
# --- IMPORTANT: Store your API Key securely, e.g., in an environment variable ---
try:
    GOOGLE_API_KEY = os.getenv("GOOGLE_API_KEY")
    if not GOOGLE_API_KEY:
        print("Warning: GOOGLE_API_KEY environment variable not set. Gemini API will not be available.")
        GEMINI_AVAILABLE = False
    else:
        genai.configure(api_key=GOOGLE_API_KEY)
        # Check if the vision model is available (optional, but good practice)
        try:
            # Attempt to list models to verify API key works (or use a specific check)
             _ = genai.get_model("models/gemini-1.5-flash") # Or list_models()
             GEMINI_AVAILABLE = True
             print("Google AI (Gemini) configured successfully.")
        except Exception as api_err:
             print(f"Warning: Google AI API key might be invalid or configuration failed: {api_err}")
             GEMINI_AVAILABLE = False

except Exception as e:
    print(f"Error configuring Google AI: {e}")
    GEMINI_AVAILABLE = False


# Initialize FastAPI app
app = FastAPI(
    title="STEM Assistant API",
    description="Backend services for OCR, LaTeX parsing, and PDF processing using Tesseract and Google Gemini.",
    version="1.1.0", # Updated version
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Request models (keep as is)
class ImagePayload(BaseModel):
    image: str
    format: str = "base64"

class MathExpressionPayload(BaseModel):
    expression: str
    format: str = "latex"

# Response models (keep as is)
class OCRResponse(BaseModel):
    result: str
    confidence: Optional[float] = None

class ExplainResponse(BaseModel):
    original: str
    explanation: str

class PDFResponse(BaseModel):
    content: str
    pages: int

class MathImageResponse(BaseModel):
    explanation: str
    latex: Optional[str] = None
    confidence: Optional[float] = None
    success: bool = True
    error: Optional[str] = None


# Helper functions (ocr_image, extract_pdf_text, explain_math_expression, explain_sympy_expression, rule_based_explanation remain largely the same)

def ocr_image(image_data):
    """Process an image with Tesseract OCR."""
    try:
        img = Image.open(io.BytesIO(image_data))

        # Preprocess the image for better OCR
        # Convert to grayscale
        if img.mode != 'L':
            img = img.convert('L')

        # Extract text using Tesseract
        text = pytesseract.image_to_string(img)

        # Calculate confidence if possible
        confidence = None
        try:
            data = pytesseract.image_to_data(img, output_type=pytesseract.Output.DICT)
            if 'conf' in data:
                # Calculate average confidence excluding -1 values
                conf_values = [float(c) for c in data['conf'] if c != -1]
                if conf_values:
                    confidence = sum(conf_values) / len(conf_values)
        except Exception: # Catch specific pytesseract errors if known
            pass

        return text.strip(), confidence
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"OCR processing error: {str(e)}")

def extract_pdf_text(pdf_data):
    """Extract text from a PDF file."""
    try:
        # Open the PDF from binary data - using a dummy filename
        doc = fitz.open(stream=pdf_data, filetype="pdf")
        text = ""
        for page in doc:
            text += page.get_text()

        return {
            "content": text,
            "pages": len(doc)
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"PDF processing error: {str(e)}")

def explain_math_expression(expression, format_type="latex"):
    """Explain a math expression in plain English using SymPy or rules."""
    try:
        # Remove LaTeX formatting if present
        if format_type == "latex":
            # Common LaTeX replacements (keep as is)
            replacements = {
                r"\frac": "/", r"\cdot": "*", r"\times": "*", r"\div": "/",
                r"\sqrt": "sqrt", r"\pi": "pi", r"\alpha": "alpha", r"\beta": "beta",
                r"\sum": "sum", r"\int": "integral", r"\infty": "oo", r"\sin": "sin",
                r"\cos": "cos", r"\tan": "tan", r"\log": "log", r"\ln": "ln",
                r"\exp": "exp", r"^": "**", r"_": "", r"{": "", r"}": "",
                r"\left": "", r"\right": "", r"\lim": "limit",
            }
            clean_expr = expression
            for latex, replacement in replacements.items():
                clean_expr = clean_expr.replace(latex, replacement)

            # Try to parse with SymPy, with implicit multiplication
            transformations = standard_transformations + (implicit_multiplication,)
            try:
                sympy_expr = parse_expr(clean_expr, transformations=transformations)
                explanation = explain_sympy_expression(sympy_expr)
                return {
                    "original": expression,
                    "explanation": explanation
                }
            except Exception as parse_error:
                # Fall back to rule-based explanation if SymPy fails
                print(f"SymPy parsing failed for '{clean_expr}' (from LaTeX '{expression}'): {parse_error}")
                return {
                    "original": expression,
                    "explanation": rule_based_explanation(clean_expr)
                }
        else:
            # Assume plain math expression format
            transformations = standard_transformations + (implicit_multiplication,)
            sympy_expr = parse_expr(expression, transformations=transformations)
            explanation = explain_sympy_expression(sympy_expr)

            return {
                "original": expression,
                "explanation": explanation
            }
    except Exception as e:
        # Catch potential errors during parsing or explanation itself
        print(f"Error explaining math expression '{expression}': {e}")
        # Provide a fallback explanation if SymPy or rule-based fails
        return {
            "original": expression,
            "explanation": f"Could not generate a detailed explanation for: {expression}. Error: {e}"
        }


def explain_sympy_expression(expr):
    """Generate an explanation from a SymPy expression."""
    explanation = ""
    try:
        if isinstance(expr, sympy.Add):
            terms = [str(arg) for arg in expr.args]
            explanation = f"This is an addition of the terms: {', '.join(terms)}"
        elif isinstance(expr, sympy.Mul):
            factors = [str(arg) for arg in expr.args]
            explanation = f"This is a multiplication of the factors: {', '.join(factors)}"
        elif isinstance(expr, sympy.Pow):
            base, exp = expr.args
            explanation = f"This represents {base} raised to the power of {exp}"
        elif isinstance(expr, sympy.Function):
            name = type(expr).__name__
            args = ", ".join([str(arg) for arg in expr.args])
            explanation = f"This is the {name} function applied to {args}"
        elif isinstance(expr, sympy.Equality):
            left, right = expr.args
            explanation = f"This is an equation stating that {left} equals {right}"
        # Add more specific cases as needed (e.g., Integral, Sum, Limit)
        elif isinstance(expr, sympy.Integral):
             func, (var, *bounds) = expr.args
             bound_str = f" from {bounds[0]} to {bounds[1]}" if bounds else ""
             explanation = f"This is the integral of {func} with respect to {var}{bound_str}"
        elif isinstance(expr, sympy.Sum):
             func, (var, lower, upper) = expr.args
             explanation = f"This is the summation of {func} for {var} from {lower} to {upper}"
        elif isinstance(expr, sympy.Limit):
            func, var, point, direction = expr.args
            dir_str = f" from the {direction} direction" if direction != '+' else ""
            explanation = f"This is the limit of {func} as {var} approaches {point}{dir_str}"
        else:
            explanation = f"This is a mathematical expression: {expr}"
            try:
                # Check if it's numeric before evaluating
                if expr.is_number:
                    value = float(expr.evalf())
                    explanation += f". It evaluates to approximately {value:.4f}"
            except (AttributeError, TypeError, ValueError):
                 # Handle cases where evalf() fails or is not applicable
                 pass
    except Exception as e:
        print(f"Error explaining SymPy expression '{expr}': {e}")
        explanation = f"Could not fully explain the expression: {expr}"

    return explanation

def rule_based_explanation(expr_str):
    """Fallback rule-based explanation when SymPy parsing fails."""
    explanation = "This expression "
    ops = []
    if "+" in expr_str: ops.append("addition")
    if "-" in expr_str: ops.append("subtraction")
    if "*" in expr_str: ops.append("multiplication")
    if "/" in expr_str: ops.append("division")
    if "**" in expr_str or "^" in expr_str: ops.append("exponentiation")
    if "sqrt" in expr_str: ops.append("square roots")
    if any(trig in expr_str for trig in ["sin", "cos", "tan"]): ops.append("trigonometric functions")
    if any(func in expr_str for func in ["log", "ln", "exp"]): ops.append("logarithmic or exponential functions")
    if "sum" in expr_str: ops.append("summation")
    if "int" in expr_str: ops.append("integration")
    if "lim" in expr_str: ops.append("limits")

    if ops:
        explanation += "involves " + ", ".join(ops) + "."
    else:
        explanation += f"is '{expr_str}'. A detailed automated explanation could not be generated."

    return explanation


def call_gemini_vision_api(image_data, prompt):
    """Helper function to call the Gemini Vision API."""
    if not GEMINI_AVAILABLE:
        raise ConnectionError("Gemini API is not available (check API key and configuration).")

    try:
        img = Image.open(io.BytesIO(image_data))
        model = genai.GenerativeModel('gemini-1.5-flash')  # Updated model name
        response = model.generate_content([prompt, img], stream=False)
        # Handle potential safety blocks or empty responses
        if not response.parts:
            # Check candidate for blocked prompt/finish reason
            try:
                finish_reason = response.prompt_feedback.block_reason
                if finish_reason:
                    return f"Request blocked due to: {finish_reason}. Explanation could not be generated."
            except Exception:
                pass # No block reason found, might be other issue
            return "Gemini returned an empty response. Could not generate explanation."

        return response.text # Access the generated text content
    except Exception as e:
        print(f"Error calling Gemini Vision API: {e}")
        # Re-raise a more specific error or return None/error indicator
        raise RuntimeError(f"Gemini API call failed: {e}")


def extract_latex(text):
    """Simple heuristic to extract LaTeX from text."""
    # Look for blocks surrounded by $$...$$ or single $...$
    # This is basic and might need refinement
    matches = re.findall(r"\$\$(.*?)\$\$", text, re.DOTALL) # Multiline $$
    if matches:
        return matches[0].strip()
    matches = re.findall(r"\$(.*?)\$", text) # Inline $
    if matches:
        # Return the first or longest match? Let's take the first for now.
        return matches[0].strip()
    # Fallback: Check for explicit markers if Gemini uses them
    if "LaTeX:" in text:
        try:
            latex_part = text.split("LaTeX:")[1].split("\n")[0].strip()
            # Remove potential markdown code fences
            if latex_part.startswith("```") and latex_part.endswith("```"):
                latex_part = latex_part[3:-3].strip()
            if latex_part.startswith("`") and latex_part.endswith("`"):
                 latex_part = latex_part[1:-1].strip()
            return latex_part
        except IndexError:
            pass
    return None


# --- Updated function to process math images ---
def process_math_equation(image_data):
    """Process an image containing mathematical equations using Gemini or OCR fallback."""
    explanation = "Processing failed."
    latex_result = None
    use_gemini = GEMINI_AVAILABLE # Check if API key is set and configured

    print(f"Starting process_math_equation. Gemini available: {use_gemini}")

    if use_gemini:
        try:
            prompt = (
                "Analyze the image containing a mathematical equation or expression. "
                "Provide a clear, step-by-step explanation of what the equation represents, "
                "its components (variables, constants, operators), and its purpose or meaning. "
                "If possible, also provide the equation in standard LaTeX format, clearly marked (e.g., start with 'LaTeX:'). "
                "Describe it as if explaining to someone who cannot see the image."
            )
            print(f"Calling Gemini with prompt: '{prompt[:50]}...'") # Print the beginning of the prompt
            gemini_response = call_gemini_vision_api(image_data, prompt)
            print(f"Gemini response received: '{gemini_response[:100]}...'") # Print the beginning of the response
            explanation = gemini_response
            latex_result = extract_latex(gemini_response) # Try to get LaTeX
            print(f"Extracted LaTeX: '{latex_result}'")
            # Remove the extracted LaTeX part from the main explanation for clarity
            if latex_result and f"LaTeX: {latex_result}" in explanation:
                explanation = explanation.replace(f"LaTeX: {latex_result}", "").strip()
            elif latex_result and f"${latex_result}$" in explanation:
                explanation = explanation.replace(f"${latex_result}$", "").strip()
            elif latex_result and f"$$ {latex_result} $$" in explanation: # Corrected typo: added space
                explanation = explanation.replace(f"$$ {latex_result} $$", "").strip()

            print("Processed math equation using Gemini.")
            return {
                "explanation": explanation,
                "latex": latex_result
            }

        except Exception as gemini_err:
            print(f"Gemini processing failed for math equation: {gemini_err}. Falling back to OCR.")

    # OCR-based processing (fallback)
    print("Using OCR fallback for math equation.")
    try:
        text, confidence = ocr_image(image_data)
        print(f"OCR detected text: '{text}' with confidence: {confidence}")
        if not text:
            explanation = "OCR could not detect any text in the image."
            latex_result = None
        else:
            # Try to extract LaTeX first
            latex_result = extract_latex(text)
            print(f"Extracted LaTeX from OCR: '{latex_result}'")
            if latex_result:
                explanation_result = explain_math_expression(latex_result, format_type="latex")
                explanation = f"LaTeX detected: '{latex_result}'.\nExplanation: {explanation_result['explanation']}"
            else:
                # If no LaTeX found, try explaining the raw OCR text (less reliable)
                explanation_result = explain_math_expression(text, format_type="plain")
                explanation = f"OCR detected text: '{text}'.\nExplanation: {explanation_result['explanation']}"

        return {
            "explanation": explanation,
            "latex": latex_result,
            # "confidence": confidence / 100.0 if confidence is not None else None
        }

    except Exception as ocr_err:
        print(f"OCR processing also failed for math equation: {ocr_err}")
        raise HTTPException(status_code=500, detail=f"Math equation processing error (Gemini unavailable/failed, OCR failed): {ocr_err}")


# --- Updated function to process math plots ---
def process_math_plot(image_data):
    """Process an image containing mathematical plots/graphs using Gemini or OCR fallback."""
    explanation = "Processing failed."
    use_gemini = GEMINI_AVAILABLE

    if use_gemini:
        try:
            prompt = (
                "Analyze the image containing a mathematical plot or graph. Describe it in detail: "
                "1. What type of plot is it (e.g., line graph, bar chart, scatter plot, function plot)? "
                "2. What do the axes represent (including labels and units, if visible)? "
                "3. What is the general trend or pattern shown (e.g., increasing, decreasing, cyclical, correlation)? "
                "4. Are there any key features like intercepts, peaks, troughs, asymptotes, outliers, or specific data points? "
                "5. What is the overall message or conclusion that can be drawn from this visualization? "
                "Explain clearly for someone who cannot see the image."
            )
            gemini_response = call_gemini_vision_api(image_data, prompt)
            explanation = gemini_response
            print("Processed math plot using Gemini.")
            return {
                "explanation": explanation,
                "latex": None # Plots don't usually have a single LaTeX representation
            }

        except Exception as gemini_err:
            print(f"Gemini processing failed for math plot: {gemini_err}. Falling back to OCR description.")
             # Fall through to OCR if Gemini fails

    # OCR-based processing (fallback description)
    print("Using OCR fallback for math plot description.")
    try:
        text, confidence = ocr_image(image_data)
        explanation = "Analyzed using basic OCR (AI description unavailable).\n"
        explanation += "This appears to be a mathematical plot or graph. "

        if text:
             explanation += f"Text detected in the image includes: '{text[:200]}...' (potentially axis labels, title, or legend text). "
             # Basic keyword analysis from OCR text
             text_lower = text.lower()
             if any(axis in text_lower for axis in ["x-axis", "y-axis", "axis", "axes"]):
                 explanation += "Labeled axes might be present. "
             if any(term in text_lower for term in ["function", "curve", "line", "plot of"]):
                 explanation += "It likely displays a function or curve. "
             elif any(term in text_lower for term in ["bar", "histogram", "chart"]):
                 explanation += "It might be a bar chart or histogram. "
             elif any(term in text_lower for term in ["scatter", "points", "data"]):
                 explanation += "It could be a scatter plot showing data points. "
             # Add more rules based on common plot keywords
        else:
             explanation += "No text labels were clearly detected by OCR. "

        explanation += "A more detailed analysis requires visual interpretation."

        return {
            "explanation": explanation,
            "latex": None,
            # "confidence": confidence / 100.0 if confidence is not None else None
        }

    except Exception as ocr_err:
        print(f"OCR processing also failed for math plot: {ocr_err}")
        raise HTTPException(status_code=500, detail=f"Math plot processing error (Gemini unavailable/failed, OCR failed): {ocr_err}")


# API Endpoints (mostly unchanged, but confidence logic updated)

@app.get("/")
async def root():
    return {"message": "STEM Assistant API is running. See /docs for API documentation."}

@app.post("/upload", response_model=OCRResponse)
async def upload_image(file: UploadFile = File(None), payload: ImagePayload = None):
    """
    Process an image to extract text using OCR.
    """
    image_data = None
    if file and payload:
        raise HTTPException(status_code=400, detail="Provide either file upload or base64 image, not both")
    elif file:
        image_data = await file.read()
    elif payload:
        try:
            image_data = base64.b64decode(payload.image)
        except Exception as e:
            raise HTTPException(status_code=400, detail=f"Invalid base64 encoding: {str(e)}")
    else:
        raise HTTPException(status_code=400, detail="Provide either file upload or base64 image")

    text, confidence = ocr_image(image_data)
    # Convert confidence from 0-100 (Tesseract) to 0.0-1.0 (optional, depends on how you want to present it)
    confidence_float = confidence / 100.0 if confidence is not None else None
    return OCRResponse(result=text, confidence=confidence_float)


@app.post("/explain", response_model=ExplainResponse)
async def explain_expression(payload: MathExpressionPayload):
    """
    Explain a mathematical expression (LaTeX or plain text) in plain English.
    """
    result = explain_math_expression(payload.expression, payload.format)
    return ExplainResponse(**result)


@app.post("/pdf-upload", response_model=PDFResponse)
async def upload_pdf(file: UploadFile = File(...)):
    """
    Process a PDF file to extract text.
    """
    if not file.filename.lower().endswith('.pdf'):
        raise HTTPException(status_code=400, detail="Uploaded file must be a PDF")

    pdf_data = await file.read()
    result = extract_pdf_text(pdf_data)
    return PDFResponse(**result)


@app.post("/process-math-image", response_model=MathImageResponse)
async def math_equation_image(file: UploadFile = File(...)):
    """
    Process an image containing mathematical equations using Gemini or OCR.
    """
    if not file.content_type.startswith('image/'):
         return MathImageResponse(
            explanation="", latex=None, confidence=0.0, success=False,
            error="Invalid file format. Please upload an image file (JPG, PNG, etc.)"
         )

    try:
        contents = await file.read()
        result = process_math_equation(contents) # Calls the updated function

        # Assign confidence based on method used (heuristic)
        confidence_score = 0.85 if GEMINI_AVAILABLE and "OCR detected text" not in result["explanation"] else 0.5
        # You could refine confidence based on OCR confidence if fallback was used

        return MathImageResponse(
            explanation=result["explanation"],
            latex=result.get("latex"), # Use .get for safety
            confidence=confidence_score,
            success=True,
            error=None
        )
    except Exception as e:
        error_message = str(e)
        error_detail = error_message
        if DEBUG:
            import traceback
            error_detail = f"{error_message}\n{traceback.format_exc()}"
            print(error_detail)

        return MathImageResponse(
            explanation="Failed to process the math image.",
            latex=None, confidence=0.0, success=False, error=error_detail
        )


@app.post("/process-plot-image", response_model=MathImageResponse)
async def math_plot_image(file: UploadFile = File(...)):
    """
    Process an image containing mathematical plots/graphs using Gemini or OCR.
    """
    if not file.content_type.startswith('image/'):
         return MathImageResponse(
             explanation="", latex=None, confidence=0.0, success=False,
             error="Invalid file format. Please upload an image file (JPG, PNG, etc.)"
         )

    try:
        contents = await file.read()
        result = process_math_plot(contents) # Calls the updated function

        # Assign confidence based on method used (heuristic)
        confidence_score = 0.8 if GEMINI_AVAILABLE and "Analyzed using basic OCR" not in result["explanation"] else 0.4

        return MathImageResponse(
            explanation=result["explanation"],
            latex=result.get("latex"), # Should always be None here
            confidence=confidence_score,
            success=True,
            error=None
        )
    except Exception as e:
        error_message = str(e)
        error_detail = error_message
        if DEBUG:
            import traceback
            error_detail = f"{error_message}\n{traceback.format_exc()}"
            print(error_detail)

        return MathImageResponse(
            explanation="Failed to process the plot image.",
            latex=None, confidence=0.0, success=False, error=error_detail
        )

