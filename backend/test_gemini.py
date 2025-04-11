"""
Test script for Google Gemini Vision integration
Usage: python test_gemini.py <path_to_image>
"""

import os
import sys
from PIL import Image
import google.generativeai as genai

def test_gemini(image_path):
    """Test Google Gemini Pro Vision model with a sample image."""
    print(f"Testing Google Gemini Pro Vision with image: {image_path}")
    
    # Get API key from environment variable
    api_key = os.getenv("GOOGLE_API_KEY")
    if not api_key:
        print("Error: GOOGLE_API_KEY environment variable not set.")
        print("Please set your API key as an environment variable or in a .env file.")
        return False
    
    try:
        # Configure the API
        print("Configuring Google Generative AI API...")
        genai.configure(api_key=api_key)
        
        # Load the image
        print("Loading image...")
        image = Image.open(image_path)
        
        # Prepare prompt for math equation analysis
        math_prompt = (
            "Analyze the image containing a mathematical equation or expression. "
            "Provide a clear, step-by-step explanation of what the equation represents, "
            "its components (variables, constants, operators), and its purpose or meaning. "
            "If possible, also provide the equation in standard LaTeX format, clearly marked (e.g., start with 'LaTeX:'). "
            "Describe it as if explaining to someone who cannot see the image."
        )
        
        # Load the model and generate content
        print("Processing image with Gemini Pro Vision...")
        model = genai.GenerativeModel('gemini-pro-vision')
        response = model.generate_content([math_prompt, image], stream=False)
        
        # Process output
        explanation = response.text
        
        print("\n--- Gemini Output ---")
        print(explanation)
        print("--------------------\n")
        
        # Try to extract LaTeX if present
        if "LaTeX:" in explanation:
            latex_parts = explanation.split("LaTeX:")
            if len(latex_parts) > 1:
                latex = latex_parts[1].strip().split("\n")[0]
                print(f"Extracted LaTeX: {latex}")
        
        # Also test with a plot analysis prompt
        plot_prompt = (
            "Analyze the image containing a mathematical plot or graph. Describe it in detail: "
            "1. What type of plot is it (e.g., line graph, bar chart, scatter plot, function plot)? "
            "2. What do the axes represent (including labels and units, if visible)? "
            "3. What is the general trend or pattern shown (e.g., increasing, decreasing, cyclical, correlation)? "
            "4. Are there any key features like intercepts, peaks, troughs, asymptotes, outliers, or specific data points? "
            "5. What is the overall message or conclusion that can be drawn from this visualization? "
            "Explain clearly for someone who cannot see the image."
        )
        
        print("Processing image as a plot with Gemini Pro Vision...")
        plot_response = model.generate_content([plot_prompt, image], stream=False)
        
        print("\n--- Gemini Plot Analysis ---")
        print(plot_response.text)
        print("-------------------------\n")
        
        return True
    
    except Exception as e:
        print(f"Error testing Gemini: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    # Check for .env file and load environment variables
    try:
        from dotenv import load_dotenv
        # Try to load .env from current directory and parent directory
        if os.path.exists(".env"):
            load_dotenv()
        elif os.path.exists("../.env"):
            load_dotenv("../.env")
    except ImportError:
        print("Warning: python-dotenv not installed. Using existing environment variables.")
    
    if len(sys.argv) != 2:
        print("Usage: python test_gemini.py <path_to_image>")
        sys.exit(1)
    
    image_path = sys.argv[1]
    success = test_gemini(image_path)
    
    if success:
        print("Gemini test completed successfully!")
    else:
        print("Gemini test failed.")
        sys.exit(1) 