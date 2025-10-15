from flask import Flask, request, jsonify
from flask_cors import CORS
import os
import fal_client
import json

app = Flask(__name__)
CORS(app)

SYSTEM_PROMPT = (
    "the output should be an audio podcast script about a couple, the podcast speakers are not the couple "
    "they are just talking about the couple. script has exactly 2 speakers, with the following format: \"Speaker 0: "
    "VibeVoice is now available on Fal. Isn't that right, ?\\nSpeaker 1: That's right, and it supports two speakers at once. "
    "Try it now!\". keep the script to less then 20 lines total."
)

@app.route('/health', methods=['GET'])
def health():
    return jsonify({"status": "OK"})

@app.route('/generate-podcast', methods=['POST'])
def generate_podcast():
    try:
        fal_client.api_key = os.getenv('FAL_KEY')
        if not fal_client.api_key:
            return jsonify({"error": "FAL_KEY not set"}), 500

        data = request.get_json(silent=True) or {}
        prompt = data.get('prompt', '')
        if not prompt:
            return jsonify({"error": "Prompt is required"}), 400

        result = fal_client.submit(
            "workflows/odtboun/couplepodcast",
            arguments={
                "prompt": prompt,
                "system_prompt": SYSTEM_PROMPT
            }
        ).get()

        audio_url = None
        duration = None
        if isinstance(result, dict):
            audio = result.get('audio') or {}
            audio_url = audio.get('url')
            duration = result.get('duration')

        if not audio_url:
            return jsonify({"error": "Failed to generate audio or retrieve URL from Fal workflow"}), 500

        return jsonify({
            "audio": {
                "url": audio_url,
                "content_type": "application/octet-stream",
                "file_name": os.path.basename(audio_url)
            },
            "duration": duration,
            "error": None
        })

    except Exception as e:
        return jsonify({"error": f"Podcast generation failed: {str(e)}"}), 500

if __name__ == '__main__':
    port = int(os.getenv('PORT', 8080))
    app.run(host='0.0.0.0', port=port, debug=True)


