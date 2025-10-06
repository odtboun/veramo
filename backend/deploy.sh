#!/bin/bash

# Veramo Backend Cloud Run Deployment Script
# Make sure you have gcloud CLI installed and authenticated

set -e

# Configuration
PROJECT_ID="veramo-473923"
SERVICE_NAME="veramo-backend"
REGION="us-east1"
IMAGE_NAME="gcr.io/$PROJECT_ID/$SERVICE_NAME"

echo "🚀 Deploying Veramo Backend to Cloud Run..."

# Build and push the Docker image using Cloud Build
echo "📦 Building and pushing Docker image to Google Container Registry using Cloud Build..."
gcloud builds submit --tag $IMAGE_NAME .

# Deploy to Cloud Run
echo "🚀 Deploying to Cloud Run..."
gcloud run deploy $SERVICE_NAME \
    --image $IMAGE_NAME \
    --platform managed \
    --region $REGION \
    --allow-unauthenticated \
    --port 8080 \
    --memory 512Mi \
    --cpu 1 \
    --max-instances 10 \
    --set-env-vars "GOOGLE_APPLICATION_CREDENTIALS=/app/credentials/service-account-key.json"

echo "✅ Deployment complete!"
echo "🌐 Service URL: https://$SERVICE_NAME-$REGION-$PROJECT_ID.a.run.app"
