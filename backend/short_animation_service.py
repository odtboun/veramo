from flask import Flask, request, jsonify
from flask_cors import CORS
import os
import fal_client
import base64
import requests

app = Flask(__name__)
CORS(app)


@app.route('/health', methods=['GET'])
def health():
    return jsonify({"status": "OK"})


@app.route('/generate-short-animation', methods=['POST'])
def generate_short_animation():
    try:
        fal_client.api_key = os.getenv('FAL_KEY')
        if not fal_client.api_key:
            return jsonify({"error": "FAL_KEY not set"}), 500

        if request.content_type and request.content_type.startswith('multipart/form-data'):
            # Expecting fields: description (text), image (file)
            description = request.form.get('description', '').strip()
            image_file = request.files.get('image')

            if not description:
                return jsonify({"error": "description is required"}), 400
            if not image_file:
                return jsonify({"error": "image file is required"}), 400

            # Upload image to a temporary storage to obtain a public URL.
            # For simplicity, re-upload to Fal file endpoint to get a URL (Fal supports data URIs/files in workflows).
            # Convert to data URL as fallback.
            image_bytes = image_file.read()
            data_uri = 'data:' + (image_file.mimetype or 'image/jpeg') + ';base64,' + base64.b64encode(image_bytes).decode('utf-8')
            image_url = data_uri
        else:
            # JSON body: { description: string, image_url: string | data_uri }
            data = request.get_json(silent=True) or {}
            description = (data.get('description') or '').strip()
            image_url = (data.get('image_url') or '').strip()
            if not description:
                return jsonify({"error": "description is required"}), 400
            if not image_url:
                return jsonify({"error": "image_url is required"}), 400

        # Submit to Fal workflow
        result = fal_client.submit(
            "workflows/odtboun/short-couple-video",
            arguments={
                "concept_description": description,
                "image_url_field": image_url,
                "negative_prompt": ""
            }
        ).get()

        # Expected result contains a video URL or file reference; map to a consistent schema
        # Try common fields
        video_url = None
        content_type = 'video/mp4'
        file_name = 'short_animation.mp4'

        if isinstance(result, dict):
            # Try direct 'video' object like V2.5 turbo
            if 'video' in result and isinstance(result['video'], dict):
                video = result['video']
                video_url = video.get('url') or video.get('signed_url')
                content_type = video.get('content_type') or content_type
                file_name = video.get('file_name') or file_name
            # Some workflows return 'output' list or 'result' dict
            if not video_url:
                maybe = result.get('output') or result.get('result') or {}
                if isinstance(maybe, dict):
                    video_url = maybe.get('url') or maybe.get('video_url')
                elif isinstance(maybe, list) and maybe:
                    first = maybe[0]
                    if isinstance(first, dict):
                        video_url = first.get('url') or first.get('video_url')

        if not video_url:
            return jsonify({"error": "Failed to retrieve video URL from workflow result", "raw": result}), 502

        return jsonify({
            "video": {
                "url": video_url,
                "content_type": content_type,
                "file_name": file_name
            },
            "error": None
        })

    except Exception as e:
        print(f"Error generating short animation: {e}")
        return jsonify({"error": f"Short animation generation failed: {str(e)}"}), 500


if __name__ == '__main__':
    port = int(os.getenv('PORT', 8080))
    app.run(host='0.0.0.0', port=port, debug=True)


