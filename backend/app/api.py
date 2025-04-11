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