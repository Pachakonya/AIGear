from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from typing import List
from sqlalchemy.orm import Session
from src.database import get_db
from src.posts.models import TrailData  # Assuming you have this in models.py

from src.posts.schemas import TrailUploadRequest, LatestTrailResponse

router = APIRouter(prefix="/gear", tags=["Gear"])

# 🚀 Existing recommend endpoint
# @router.post("/recommend", response_model=GearResponse)
# def recommend_gear(request: GearRequest):
#     recs = []

#     if request.weather == "rainy":
#         recs.append("Rain Jacket")
#     if request.trail_condition == "rocky":
#         recs.append("Hiking Boots")

#     return {"recommendations": recs}


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
    db: Session = Depends(get_db)
):
    try:
        trail = TrailData(
            coordinates=request.coordinates,
            distance_meters=request.distance_meters,
            elevation_gain_meters=request.elevation_gain_meters,
            trail_conditions=request.trail_conditions
        )
        db.add(trail)
        db.commit()
        db.refresh(trail)

        return {"message": "Trail data uploaded successfully", "trail_id": trail.id}

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/latest", response_model=LatestTrailResponse)
def get_latest_trail(db: Session = Depends(get_db)):
    trail = db.query(TrailData).order_by(TrailData.id.desc()).first()
    if not trail:
        raise HTTPException(status_code=404, detail="No trail data found")
    return trail
