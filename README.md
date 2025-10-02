# Veramo Mobile App

A mobile application built with iOS and backend components.

## Project Structure

```
veramo/
├── ios/                 # iOS app (SwiftUI)
│   └── Veramo.xcodeproj
├── backend/             # Node.js backend
│   ├── package.json
│   └── index.js
└── README.md
```

## iOS App

The iOS app is built with SwiftUI and supports:
- iOS 17.0+ with Liquid Glass design system
- Fallback components for older iOS versions
- Modern SwiftUI architecture

## Backend

The backend is a Python FastAPI server deployed on Google Cloud Run that provides:
- REST API endpoints with automatic OpenAPI documentation
- CORS support for mobile app
- Health check endpoints
- Cloud Run deployment with auto-scaling
- Google Cloud integration

## Getting Started

### iOS Development
1. Open `ios/Veramo.xcodeproj` in Xcode
2. Build and run the project

### Backend Development (Local)
1. Navigate to `backend/` directory
2. Create virtual environment: `python -m venv venv`
3. Activate virtual environment: `source venv/bin/activate` (macOS/Linux) or `venv\Scripts\activate` (Windows)
4. Install dependencies: `pip install -r requirements.txt`
5. Start development server: `python run_local.py`

### Backend Deployment (Cloud Run)
1. Install Google Cloud CLI and authenticate
2. Run deployment script: `./deploy.sh`
3. Service will be available at the provided Cloud Run URL

## Requirements

- Xcode 15.0+
- iOS 17.0+ (target device)
- Python 3.11+
- Google Cloud CLI (for deployment)
- Docker (for containerization)
