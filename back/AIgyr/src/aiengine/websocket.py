# WebSocket implementation (commented out for now - using HTTP instead)

from fastapi import WebSocket, WebSocketDisconnect, Depends
from typing import List, Dict
import json
import asyncio
from .schemas import GearAndHikeResponse
from .knowledge_base import retrieve_gear
from src.posts.models import TrailData
from src.database import get_db, SessionLocal
from sqlalchemy.orm import Session
import openai
import os


class ConnectionManager:
    def __init__(self):
        self.active_connections: List[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)

    def disconnect(self, websocket: WebSocket):
        self.active_connections.remove(websocket)

    async def send_personal_message(self, message: str, websocket: WebSocket):
        await websocket.send_text(message)

    async def broadcast(self, message: str):
        for connection in self.active_connections:
            await connection.send_text(message)

manager = ConnectionManager()

# Create OpenAI client instance
openai_client = openai.OpenAI(api_key=os.getenv("OPENAI_API_KEY"))

async def get_gear_and_hike_suggestions(db: Session) -> GearAndHikeResponse:
    """Get gear and hike suggestions based on latest trail data"""
    trail = db.query(TrailData).order_by(TrailData.id.desc()).first()
    
    if not trail:
        return GearAndHikeResponse(
            gear=["No trail data available. Please upload trail data first."],
            hike=["No trail data available. Please upload trail data first."]
        )
    
    # Retrieve context from knowledge base
    context_gear = retrieve_gear(
        trail.trail_conditions, 
        trail.elevation_gain_meters, 
        trail.distance_meters
    )
    
    # Use OpenAI to generate suggestions
    try:
        response = openai_client.chat.completions.create(
            model="gpt-4-1106-preview",
            messages=[
                {"role": "system", "content": "You are a hiking expert. Provide gear recommendations and hiking tips based on trail data."},
                {"role": "user", "content": f"""
                Trail data:
                - Distance: {trail.distance_meters}m
                - Elevation gain: {trail.elevation_gain_meters}m
                - Trail conditions: {', '.join(trail.trail_conditions)}
                - Available gear context: {', '.join(context_gear)}
                
                Provide:
                1. 5 specific gear recommendations
                2. 5 hiking tips for this trail
                """}
            ],
            max_tokens=500
        )
        
        content = response.choices[0].message.content
        
        # Simple parsing - split by lines and categorize
        lines = content.split('\n')
        gear_suggestions = []
        hike_tips = []
        
        current_section = None
        for line in lines:
            line = line.strip()
            if not line:
                continue
            if 'gear' in line.lower() or 'equipment' in line.lower():
                current_section = 'gear'
            elif 'tip' in line.lower() or 'advice' in line.lower():
                current_section = 'hike'
            elif line.startswith('•') or line.startswith('-') or line.startswith('*'):
                if current_section == 'gear':
                    gear_suggestions.append(line.lstrip('•-* '))
                elif current_section == 'hike':
                    hike_tips.append(line.lstrip('•-* '))
        
        # Fallback if parsing fails
        if not gear_suggestions:
            gear_suggestions = context_gear[:5] if context_gear else ["Hiking boots", "Water bottle", "First aid kit", "Weather-appropriate clothing", "Navigation tools"]
        if not hike_tips:
            hike_tips = [
                "Check weather conditions before starting",
                "Bring enough water and snacks",
                "Tell someone your hiking plans",
                "Stay on marked trails",
                "Pack out all trash"
            ]
        
        return GearAndHikeResponse(gear=gear_suggestions, hike=hike_tips)
        
    except Exception as e:
        # Fallback response
        return GearAndHikeResponse(
            gear=context_gear[:5] if context_gear else ["Hiking boots", "Water bottle", "First aid kit", "Weather-appropriate clothing", "Navigation tools"],
            hike=["Check weather conditions", "Bring enough water", "Tell someone your plans", "Stay on marked trails", "Pack out all trash"]
        )

async def websocket_endpoint(websocket: WebSocket):
    print(f"WebSocket connection attempt from {websocket.client.host}:{websocket.client.port}")
    print(f"Headers: {websocket.headers}")
    print(f"Query params: {websocket.query_params}")

    db = SessionLocal()  # <-- Open a new DB session
    try:
        await manager.connect(websocket)
        print(f"WebSocket connected successfully. Total connections: {len(manager.active_connections)}")
        print(f"Connection URL: {websocket.url}")
        print(f"Connection scheme: {websocket.url.scheme}")
        try:
            while True:
                # Receive message from client
                data = await websocket.receive_text()
                message_data = json.loads(data)
                print(f"Received WebSocket message: {message_data}")
                
                # Handle different message types
                if message_data.get("type") == "chat":
                    user_message = message_data.get("message", "").lower()
                    print(f"Processing chat message: {user_message}")
                    
                    # Check if user is asking for gear/hike suggestions
                    if any(keyword in user_message for keyword in ["gear", "hike", "suggest", "recommend", "what should i bring"]):
                        print("Generating gear and hike suggestions...")
                        # Get suggestions
                        suggestions = await get_gear_and_hike_suggestions(db)
                        
                        # Format response
                        gear_text = "🧢 Gear Suggestions:\n" + "\n".join([f"• {item}" for item in suggestions.gear])
                        hike_text = "🥾 Hike Tips:\n" + "\n".join([f"• {item}" for item in suggestions.hike])
                        response_text = f"{gear_text}\n\n{hike_text}"
                        
                        print(f"Sending response: {response_text}")
                        # Send response
                        await manager.send_personal_message(
                            json.dumps({
                                "type": "response",
                                "message": response_text,
                                "timestamp": asyncio.get_event_loop().time()
                            }),
                            websocket
                        )
                    else:
                        # General chat response
                        response_text = "Ask me for gear or hike suggestions for your latest route!"
                        print(f"Sending general response: {response_text}")
                        await manager.send_personal_message(
                            json.dumps({
                                "type": "response",
                                "message": response_text,
                                "timestamp": asyncio.get_event_loop().time()
                            }),
                            websocket
                        )
            
        except WebSocketDisconnect:
            manager.disconnect(websocket)
            print(f"WebSocket disconnected. Total connections: {len(manager.active_connections)}")
        except Exception as e:
            print(f"WebSocket error: {str(e)}")
            await manager.send_personal_message(
                json.dumps({
                    "type": "error",
                    "message": f"Error: {str(e)}",
                    "timestamp": asyncio.get_event_loop().time()
                }),
                websocket
            )
            manager.disconnect(websocket)
    finally:
        db.close()  # <-- Always close the DB session 