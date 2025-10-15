from flask import Flask, request, jsonify
from flask_cors import CORS
import os
import fal_client
import tempfile
from werkzeug.utils import secure_filename

app = Flask(__name__)
CORS(app)


@app.route('/health', methods=['GET'])
def health():
    return jsonify({"status": "OK"})


@app.route('/generate-video-with-audio', methods=['POST'])
def generate_video_with_audio():
    try:
        print(f"DEBUG: Request method: {request.method}")
        print(f"DEBUG: Content type: {request.content_type}")
        print(f"DEBUG: Form data: {dict(request.form)}")
        print(f"DEBUG: Files: {list(request.files.keys())}")
        print(f"DEBUG: JSON: {request.json if request.is_json else 'Not JSON'}")
        
        # Debug each form field individually
        for key, value in request.form.items():
            print(f"DEBUG: Form field '{key}': '{value}'")
        
        # Debug each file individually  
        for key, file in request.files.items():
            print(f"DEBUG: File field '{key}': filename='{file.filename}', content_type='{file.content_type}'")
        
        fal_client.api_key = os.getenv('FAL_KEY')
        if not fal_client.api_key:
            return jsonify({"error": "FAL_KEY not set"}), 500

        description = request.form.get('description') or (request.json.get('description') if request.is_json else None)
        duration_str = request.form.get('duration') or (str(request.json.get('duration')) if request.is_json and request.json.get('duration') is not None else None)
        image_url = request.form.get('image_url') or (request.json.get('image_url') if request.is_json else None)

        print(f"DEBUG: Parsed description: {description}")
        print(f"DEBUG: Parsed duration_str: {duration_str}")
        print(f"DEBUG: Parsed image_url (before file upload): {image_url}")

        # Default duration = 4 if not provided, convert to int
        duration = int(duration_str) if duration_str is not None else 4

        # Handle image file upload -> fal-hosted URL
        if 'image' in request.files and request.files['image'].filename:
            print(f"DEBUG: Processing image file: {request.files['image'].filename}")
            image_file = request.files['image']
            tmp_dir = tempfile.gettempdir()
            tmp_path = os.path.join(tmp_dir, secure_filename(image_file.filename))
            image_file.save(tmp_path)
            try:
                image_url = fal_client.upload_file(tmp_path)
                print(f"DEBUG: Uploaded image to Fal, got URL: {image_url}")
            finally:
                try:
                    os.remove(tmp_path)
                except Exception:
                    pass

        print(f"DEBUG: Final image_url: {image_url}")
        print(f"DEBUG: Final description: {description}")

        if not description or not image_url:
            print(f"DEBUG: Missing required fields - description: {bool(description)}, image_url: {bool(image_url)}")
            return jsonify({"error": "Description and image are required"}), 400

        # Call fal workflow: workflows/odtboun/short-couple-video-audio
        # This workflow expects top-level arguments, not wrapped under "input"
        result = fal_client.submit(
            "workflows/odtboun/short-couple-video-audio",
            arguments={
                "concept_description": description,
                "image_url_field": image_url,
                "duration": duration,
            },
        ).get()

        # Normalize response
        video_url = None
        if isinstance(result, dict):
            # Try common shapes
            if 'video' in result and isinstance(result['video'], dict) and 'url' in result['video']:
                video_url = result['video']['url']
            elif 'url' in result and isinstance(result['url'], str):
                video_url = result['url']

        if video_url:
            return jsonify({
                "video": {
                    "url": video_url,
                    "content_type": "video/mp4",
                    "file_name": os.path.basename(video_url),
                },
                "error": None,
            })

        return jsonify({"error": "Failed to generate video or missing URL in response"}), 500

    except Exception as e:
        return jsonify({"error": f"Video with audio generation failed: {str(e)}"}), 500


if __name__ == '__main__':
    port = int(os.getenv('PORT', 8080))
    app.run(host='0.0.0.0', port=port, debug=True)


