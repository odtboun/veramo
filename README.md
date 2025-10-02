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

The backend is a Node.js Express server that provides:
- REST API endpoints
- CORS support for mobile app
- Health check endpoints

## Getting Started

### iOS Development
1. Open `ios/Veramo.xcodeproj` in Xcode
2. Build and run the project

### Backend Development
1. Navigate to `backend/` directory
2. Install dependencies: `npm install`
3. Start development server: `npm run dev`

## Requirements

- Xcode 15.0+
- iOS 17.0+ (target device)
- Node.js 18+
- npm or yarn
