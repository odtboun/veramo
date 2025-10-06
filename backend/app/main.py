from flask import Flask, request, jsonify, send_file
from flask_cors import CORS
from werkzeug.utils import secure_filename
import os
import io
from datetime import datetime
from PIL import Image, ImageDraw
import tempfile
import json
import fal_client
import requests

# Initialize Flask app
app = Flask(__name__)
CORS(app)  # Enable CORS for mobile app

# Configuration
UPLOAD_FOLDER = '/tmp/uploads'
ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg', 'gif', 'bmp'}
MAX_FILE_SIZE = 16 * 1024 * 1024  # 16MB max file size

# Ensure upload directory exists
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

def allowed_file(filename):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

def create_solid_color_square(size=512, color=(128, 128, 128)):
    """Create a solid color square image"""
    img = Image.new('RGB', (size, size), color)
    return img

def process_first_image(image_path):
    """Process the first uploaded image: rotate 90 degrees and crop to square"""
    try:
        with Image.open(image_path) as img:
            # Convert to RGB if necessary
            if img.mode != 'RGB':
                img = img.convert('RGB')
            
            # Rotate 90 degrees clockwise
            rotated = img.rotate(-90, expand=True)
            
            # Get dimensions and calculate square crop
            width, height = rotated.size
            size = min(width, height)
            
            # Calculate crop box (center crop)
            left = (width - size) // 2
            top = (height - size) // 2
            right = left + size
            bottom = top + size
            
            # Crop to square
            square_crop = rotated.crop((left, top, right, bottom))
            
            return square_crop
    except Exception as e:
        print(f"Error processing image: {e}")
        return None

def select_model_and_preprocess(description, images, style_label):
    """
    Preprocessing logic to decide what model to use and format inputs
    This is a placeholder for future AI model integration
    """
    # Simple preprocessing logic
    model_type = "default"
    
    # Determine model based on inputs
    if len(images) > 0:
        model_type = "image_based"
    elif len(description) > 100:
        model_type = "text_heavy"
    elif style_label.lower() in ["artistic", "painting", "sketch"]:
        model_type = "artistic"
    
    # Format inputs for the selected model
    formatted_inputs = {
        "model_type": model_type,
        "description": description,
        "style_label": style_label,
        "image_count": len(images),
        "processed_at": datetime.utcnow().isoformat()
    }
    
    return formatted_inputs

def generate_with_fal_ai(description, images, style_label):
    """
    Generate image using fal.ai FLUX Pro Kontext Multi
    """
    try:
        # Configure fal.ai client
        fal_client.api_key = os.getenv('FAL_KEY')
        
        # Upload images to fal.ai storage and get URLs
        image_urls = []
        for img_path in images:
            with open(img_path, 'rb') as f:
                file_data = f.read()
            
            # Upload to fal.ai storage
            upload_result = fal_client.storage.upload(file_data)
            image_urls.append(upload_result['url'])
        
        # Create enhanced prompt with style
        enhanced_prompt = f"{description} (style: {style_label})"
        
        # Prepare the request payload
        payload = {
            "prompt": enhanced_prompt,
            "image_urls": image_urls,
            "sync_mode": True,  # Wait for completion
            "output_format": "png",
            "safety_tolerance": "4",
            "enhance_prompt": True,
            "aspect_ratio": "1:1",
            "num_images": 1
        }
        
        print(f"🚀 Calling fal.ai with payload: {json.dumps(payload, indent=2)}")
        
        # Call fal.ai API
        result = fal_client.subscribe("fal-ai/flux-pro/kontext/multi", payload)
        
        # Download the generated image
        if result and 'data' in result and 'images' in result['data']:
            image_url = result['data']['images'][0]['url']
            response = requests.get(image_url)
            if response.status_code == 200:
                return Image.open(io.BytesIO(response.content))
        
        # Fallback to placeholder if fal.ai fails
        print("⚠️ fal.ai failed, falling back to placeholder")
        return generate_placeholder_image(description, images, style_label)
        
    except Exception as e:
        print(f"❌ fal.ai error: {e}")
        # Fallback to placeholder
        return generate_placeholder_image(description, images, style_label)

def generate_placeholder_image(description, images, style_label):
    """
    Placeholder function that simulates AI image generation
    Returns a processed version of the first image or a solid color square
    """
    if images and len(images) > 0:
        # Process the first image: rotate and crop
        processed_img = process_first_image(images[0])
        if processed_img:
            return processed_img
    
    # Fallback: create solid color square
    # Use style_label to determine color
    color_map = {
        "warm": (255, 200, 150),
        "cool": (150, 200, 255),
        "neutral": (200, 200, 200),
        "vibrant": (255, 100, 100),
        "muted": (150, 150, 150)
    }
    
    color = color_map.get(style_label.lower(), (128, 128, 128))
    return create_solid_color_square(512, color)

# Routes
@app.route('/', methods=['GET'])
def root():
    return jsonify({
        "message": "Veramo Backend API is running!",
        "version": "1.0.0",
        "endpoints": {
            "health": "/health",
            "generate": "/generate-image"
        }
    })

@app.route('/health', methods=['GET'])
def health():
    return jsonify({
        "status": "OK",
        "timestamp": datetime.utcnow().isoformat(),
        "service": "Veramo API",
        "version": "1.0.0"
    })

@app.route('/generate-image', methods=['POST'])
def generate_image():
    """
    Generate an image based on description, images, and style label
    """
    try:
        # Get form data
        description = request.form.get('description', '')
        style_label = request.form.get('style_label', 'neutral')
        
        # Validate inputs
        if not description.strip():
            return jsonify({"error": "Description is required"}), 400
        
        # Handle uploaded images
        images = []
        if 'images' in request.files:
            files = request.files.getlist('images')
            
            # Limit to 5 images
            files = files[:5]
            
            for file in files:
                if file and file.filename and allowed_file(file.filename):
                    # Save file temporarily
                    filename = secure_filename(file.filename)
                    file_path = os.path.join(UPLOAD_FOLDER, filename)
                    file.save(file_path)
                    images.append(file_path)
        
        # Check if we should use fal.ai or placeholder
        use_fal_ai = len(images) >= 2 and description.strip()
        
        if use_fal_ai:
            # Use fal.ai FLUX Pro Kontext Multi
            generated_img = generate_with_fal_ai(description, images, style_label)
        else:
            # Use placeholder function
            generated_img = generate_placeholder_image(description, images, style_label)
        
        # Save generated image to temporary file
        output_path = os.path.join(UPLOAD_FOLDER, f"generated_{datetime.utcnow().strftime('%Y%m%d_%H%M%S')}.png")
        generated_img.save(output_path, 'PNG')
        
        # Clean up input images
        for img_path in images:
            try:
                os.remove(img_path)
            except:
                pass
        
        # Return the generated image
        return send_file(output_path, mimetype='image/png', as_attachment=True, download_name='generated_image.png')
        
    except Exception as e:
        # Clean up any temporary files
        try:
            for img_path in images:
                if os.path.exists(img_path):
                    os.remove(img_path)
        except:
            pass
        
        return jsonify({"error": f"Image generation failed: {str(e)}"}), 500

if __name__ == '__main__':
    port = int(os.getenv('PORT', 8080))
    app.run(host='0.0.0.0', port=port, debug=True)