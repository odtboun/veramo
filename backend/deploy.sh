#!/bin/bash

# Veramo Backend Cloud Run Deployment Script
# Make sure you have gcloud CLI installed and authenticated

set -e

# Configuration
PROJECT_ID="astute-maxim-472510-m8"
SERVICE_NAME="veramo-backend"
REGION="us-east1"
IMAGE_NAME="gcr.io/$PROJECT_ID/$SERVICE_NAME"

echo "🚀 Deploying Veramo Backend to Cloud Run..."

# Build and push the Docker image
echo "📦 Building Docker image..."
docker build -t $IMAGE_NAME .

echo "⬆️ Pushing image to Google Container Registry..."
docker push $IMAGE_NAME

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
