#!/usr/bin/env python3
"""
Local development server for Veramo Backend
Run with: python run_local.py
"""

import os
import sys
from pathlib import Path

# Add the app directory to Python path
app_dir = Path(__file__).parent / "app"
sys.path.insert(0, str(app_dir))

# Set environment variables for local development
os.environ.setdefault("GOOGLE_APPLICATION_CREDENTIALS", "credentials/service-account-key.json")
os.environ.setdefault("PORT", "8080")

if __name__ == "__main__":
    import uvicorn
    from app.main import app
    
    print("🚀 Starting Veramo Backend locally...")
    print("📱 API will be available at: http://localhost:8080")
    print("📖 API docs at: http://localhost:8080/docs")
    
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=8080,
        reload=True,
        log_level="info"
    )
