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
import traceback

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
        print(f"🔑 FAL_KEY set: {bool(os.getenv('FAL_KEY'))}")
        
        # Upload images to fal.ai storage and get URLs
        image_urls = []
        for i, img_path in enumerate(images):
            print(f"📤 Uploading image {i+1}/{len(images)}: {img_path}")
            try:
                # Try different upload methods
                upload_result = None
                
                # Method 1: Try fal_client.upload_file()
                try:
                    upload_result = fal_client.upload_file(img_path)
                    print(f"📤 Method 1 (upload_file) result: {upload_result}")
                except Exception as e:
                    print(f"📤 Method 1 failed: {e}")
                
                # Method 2: Try fal_client.storage.upload()
                if not upload_result:
                    try:
                        upload_result = fal_client.storage.upload(img_path)
                        print(f"📤 Method 2 (storage.upload) result: {upload_result}")
                    except Exception as e:
                        print(f"📤 Method 2 failed: {e}")
                
                # Method 3: Try fal_client.upload()
                if not upload_result:
                    try:
                        upload_result = fal_client.upload(img_path)
                        print(f"📤 Method 3 (upload) result: {upload_result}")
                    except Exception as e:
                        print(f"📤 Method 3 failed: {e}")
                
                if not upload_result:
                    raise Exception("All upload methods failed")
                
                # Handle different response formats
                if isinstance(upload_result, dict) and 'url' in upload_result:
                    image_urls.append(upload_result['url'])
                    print(f"✅ Image {i+1} uploaded successfully: {upload_result['url']}")
                elif isinstance(upload_result, str):
                    # If it's a string, it might be the URL directly
                    image_urls.append(upload_result)
                    print(f"✅ Image {i+1} uploaded successfully (string): {upload_result}")
                else:
                    print(f"❌ Unexpected upload result format: {upload_result}")
                    raise Exception(f"Unexpected upload result format: {type(upload_result)}")
                    
            except Exception as upload_error:
                print(f"❌ Upload error for image {i+1}: {upload_error}")
                print(f"❌ Upload error traceback: {traceback.format_exc()}")
                raise upload_error
        
        print(f"📋 Total image URLs: {len(image_urls)}")
        
        # Create enhanced prompt with style
        enhanced_prompt = f"{description} (style: {style_label})"
        print(f"📝 Enhanced prompt: {enhanced_prompt}")
        
        # Prepare the request payload
        payload = {
            "prompt": enhanced_prompt,
            "image_urls": image_urls,
            "sync_mode": False,  # Don't wait for completion
            "output_format": "jpeg",
            "safety_tolerance": "4",
            "enhance_prompt": True,
            "aspect_ratio": "1:1",
            "num_images": 1
        }
        
        print(f"🚀 Calling fal.ai with payload: {json.dumps(payload, indent=2)}")
        
        # Call fal.ai API
        result_handle = fal_client.submit("fal-ai/flux-pro/kontext/multi", payload)
        print(f"🎯 fal.ai result handle type: {type(result_handle)}")
        print(f"🎯 fal.ai result handle: {result_handle}")
        
        # Get the actual result from the handle
        try:
            result = result_handle.get()
            print(f"🎯 fal.ai result type: {type(result)}")
            print(f"🎯 fal.ai result: {result}")
            
            # Download the generated image
            print(f"🔍 Checking result structure...")
            print(f"🔍 Result keys: {list(result.keys()) if isinstance(result, dict) else 'Not a dict'}")
            print(f"🔍 Full result structure: {result}")
            
            # Try different possible result formats
            image_url = None
            
            # Format 1: result['data']['images'][0]['url']
            if result and 'data' in result and 'images' in result['data']:
                image_url = result['data']['images'][0]['url']
                print(f"🖼️ Found image URL (format 1): {image_url}")
            
            # Format 2: result['images'][0]['url'] (direct images array)
            elif result and 'images' in result:
                image_url = result['images'][0]['url']
                print(f"🖼️ Found image URL (format 2): {image_url}")
            
            # Format 3: result['data']['url'] (single image)
            elif result and 'data' in result and 'url' in result['data']:
                image_url = result['data']['url']
                print(f"🖼️ Found image URL (format 3): {image_url}")
            
            # Format 4: result['url'] (direct URL)
            elif result and 'url' in result:
                image_url = result['url']
                print(f"🖼️ Found image URL (format 4): {image_url}")
            
            if image_url:
                print(f"🖼️ Generated image URL: {image_url}")
                print(f"🖼️ Image URL type: {type(image_url)}")
                print(f"🖼️ Image URL value: {repr(image_url)}")
                
                # Validate URL before making request - be more lenient
                url_str = str(image_url).strip()
                print(f"🔍 URL validation - original: {repr(image_url)}")
                print(f"🔍 URL validation - string: {repr(url_str)}")
                print(f"🔍 URL validation - starts with http: {url_str.startswith('http')}")
                print(f"🔍 URL validation - starts with data: {url_str.startswith('data:')}")
                print(f"🔍 URL validation - length: {len(url_str)}")
                
                # Check if it's a base64 data URL
                if url_str.startswith('data:image/'):
                    print("🖼️ Found base64 data URL, decoding directly")
                    try:
                        # Extract base64 data from data URL
                        header, data = url_str.split(',', 1)
                        print(f"🔍 Data URL header: {header}")
                        print(f"🔍 Data length: {len(data)}")
                        
                        # Decode base64 data
                        image_data = base64.b64decode(data)
                        print("✅ Successfully decoded base64 image data")
                        return Image.open(io.BytesIO(image_data))
                    except Exception as decode_error:
                        print(f"❌ Base64 decode error: {decode_error}")
                        print("⚠️ Base64 decode failed, falling back to placeholder")
                        return generate_placeholder_image(description, images, style_label)
                
                # More lenient URL validation for HTTP URLs - just check if it's a non-empty string
                elif not url_str or len(url_str) < 10:
                    print(f"❌ Invalid image URL format: {repr(image_url)}")
                    print("⚠️ Invalid URL format, falling back to placeholder")
                    return generate_placeholder_image(description, images, style_label)
                
                # Try to download the image from HTTP URL
                print(f"🖼️ Attempting to download image from: {url_str}")
                try:
                    response = requests.get(url_str, timeout=30)
                    print(f"🖼️ Download response status: {response.status_code}")
                    if response.status_code == 200:
                        print("✅ Successfully downloaded generated image")
                        return Image.open(io.BytesIO(response.content))
                    else:
                        print(f"❌ Failed to download image: {response.status_code}")
                        print(f"❌ Response content: {response.text[:200]}...")
                        print("⚠️ Image download failed, falling back to placeholder")
                        return generate_placeholder_image(description, images, style_label)
                except Exception as download_error:
                    print(f"❌ Download error: {download_error}")
                    print("⚠️ Image download failed, falling back to placeholder")
                    return generate_placeholder_image(description, images, style_label)
            else:
                print(f"❌ No image URL found in result: {result}")
                # Fallback to placeholder if result format is unexpected
                print("⚠️ Unexpected result format, falling back to placeholder")
                return generate_placeholder_image(description, images, style_label)
        except Exception as e:
            print(f"❌ Error getting result from fal.ai: {e}")
            print(f"❌ Error type: {type(e)}")
            import traceback
            print(f"❌ Traceback: {traceback.format_exc()}")
            # Fallback to placeholder if any error occurs
            print("⚠️ fal.ai error, falling back to placeholder")
            return generate_placeholder_image(description, images, style_label)
        
    except Exception as e:
        print(f"❌ fal.ai error: {e}")
        import traceback
        print(f"❌ Full traceback: {traceback.format_exc()}")
        # Fallback to placeholder
        return generate_placeholder_image(description, images, style_label)

def generate_with_nano_banana(description, style_label):
    """
    Generate image using fal.ai nano-banana for text-only generation
    """
    try:
        # Configure fal.ai client
        fal_client.api_key = os.getenv('FAL_KEY')
        print(f"🔑 FAL_KEY set: {bool(fal_client.api_key)}")
        
        if not fal_client.api_key:
            print("❌ FAL_KEY not set, falling back to placeholder")
            return generate_placeholder_image(description, [], style_label)

        # Create enhanced prompt with style - try a simpler approach
        if style_label and style_label != "none":
            enhanced_prompt = f"{description}, {style_label} style"
        else:
            enhanced_prompt = description
        print(f"📝 Enhanced prompt: {enhanced_prompt}")
        
        # Prepare the request arguments for nano-banana (matching playground format)
        arguments = {
            "prompt": enhanced_prompt,
            "num_images": 1,
            "output_format": "jpeg",
            "aspect_ratio": "1:1",
            "sync_mode": False  # Don't wait for completion
        }
        
        print(f"🚀 Calling fal.ai nano-banana with arguments: {json.dumps(arguments, indent=2)}")
        
        # Call fal.ai nano-banana API using run method
        result = fal_client.run("fal-ai/nano-banana", arguments)
        print(f"🎯 fal.ai result type: {type(result)}")
        print(f"🎯 fal.ai result: {result}")
        
        # Download the generated image
        print(f"🔍 Checking result structure...")
        print(f"🔍 Result keys: {list(result.keys()) if isinstance(result, dict) else 'Not a dict'}")
        print(f"🔍 Full result structure: {result}")
        
        # Try different possible result formats for nano-banana
        image_url = None
        
        # Format 1: result['data']['images'][0]['url']
        if result and 'data' in result and 'images' in result['data'] and len(result['data']['images']) > 0:
            image_url = result['data']['images'][0]['url']
            print(f"🖼️ Found image URL (format 1): {image_url}")
        
        # Format 2: result['images'][0]['url'] (direct images array)
        elif result and 'images' in result and len(result['images']) > 0:
            image_url = result['images'][0]['url']
            print(f"🖼️ Found image URL (format 2): {image_url}")
        
        # Format 3: result['data']['url'] (single image)
        elif result and 'data' in result and 'url' in result['data']:
            image_url = result['data']['url']
            print(f"🖼️ Found image URL (format 3): {image_url}")
        
        # Format 4: result['url'] (direct URL)
        elif result and 'url' in result:
            image_url = result['url']
            print(f"🖼️ Found image URL (format 4): {image_url}")
        
        if image_url:
            # Validate URL before making request
            url_str = str(image_url).strip()
            print(f"🔍 URL validation - original: {repr(image_url)}")
            print(f"🔍 URL validation - string: {repr(url_str)}")
            print(f"🔍 URL validation - starts with http: {url_str.startswith('http')}")
            print(f"🔍 URL validation - starts with data: {url_str.startswith('data:')}")
            
            # Check if it's a base64 data URL
            if url_str.startswith('data:image/'):
                print("🖼️ Found base64 data URL, decoding directly")
                try:
                    # Extract base64 data from data URL
                    header, data = url_str.split(',', 1)
                    print(f"🔍 Data URL header: {header}")
                    print(f"🔍 Data length: {len(data)}")
                    
                    # Decode base64 data
                    image_data = base64.b64decode(data)
                    print("✅ Successfully decoded base64 image data")
                    return Image.open(io.BytesIO(image_data))
                except Exception as decode_error:
                    print(f"❌ Base64 decode error: {decode_error}")
                    print("⚠️ Base64 decode failed, falling back to placeholder")
                    return generate_placeholder_image(description, [], style_label)
            
            elif not url_str.startswith('http'):
                print(f"❌ Invalid image URL format: {repr(image_url)}")
                print("⚠️ Invalid URL format, falling back to placeholder")
                return generate_placeholder_image(description, [], style_label)

            print(f"🖼️ Generated image URL: {image_url}")
            response = requests.get(image_url)
            if response.status_code == 200:
                print("✅ Successfully downloaded generated image from nano-banana")
                return Image.open(io.BytesIO(response.content))
            else:
                print(f"❌ Failed to download image: {response.status_code}")
                # Fallback to placeholder if download fails
                print("⚠️ Image download failed, falling back to placeholder")
                return generate_placeholder_image(description, [], style_label)
        else:
            print(f"❌ No image URL found in result: {result}")
            # Fallback to placeholder if result format is unexpected
            print("⚠️ Unexpected result format, falling back to placeholder")
            return generate_placeholder_image(description, [], style_label)
            
    except Exception as e:
        print(f"❌ fal.ai nano-banana error: {e}")
        print(f"❌ Error type: {type(e)}")
        print(f"❌ Traceback: {traceback.format_exc()}")
        # Fallback to placeholder
        print("⚠️ fal.ai nano-banana error, falling back to placeholder")
        return generate_placeholder_image(description, [], style_label)

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
        use_fal_ai = description.strip()  # Use fal.ai if we have a description
        
        if use_fal_ai:
            if len(images) >= 2:
                # Use fal.ai FLUX Pro Kontext Multi for multi-image generation
                generated_img = generate_with_fal_ai(description, images, style_label)
            elif len(images) == 0:
                # Use fal.ai nano-banana for text-only generation (no images)
                generated_img = generate_with_nano_banana(description, style_label)
            else:
                # Use placeholder function for single image (fal.ai doesn't handle single images well)
                generated_img = generate_placeholder_image(description, images, style_label)
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