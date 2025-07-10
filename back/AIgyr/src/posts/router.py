from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from typing import List
from sqlalchemy.orm import Session
from src.database import get_db
from src.posts.models import TrailData  # Assuming you have this in models.py
from src.auth.dependencies import get_current_user
from src.auth.models import User

from src.posts.schemas import TrailUploadRequest, LatestTrailResponse

router = APIRouter(prefix="/gear", tags=["Gear"])

# 🚀 New upload endpoint with inline CRUD
class TrailUploadRequest(BaseModel):
    coordinates: List[List[float]]
    distance_meters: float
    elevation_gain_meters: float
    trail_conditions: List[str]

class UploadResponse(BaseModel):
    message: str
    trail_id: int


@router.post("/upload", response_model=UploadResponse)
def upload_trail_data(
    request: TrailUploadRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    try:
        trail = TrailData(
            user_id=current_user.id,  # Associate with current user
            coordinates=request.coordinates,
            distance_meters=request.distance_meters,
            elevation_gain_meters=request.elevation_gain_meters,
            trail_conditions=request.trail_conditions
        )
        db.add(trail)
        db.commit()
        db.refresh(trail)
        
        # Clean up old trail data - keep only the 3 most recent
        user_trails = db.query(TrailData).filter(
            TrailData.user_id == current_user.id
        ).order_by(TrailData.id.desc()).all()
        
        if len(user_trails) > 3:
            # Delete trails beyond the 3 most recent
            trails_to_delete = user_trails[3:]  # Everything after the first 3
            for old_trail in trails_to_delete:
                db.delete(old_trail)
            db.commit()
            print(f"Cleaned up {len(trails_to_delete)} old trail(s) for user {current_user.id}")

        return {"message": "Trail data uploaded successfully", "trail_id": trail.id}

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/latest", response_model=LatestTrailResponse)
def get_latest_trail(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    # Get latest trail for the current user only
    trail = db.query(TrailData).filter(
        TrailData.user_id == current_user.id
    ).order_by(TrailData.id.desc()).first()
    
    if not trail:
        raise HTTPException(status_code=404, detail="No trail data found")
    return trail
