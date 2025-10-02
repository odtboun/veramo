from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import os
from datetime import datetime
import uvicorn

# Initialize FastAPI app
app = FastAPI(
    title="Veramo API",
    description="Backend API for Veramo mobile app",
    version="1.0.0"
)

# CORS middleware for mobile app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure this properly for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Pydantic models
class HealthResponse(BaseModel):
    status: str
    timestamp: str
    uptime: float
    service: str
    version: str

class UserResponse(BaseModel):
    id: int
    name: str
    email: str
    created_at: str

class APIStatusResponse(BaseModel):
    status: str
    service: str
    version: str
    timestamp: str

# Routes
@app.get("/", response_model=dict)
async def root():
    return {
        "message": "Veramo Backend API is running!",
        "version": "1.0.0",
        "endpoints": {
            "health": "/health",
            "api": "/api/status",
            "user": "/api/user"
        }
    }

@app.get("/health", response_model=HealthResponse)
async def health():
    import time
    return HealthResponse(
        status="OK",
        timestamp=datetime.utcnow().isoformat(),
        uptime=time.time(),
        service="Veramo API",
        version="1.0.0"
    )

@app.get("/api/status", response_model=APIStatusResponse)
async def api_status():
    return APIStatusResponse(
        status="OK",
        service="Veramo API",
        version="1.0.0",
        timestamp=datetime.utcnow().isoformat()
    )

@app.get("/api/user", response_model=UserResponse)
async def get_user():
    return UserResponse(
        id=1,
        name="Veramo User",
        email="user@veramo.app",
        created_at=datetime.utcnow().isoformat()
    )

if __name__ == "__main__":
    port = int(os.getenv("PORT", 8080))
    uvicorn.run(app, host="0.0.0.0", port=port)
