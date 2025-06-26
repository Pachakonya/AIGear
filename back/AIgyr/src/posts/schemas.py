from pydantic import BaseModel
from typing import List

class GearRequest(BaseModel):
    weather: str
    trail_condition: str

class GearResponse(BaseModel):
    recommendations: list[str]

class TrailUploadRequest(BaseModel):
    coordinates: List[List[float]]
    distance_meters: float
    elevation_gain_meters: float
    trail_conditions: List[str]

class UploadResponse(BaseModel):
    message: str
    trail_id: int
