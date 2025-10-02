# Veramo - AI Couples App

An AI-powered couples app that helps partners create, share, and cherish daily moments through intelligent image generation and editing.

## Project Structure

```
veramo/
├── docs/                # Documentation
│   └── PRD.md          # Product Requirements Document
├── ios/                 # iOS app (SwiftUI)
│   └── Veramo.xcodeproj
├── backend/             # Python FastAPI backend
│   ├── app/            # FastAPI application
│   ├── credentials/    # Service account keys
│   └── requirements.txt
└── README.md
```

## 🎯 Core Features

- **AI-Powered Image Generation**: Create unique images using text prompts and personal photos
- **Shared Calendar**: Schedule and share images with your partner
- **Personal Galleries**: Private image collections for each partner
- **Widget Integration**: Daily photo widget showing partner's latest image
- **Streak Tracking**: Build daily sharing habits together
- **Smart Scheduling**: Plan surprises for future dates

## iOS App

The iOS app is built with SwiftUI and supports:
- **iOS 26+** with Liquid Glass design system (primary target)
- **Fallback components** for older iOS versions
- **Adapty.io integration** for subscription management
- **WidgetKit** for home screen widgets
- **Core Image** for image editing capabilities

## Backend

The backend is a Python FastAPI server deployed on Google Cloud Run that provides:
- **AI Integration**: Fal.ai models for image generation and editing
- **Database**: Supabase for auth, storage, and data
- **Authentication**: Apple and Google Sign-In support
- **Image Processing**: Three AI model types for different use cases
- **Cloud Run Deployment**: Auto-scaling serverless functions

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

## 🔧 Technical Stack

### Frontend
- **SwiftUI** with iOS 26+ Liquid Glass design
- **Adapty.io** for subscription management
- **WidgetKit** for home screen widgets
- **Core Image** for image editing

### Backend
- **Python FastAPI** for API server
- **Google Cloud Run** for deployment
- **Supabase** for database, auth, and storage
- **Fal.ai** for AI image generation

### AI Models
- **Text-to-Image**: Generate images from text prompts
- **Image + Text**: Transform existing images with text guidance
- **Multi-Image + Text**: Edit multiple images together

## Requirements

- Xcode 15.0+
- iOS 26+ (primary target), fallback for older versions
- Python 3.11+
- Google Cloud CLI (for deployment)
- Docker (for containerization)
- Supabase account
- Fal.ai API access
