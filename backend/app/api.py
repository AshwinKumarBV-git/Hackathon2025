import base64
import os
import io
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

# Import config
from app.config import DEBUG

# Initialize FastAPI app
app = FastAPI(
    title="STEM Assistant API",
    description="Backend services for OCR, LaTeX parsing, and PDF processing.",
    version="1.0.0",
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Request models
class ImagePayload(BaseModel):
    image: str
    format: str = "base64"

class MathExpressionPayload(BaseModel):
    expression: str
    format: str = "latex"

# Response models
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

# Helper functions
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
        except:
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
    """Explain a math expression in plain English."""
    try:
        # Remove LaTeX formatting if present
        if format_type == "latex":
            # Common LaTeX replacements
            replacements = {
                r"\frac": "/",
                r"\cdot": "*",
                r"\times": "*",
                r"\div": "/",
                r"\sqrt": "sqrt",
                r"\pi": "pi",
                r"\alpha": "alpha",
                r"\beta": "beta",
                r"\sum": "sum",
                r"\int": "integral",
                r"\infty": "oo",  # infinity in sympy
                r"\sin": "sin",
                r"\cos": "cos",
                r"\tan": "tan",
                r"\log": "log",
                r"\ln": "ln",
                r"\exp": "exp",
                r"^": "**",  # exponentiation
                r"_": "",    # subscripts are removed
                r"{": "",    # brackets for grouping in LaTeX
                r"}": "",
                r"\left": "",
                r"\right": "",
                r"\lim": "limit",
            }
            
            # Perform replacements
            clean_expr = expression
            for latex, replacement in replacements.items():
                clean_expr = clean_expr.replace(latex, replacement)
            
            # Try to parse with SymPy, with implicit multiplication
            transformations = standard_transformations + (implicit_multiplication,)
            try:
                sympy_expr = parse_expr(clean_expr, transformations=transformations)
                
                # Generate explanation
                explanation = explain_sympy_expression(sympy_expr)
                return {
                    "original": expression,
                    "explanation": explanation
                }
            except Exception as parse_error:
                # Fall back to rule-based explanation
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
        raise HTTPException(status_code=500, detail=f"Math explanation error: {str(e)}")

def explain_sympy_expression(expr):
    """Generate an explanation from a SymPy expression."""
    explanation = ""
    
    # Check for various expression types
    if isinstance(expr, sympy.Add):
        terms = []
        for arg in expr.args:
            terms.append(str(arg))
        explanation = f"This is an addition of the terms: {', '.join(terms)}"
    
    elif isinstance(expr, sympy.Mul):
        factors = []
        for arg in expr.args:
            factors.append(str(arg))
        explanation = f"This is a multiplication of the factors: {', '.join(factors)}"
    
    elif isinstance(expr, sympy.Pow):
        base, exp = expr.args
        explanation = f"This represents {base} raised to the power of {exp}"
    
    elif isinstance(expr, sympy.Function):
        # For functions like sin, cos, etc.
        name = type(expr).__name__
        args = ", ".join([str(arg) for arg in expr.args])
        explanation = f"This is the {name} function applied to {args}"
    
    elif isinstance(expr, sympy.Equality):
        left, right = expr.args
        explanation = f"This is an equation stating that {left} equals {right}"
    
    else:
        # Default explanation
        explanation = f"This is a mathematical expression: {expr}"
        
        # Try to evaluate if it's a constant expression
        try:
            value = float(expr.evalf())
            explanation += f". It evaluates to approximately {value:.4f}"
        except:
            pass
    
    return explanation

def rule_based_explanation(expr_str):
    """Fallback rule-based explanation when SymPy parsing fails."""
    explanation = "This expression "
    
    # Check for common patterns
    if "+" in expr_str:
        explanation += "involves addition"
    if "-" in expr_str:
        explanation += ", subtraction" if explanation != "This expression " else "involves subtraction"
    if "*" in expr_str or "/" in expr_str:
        explanation += ", multiplication or division" if explanation != "This expression " else "involves multiplication or division"
    if "**" in expr_str or "^" in expr_str:
        explanation += ", and exponentiation" if explanation != "This expression " else "involves exponentiation"
    if "sqrt" in expr_str:
        explanation += ", and square roots" if explanation != "This expression " else "involves square roots"
    if any(trig in expr_str for trig in ["sin", "cos", "tan"]):
        explanation += ", and trigonometric functions" if explanation != "This expression " else "involves trigonometric functions"
    if any(func in expr_str for func in ["log", "ln", "exp"]):
        explanation += ", and logarithmic or exponential functions" if explanation != "This expression " else "involves logarithmic or exponential functions"
    
    if explanation == "This expression ":
        explanation += f"is '{expr_str}', which could not be automatically parsed for a detailed explanation"
    else:
        explanation += "."
    
    return explanation

# Add a function to process math images specifically
def process_math_equation(image_data):
    """Process an image containing mathematical equations.
    
    This function extracts text using OCR optimized for math content,
    attempts to identify LaTeX expressions, and generates explanations.
    """
    try:
        img = Image.open(io.BytesIO(image_data))
        
        # Preprocess the image - convert to grayscale for better OCR results
        if img.mode != 'L':
            img = img.convert('L')
        
        # Use Tesseract with configuration optimized for equations
        custom_config = r'--oem 3 --psm 6 -c textord_max_noise_size=5'
        text = pytesseract.image_to_string(img, config=custom_config)
        
        # Attempt to clean up and identify math expressions
        # Remove extra whitespace and line breaks
        cleaned_text = ' '.join(text.split())
        
        # If we have math-specific OCR tools, we'd use them here
        # For now, we'll treat the extracted text as a math expression
        
        latex_expr = cleaned_text  # In a real system, we'd convert to LaTeX here
        
        # Try to explain the expression
        try:
            explanation_result = explain_math_expression(cleaned_text, format_type="plain")
            explanation = explanation_result["explanation"]
        except Exception as explain_err:
            # Fallback explanation if parsing fails
            explanation = f"The detected equation appears to be: {cleaned_text}. " + \
                         "I'm unable to provide a detailed explanation for this equation."
        
        return {
            "explanation": explanation,
            "latex": latex_expr
        }
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Math equation processing error: {str(e)}")

def process_math_plot(image_data):
    """Process an image containing mathematical plots or graphs.
    
    This function analyzes plot images and provides descriptions of the 
    visual content, identifying axes, trends, and mathematical features.
    """
    try:
        img = Image.open(io.BytesIO(image_data))
        
        # In a real implementation, this would use computer vision to analyze the plot
        # For now, we'll provide a placeholder analysis based on OCR text
        
        # Extract any text labels from the image
        text = pytesseract.image_to_string(img)
        
        # Create a basic explanation
        explanation = "This appears to be a mathematical plot or graph. "
        
        # Check for common terms in the OCR text
        if any(axis in text.lower() for axis in ["x-axis", "y-axis", "axis", "axes"]):
            explanation += "The image contains labeled axes. "
        
        if any(term in text.lower() for term in ["function", "curve", "line", "parabola", "hyperbola"]):
            explanation += "There appears to be a mathematical function or curve displayed. "
        
        if any(term in text.lower() for term in ["bar", "histogram", "chart"]):
            explanation += "This might be a bar chart or histogram. "
        
        if any(term in text.lower() for term in ["scatter", "point", "plot"]):
            explanation += "This looks like a scatter plot with data points. "
        
        # Add a general statement about the extracted text
        if text.strip():
            explanation += f"The following text was detected in the image: {text.strip()}"
        else:
            explanation += "No text labels were detected in this plot."
        
        return {
            "explanation": explanation,
            "latex": None  # Plots typically don't have a direct LaTeX representation
        }
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Math plot processing error: {str(e)}")

# API Endpoints
@app.get("/")
async def root():
    return {"message": "STEM Assistant API is running. See /docs for API documentation."}

@app.post("/upload", response_model=OCRResponse)
async def upload_image(file: UploadFile = File(None), payload: ImagePayload = None):
    """
    Process an image to extract text using OCR.
    
    The image can be provided either as a file upload or as a base64-encoded string.
    """
    if file and payload:
        raise HTTPException(status_code=400, detail="Provide either a file upload or a base64-encoded image, not both")
    elif file:
        # Read image from file upload
        image_data = await file.read()
    elif payload:
        # Decode base64 image
        try:
            image_data = base64.b64decode(payload.image)
        except Exception as e:
            raise HTTPException(status_code=400, detail=f"Invalid base64 encoding: {str(e)}")
    else:
        raise HTTPException(status_code=400, detail="Provide either a file upload or a base64-encoded image")
    
    # Process the image with OCR
    text, confidence = ocr_image(image_data)
    
    return OCRResponse(result=text, confidence=confidence)

@app.post("/explain", response_model=ExplainResponse)
async def explain_expression(payload: MathExpressionPayload):
    """
    Explain a mathematical expression in plain English.
    
    The expression can be provided in LaTeX format or as a plain math expression.
    """
    result = explain_math_expression(payload.expression, payload.format)
    return result

@app.post("/pdf-upload", response_model=PDFResponse)
async def upload_pdf(file: UploadFile = File(...)):
    """
    Process a PDF file to extract text.
    """
    if not file.filename.lower().endswith('.pdf'):
        raise HTTPException(status_code=400, detail="Uploaded file must be a PDF")
    
    # Read PDF file
    pdf_data = await file.read()
    
    # Extract text from PDF
    result = extract_pdf_text(pdf_data)
    
    return PDFResponse(**result)

@app.post("/process-math-image", response_model=MathImageResponse)
async def math_equation_image(file: UploadFile = File(...)):
    """
    Process an image containing mathematical equations.
    
    This endpoint accepts an image file containing mathematical equations,
    extracts the equations using OCR, and provides an explanation.
    
    - **file**: An image file (.jpg, .png, etc.) containing mathematical equations
    
    Returns an explanation of the detected mathematical content.
    """
    if not file.filename.lower().endswith(('.png', '.jpg', '.jpeg', '.tiff', '.bmp', '.gif')):
        raise HTTPException(status_code=400, detail="Invalid file format. Please upload an image file.")
    
    try:
        contents = await file.read()
        
        # Process the math equation image
        result = process_math_equation(contents)
        
        return result
    except Exception as e:
        if DEBUG:
            # Include traceback in debug mode
            import traceback
            error_detail = f"{str(e)}\n{traceback.format_exc()}"
        else:
            error_detail = str(e)
        
        raise HTTPException(status_code=500, detail=f"Error processing math image: {error_detail}")

@app.post("/process-plot-image", response_model=MathImageResponse)
async def math_plot_image(file: UploadFile = File(...)):
    """
    Process an image containing mathematical plots or graphs.
    
    This endpoint accepts an image file containing plots, graphs, or charts,
    analyzes the visual content, and provides a description.
    
    - **file**: An image file (.jpg, .png, etc.) containing a mathematical plot
    
    Returns an explanation of the plot's features and content.
    """
    if not file.filename.lower().endswith(('.png', '.jpg', '.jpeg', '.tiff', '.bmp', '.gif')):
        raise HTTPException(status_code=400, detail="Invalid file format. Please upload an image file.")
    
    try:
        contents = await file.read()
        
        # Process the math plot image
        result = process_math_plot(contents)
        
        return result
    except Exception as e:
        if DEBUG:
            # Include traceback in debug mode
            import traceback
            error_detail = f"{str(e)}\n{traceback.format_exc()}"
        else:
            error_detail = str(e)
        
        raise HTTPException(status_code=500, detail=f"Error processing plot image: {error_detail}")