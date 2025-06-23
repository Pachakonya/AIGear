from pydantic import BaseModel
from datetime import datetime

class GearRequest(BaseModel):
    weather: str
    trail_condition: str

class GearResponse(BaseModel):
    recommendations: list[str]

