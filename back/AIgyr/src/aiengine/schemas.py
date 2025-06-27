from pydantic import BaseModel
from typing import List

class TrailDataInput(BaseModel):
    coordinates: List[List[float]]
    distance_meters: float
    elevation_gain_meters: float
    trail_conditions: List[str]

class GearRecommendation(BaseModel):
    recommendations: List[str]

class HikeSuggestion(BaseModel):
    suggestions: list[str]

class GearAndHikeResponse(BaseModel):
    gear: list[str]
    hike: list[str] 