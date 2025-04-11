import requests
import base64
from pathlib import Path
import json

# API base URL - change if your server is running elsewhere
BASE_URL = "http://localhost:8000"

def test_ocr_upload():
    """Test the OCR image upload endpoint with a sample image."""
    print("\n--- Testing OCR Upload ---")
    
    # Replace with path to a sample image
    image_path = Path("sample_image.jpg")
    
    if not image_path.exists():
        print(f"Warning: {image_path} does not exist. Skipping OCR test.")
        return
    
    # Test file upload
    with open(image_path, "rb") as img:
        files = {"file": (image_path.name, img, "image/jpeg")}
        response = requests.post(f"{BASE_URL}/upload", files=files)
    
    if response.status_code == 200:
        print("File upload successful!")
        print(f"Extracted text: {json.dumps(response.json()['result'], indent=2)}")
    else:
        print(f"Error: {response.status_code}")
        print(response.text)
    
    # Test base64 upload
    with open(image_path, "rb") as img:
        img_bytes = img.read()
        img_base64 = base64.b64encode(img_bytes).decode("utf-8")
        
        payload = {
            "image": img_base64,
            "format": "base64"
        }
        
        response = requests.post(f"{BASE_URL}/upload", json=payload)
    
    if response.status_code == 200:
        print("Base64 upload successful!")
        print(f"Extracted text: {json.dumps(response.json()['result'], indent=2)}")
    else:
        print(f"Error: {response.status_code}")
        print(response.text)

def test_math_explanation():
    """Test the math explanation endpoint with sample expressions."""
    print("\n--- Testing Math Explanation ---")
    
    # Test expressions - a mix of LaTeX and plain
    expressions = [
        {"expression": r"\frac{-b \pm \sqrt{b^2 - 4ac}}{2a}", "format": "latex"},
        {"expression": r"\sin^2(x) + \cos^2(x) = 1", "format": "latex"},
        {"expression": "x^2 + 2*x + 1", "format": "plain"}
    ]
    
    for expr in expressions:
        response = requests.post(f"{BASE_URL}/explain", json=expr)
        
        if response.status_code == 200:
            print(f"\nExpression: {expr['expression']}")
            print(f"Explanation: {response.json()['explanation']}")
        else:
            print(f"Error: {response.status_code}")
            print(response.text)

def test_pdf_upload():
    """Test the PDF upload endpoint with a sample PDF."""
    print("\n--- Testing PDF Upload ---")
    
    # Replace with path to a sample PDF
    pdf_path = Path("sample.pdf")
    
    if not pdf_path.exists():
        print(f"Warning: {pdf_path} does not exist. Skipping PDF test.")
        return
    
    with open(pdf_path, "rb") as pdf:
        files = {"file": (pdf_path.name, pdf, "application/pdf")}
        response = requests.post(f"{BASE_URL}/pdf-upload", files=files)
    
    if response.status_code == 200:
        result = response.json()
        print(f"PDF upload successful!")
        print(f"Pages: {result['pages']}")
        print(f"First 100 chars of content: {result['content'][:100]}...")
    else:
        print(f"Error: {response.status_code}")
        print(response.text)

if __name__ == "__main__":
    # Test if the API is running
    try:
        response = requests.get(f"{BASE_URL}/")
        if response.status_code == 200:
            print(f"API is running: {response.json()['message']}")
        else:
            print(f"API returned unexpected status: {response.status_code}")
            print(response.text)
    except requests.exceptions.ConnectionError:
        print(f"Error: Could not connect to {BASE_URL}")
        print("Make sure the API server is running.")
        exit(1)
    
    # Run tests
    test_ocr_upload()
    test_math_explanation()
    test_pdf_upload()