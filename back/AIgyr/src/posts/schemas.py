from pydantic import BaseModel
from typing import List

class TrailUploadRequest(BaseModel):
    coordinates: List[List[float]]
    distance_meters: float
    elevation_gain_meters: float
    trail_conditions: List[str]

class UploadResponse(BaseModel):
    message: str
    trail_id: int

class LatestTrailResponse(BaseModel):
    id: int
    coordinates: List[List[float]]
    distance_meters: float
    elevation_gain_meters: float
    trail_conditions: List[str]

    class Config:
        orm_mode = True