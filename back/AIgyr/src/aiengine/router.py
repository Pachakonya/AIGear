from fastapi import APIRouter, Depends, HTTPException, Body
from sqlalchemy.orm import Session
from .schemas import TrailDataInput, GearRecommendation, GearAndHikeResponse
from .knowledge_base import retrieve_gear
import openai
import os
from src.database import get_db
from src.posts.models import TrailData
from pydantic import BaseModel

router = APIRouter(prefix="/aiengine", tags=["AIEngine"])

# Create OpenAI client instance
openai_client = openai.OpenAI(api_key=os.getenv("OPENAI_API_KEY"))

class PromptRequest(BaseModel):
    prompt: str

@router.post("/gear-and-hike-suggest", response_model=GearAndHikeResponse)
async def suggest(request: PromptRequest):
    prompt = request.prompt
    db = next(get_db())
    trail = db.query(TrailData).order_by(TrailData.id.desc()).first()
    if not trail:
        raise HTTPException(status_code=404, detail="No trail data found")
    trail_conditions = trail.trail_conditions or []
    elevation = trail.elevation_gain_meters or 0
    distance = trail.distance_meters or 0
    coordinates = trail.coordinates or []
    context_gear = retrieve_gear(trail_conditions, elevation, distance)

    # Intent detection: check if user is asking for gear
    gear_keywords = ["gear", "packing", "what to bring", "equipment", "pack", "bring"]
    user_prompt_lower = prompt.lower()
    wants_gear = any(kw in user_prompt_lower for kw in gear_keywords)

    system_prompt = (
        "You are a friendly hiking and travel assistant. "
        "If the user asks about gear, packing, or what to bring, provide clear, concise, bullet-pointed gear suggestions. "
        "Otherwise, answer conversationally about hiking or travel. "
        "Always keep your answers concise and easy to read."
    )

    if wants_gear:
        user_message = (
            f"User: {prompt}\n"
            f"Trail Data:\n"
            f"- Distance: {distance/1000:.1f} km\n"
            f"- Elevation Gain: {elevation:.0f} m\n"
            f"- Trail Conditions: {', '.join(trail_conditions)}"
        )
    else:
        user_message = prompt

    # Call OpenAI for gear and/or hike suggestions
    gear_response = openai_client.chat.completions.create(
        model="gpt-4o-mini",
        messages=[
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_message}
        ]
    )
    ai_text = gear_response.choices[0].message.content

    # Simple parsing: split into gear and hike tips if possible
    gear = []
    hike = []
    current = None
    for line in ai_text.split("\n"):
        l = line.strip()
        if not l:
            continue
        if "gear" in l.lower():
            current = "gear"
            continue
        if "tip" in l.lower():
            current = "hike"
            continue
        if l.startswith("•") or l.startswith("-") or l.startswith("*"):
            if current == "gear":
                gear.append(l.lstrip("•-* "))
            elif current == "hike":
                hike.append(l.lstrip("•-* "))
            else:
                hike.append(l.lstrip("•-* "))  # Default to hike if not specified
        else:
            # If not a bullet, treat as a section header or ignore
            continue
    # Fallbacks
    if not gear and wants_gear:
        gear = context_gear[:5] if context_gear else ["Hiking boots", "Water bottle", "First aid kit", "Weather-appropriate clothing", "Navigation tools"]
    if not hike:
        hike = [
            "Check weather conditions before starting",
            "Bring enough water and snacks",
            "Tell someone your hiking plans",
            "Stay on marked trails",
            "Pack out all trash"
        ]
    return {"gear": gear, "hike": hike} 