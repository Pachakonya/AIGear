from fastapi import APIRouter, Depends, HTTPException, Body
from sqlalchemy.orm import Session
from .schemas import TrailDataInput, GearRecommendation, GearAndHikeResponse
from .knowledge_base import retrieve_gear
import openai
import os
import json
from src.database import get_db
from src.posts.models import TrailData
from pydantic import BaseModel
from typing import List, Dict, Any, Optional
from src.auth.dependencies import get_current_user
from src.auth.models import User

router = APIRouter(prefix="/aiengine", tags=["AIEngine"])

# Create OpenAI client instance
openai_client = openai.OpenAI(api_key=os.getenv("OPENAI_API_KEY"))

class PromptRequest(BaseModel):
    prompt: str

class OrchestratorResponse(BaseModel):
    tool_used: str
    parameters: Dict[str, Any]
    response: str
    raw_response: Optional[str] = None

# Tool implementations
def gear_recommendation_tool(terrain: List[str] = None, weather: str = None, distance: float = None, elevation: float = None, user_id: str = None) -> str:
    """Recommend hiking gear based on conditions"""
    db = next(get_db())
    
    # Get user-specific trail data if user_id provided
    trail = None
    if user_id:
        trail = db.query(TrailData).filter(
            TrailData.user_id == user_id
        ).order_by(TrailData.id.desc()).first()
    
    recommendations = []
    
    # Merge trail data with provided parameters
    if trail:
        # Use trail data if parameters not provided
        if terrain is None and trail.trail_conditions:
            terrain = trail.trail_conditions
        if distance is None and trail.distance_meters:
            distance = trail.distance_meters / 1000  # Convert to km
        if elevation is None and trail.elevation_gain_meters:
            elevation = trail.elevation_gain_meters
    
    # Generate recommendations based on conditions
    if terrain:
        for t in terrain:
            t_lower = t.lower()
            if "rocky" in t_lower:
                recommendations.extend(["Hiking boots with ankle support", "Trekking poles"])
            elif "muddy" in t_lower:
                recommendations.extend(["Waterproof boots", "Gaiters"])
            elif "snowy" in t_lower:
                recommendations.extend(["Insulated boots", "Microspikes", "Warm layers"])
            elif "steep" in t_lower:
                recommendations.extend(["Trekking poles", "High-traction footwear"])
            elif "river" in t_lower or "stream" in t_lower:
                recommendations.extend(["Water shoes", "Quick-dry towel", "Waterproof bag"])
    
    if weather:
        weather_lower = weather.lower()
        if "rain" in weather_lower:
            recommendations.extend(["Rain jacket", "Pack cover", "Waterproof pants"])
        elif "hot" in weather_lower or "sunny" in weather_lower:
            recommendations.extend(["Sun hat", "Lightweight clothing", "Extra water", "Sunscreen"])
        elif "cold" in weather_lower:
            recommendations.extend(["Insulated jacket", "Gloves", "Warm hat", "Thermal layers"])
        elif "wind" in weather_lower:
            recommendations.extend(["Windbreaker", "Buff or neck gaiter"])
    
    if distance:
        if distance > 15:
            recommendations.extend(["Larger backpack (30-40L)", "Extra snacks", "Blister prevention kit", "Electrolyte supplements"])
        elif distance > 10:
            recommendations.extend(["Day pack (20-30L)", "Trail snacks", "Blister plasters"])
        else:
            recommendations.extend(["Small day pack (15-20L)", "Light snacks"])
    
    if elevation:
        if elevation > 1000:
            recommendations.extend(["Layers for temperature changes", "Extra water", "High-energy snacks", "Altitude sickness medication"])
        elif elevation > 500:
            recommendations.extend(["Extra layer", "Additional water", "Energy bars"])
    
    # Add essentials that are always recommended
    essentials = ["First aid kit", "Navigation (map/GPS)", "Emergency whistle", "Headlamp"]
    recommendations.extend(essentials)
    
    # Remove duplicates while preserving order
    seen = set()
    unique_recommendations = []
    for item in recommendations:
        if item not in seen:
            seen.add(item)
            unique_recommendations.append(item)
    
    # Format the response
    response = "Based on your trail conditions, I recommend:\n\n"
    
    # Group recommendations by category
    clothing = [r for r in unique_recommendations if any(word in r.lower() for word in ["jacket", "pants", "hat", "gloves", "layers", "clothing", "windbreaker", "gaiter"])]
    footwear = [r for r in unique_recommendations if any(word in r.lower() for word in ["boots", "shoes", "microspikes"])]
    equipment = [r for r in unique_recommendations if any(word in r.lower() for word in ["poles", "backpack", "pack"])]
    safety = [r for r in unique_recommendations if any(word in r.lower() for word in ["first aid", "navigation", "gps", "whistle", "headlamp"])]
    consumables = [r for r in unique_recommendations if any(word in r.lower() for word in ["water", "snacks", "bars", "electrolyte", "sunscreen"])]
    other = [r for r in unique_recommendations if r not in clothing + footwear + equipment + safety + consumables]
    
    if footwear:
        response += "👟 **Footwear:**\n" + "\n".join([f"• {item}" for item in footwear]) + "\n\n"
    if clothing:
        response += "👕 **Clothing:**\n" + "\n".join([f"• {item}" for item in clothing]) + "\n\n"
    if equipment:
        response += "🎒 **Equipment:**\n" + "\n".join([f"• {item}" for item in equipment]) + "\n\n"
    if consumables:
        response += "💧 **Food & Hydration:**\n" + "\n".join([f"• {item}" for item in consumables]) + "\n\n"
    if safety:
        response += "🚨 **Safety Essentials:**\n" + "\n".join([f"• {item}" for item in safety]) + "\n\n"
    if other:
        response += "📦 **Other Items:**\n" + "\n".join([f"• {item}" for item in other]) + "\n\n"
    
    # Add context about the recommendations
    if trail:
        response += f"_These recommendations are based on: {distance or trail.distance_meters/1000:.1f}km distance"
        if elevation or trail.elevation_gain_meters:
            response += f", {elevation or trail.elevation_gain_meters:.0f}m elevation gain"
        if terrain or trail.trail_conditions:
            response += f", {', '.join(terrain or trail.trail_conditions)} conditions"
        response += "_"
    
    return response

def wardrobe_inventory_tool(item: str, action: str = "check") -> str:
    """Check or manage user's wardrobe inventory"""
    # In a real implementation, this would query a user's inventory database
    # For now, we'll simulate with some common items
    common_items = ["hiking boots", "rain jacket", "backpack", "water bottle", "first aid kit", "trekking poles"]
    
    if action == "check":
        if any(item.lower() in ci for ci in common_items):
            return f"✓ You have '{item}' in your wardrobe. It's ready for your next hike!"
        else:
            return f"✗ '{item}' is not in your wardrobe. Would you like gear recommendations for this?"
    elif action == "add":
        return f"Added '{item}' to your wardrobe inventory."
    elif action == "remove":
        return f"Removed '{item}' from your wardrobe inventory."
    
    return f"I can help you {action} '{item}' in your wardrobe."

def trail_analysis_tool(analyze_elevation: bool = False, analyze_difficulty: bool = False, user_id: str = None) -> str:
    """Analyze the latest trail data"""
    db = next(get_db())
    
    # Get user-specific trail data
    query = db.query(TrailData)
    if user_id:
        query = query.filter(TrailData.user_id == user_id)
    trail = query.order_by(TrailData.id.desc()).first()
    
    if not trail:
        return "No trail data available. Please upload a trail first."
    
    analysis = []
    
    if analyze_elevation or analyze_difficulty:
        distance_km = (trail.distance_meters or 0) / 1000
        elevation_m = trail.elevation_gain_meters or 0
        
        if analyze_elevation:
            analysis.append(f"📊 Elevation Analysis:")
            analysis.append(f"• Total gain: {elevation_m:.0f}m")
            analysis.append(f"• Average grade: {(elevation_m/trail.distance_meters*100):.1f}%")
            
            if elevation_m > 1000:
                analysis.append("• Classification: Significant elevation gain - prepare for a challenging climb")
            elif elevation_m > 500:
                analysis.append("• Classification: Moderate elevation gain - good workout")
            else:
                analysis.append("• Classification: Gentle elevation - suitable for most fitness levels")
        
        if analyze_difficulty:
            analysis.append(f"\n🥾 Difficulty Assessment:")
            # Simple difficulty calculation
            difficulty_score = (elevation_m / 100) + (distance_km * 0.5)
            
            if difficulty_score > 15:
                analysis.append("• Difficulty: Hard - experienced hikers recommended")
            elif difficulty_score > 8:
                analysis.append("• Difficulty: Moderate - some hiking experience helpful")
            else:
                analysis.append("• Difficulty: Easy - great for beginners")
            
            if trail.trail_conditions:
                analysis.append(f"• Trail conditions: {', '.join(trail.trail_conditions)}")
    
    return "\n".join(analysis) if analysis else "Please specify what aspect of the trail you'd like me to analyze."

def chat_tool(question: str) -> str:
    """General hiking and travel chat"""
    # Use GPT for general hiking/travel questions
    response = openai_client.chat.completions.create(
        model="gpt-4o-mini",
        messages=[
            {"role": "system", "content": "You are a friendly hiking and travel assistant. Answer questions concisely and helpfully."},
            {"role": "user", "content": question}
        ],
        max_tokens=300
    )
    return response.choices[0].message.content

# Tool definitions for OpenAI function calling
TOOLS = [
    {
        "type": "function",
        "function": {
            "name": "gear_recommendation_tool",
            "description": "Recommend hiking gear based on terrain, weather, distance, and elevation",
            "parameters": {
                "type": "object",
                "properties": {
                    "terrain": {
                        "type": "array",
                        "items": {"type": "string"},
                        "description": "List of terrain types (e.g., rocky, muddy, snowy)"
                    },
                    "weather": {
                        "type": "string",
                        "description": "Weather conditions (e.g., rainy, hot, cold)"
                    },
                    "distance": {
                        "type": "number",
                        "description": "Hiking distance in kilometers"
                    },
                    "elevation": {
                        "type": "number",
                        "description": "Elevation gain in meters"
                    }
                },
                "required": []
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "wardrobe_inventory_tool",
            "description": "Check, add, or remove items from user's hiking gear wardrobe",
            "parameters": {
                "type": "object",
                "properties": {
                    "item": {
                        "type": "string",
                        "description": "The gear item to check/add/remove"
                    },
                    "action": {
                        "type": "string",
                        "enum": ["check", "add", "remove"],
                        "description": "Action to perform on the item"
                    }
                },
                "required": ["item"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "trail_analysis_tool",
            "description": "Analyze trail data for elevation profile and difficulty assessment",
            "parameters": {
                "type": "object",
                "properties": {
                    "analyze_elevation": {
                        "type": "boolean",
                        "description": "Whether to analyze elevation profile"
                    },
                    "analyze_difficulty": {
                        "type": "boolean",
                        "description": "Whether to assess trail difficulty"
                    }
                },
                "required": []
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "chat_tool",
            "description": "General hiking and travel Q&A for questions not covered by other tools",
            "parameters": {
                "type": "object",
                "properties": {
                    "question": {
                        "type": "string",
                        "description": "The user's question about hiking or travel"
                    }
                },
                "required": ["question"]
            }
        }
    }
]

# Tool execution mapping
TOOL_FUNCTIONS = {
    "gear_recommendation_tool": gear_recommendation_tool,
    "wardrobe_inventory_tool": wardrobe_inventory_tool,
    "trail_analysis_tool": trail_analysis_tool,
    "chat_tool": chat_tool
}

@router.post("/orchestrate", response_model=OrchestratorResponse)
async def orchestrate(
    request: PromptRequest,
    current_user: User = Depends(get_current_user)
):
    """AI Agent Orchestrator that selects and executes appropriate tools based on user input"""
    db = next(get_db())
    # Get user-specific trail data
    trail = db.query(TrailData).filter(
        TrailData.user_id == current_user.id
    ).order_by(TrailData.id.desc()).first()
    
    trail_context = ""
    if trail:
        trail_context = f"\n\nLatest Trail Data Available:\n"
        trail_context += f"- Distance: {(trail.distance_meters or 0)/1000:.1f} km\n"
        trail_context += f"- Elevation Gain: {trail.elevation_gain_meters or 0:.0f} m\n"
        if trail.trail_conditions:
            trail_context += f"- Trail Conditions: {', '.join(trail.trail_conditions)}\n"
    
    # System prompt for the orchestrator
    system_prompt = f"""You are AI Gear Assistant, an intelligent hiking guide. Your job is to:
1. Understand the user's request
2. Select the most appropriate tool to handle their request
3. Call the tool with the right parameters extracted from their message

Available tools:
- gear_recommendation_tool: For gear/equipment suggestions based on conditions
- wardrobe_inventory_tool: To check/manage items the user owns
- trail_analysis_tool: To analyze trail difficulty and elevation
- chat_tool: For general hiking/travel questions

Always choose the most specific tool for the task. Only use chat_tool if no other tool fits.
{trail_context}
When the user asks for gear recommendations without specifying conditions, use the trail data context to inform your parameters."""

    # Get tool selection from OpenAI
    response = openai_client.chat.completions.create(
        model="gpt-4o",
        messages=[
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": request.prompt}
        ],
        tools=TOOLS,
        tool_choice="auto"
    )
    
    message = response.choices[0].message
    
    # Check if a tool was called
    if message.tool_calls:
        tool_call = message.tool_calls[0]
        tool_name = tool_call.function.name
        tool_args = json.loads(tool_call.function.arguments)
        
        # Add user_id to args for tools that need it
        if tool_name in ["gear_recommendation_tool", "trail_analysis_tool"]:
            tool_args["user_id"] = current_user.id
        
        # Execute the selected tool
        tool_function = TOOL_FUNCTIONS.get(tool_name)
        if tool_function:
            try:
                tool_result = tool_function(**tool_args)
            except Exception as e:
                tool_result = f"Error executing tool: {str(e)}"
        else:
            tool_result = f"Tool {tool_name} not implemented"
        
        # Format the response
        formatted_response = f"**Tool Used:** `{tool_name}`\n"
        formatted_response += f"**Parameters:** {', '.join(f'{k}: {v}' for k, v in tool_args.items())}\n\n"
        formatted_response += f"**Assistant:**\n{tool_result}"
        
        return OrchestratorResponse(
            tool_used=tool_name,
            parameters=tool_args,
            response=tool_result,
            raw_response=formatted_response
        )
    else:
        # No tool was selected, use the AI's direct response
        ai_response = message.content or "I'm not sure how to help with that. Could you please rephrase your request?"
        
        return OrchestratorResponse(
            tool_used="direct_response",
            parameters={},
            response=ai_response,
            raw_response=ai_response
        )

# Keep the original endpoint for backward compatibility
@router.post("/gear-and-hike-suggest", response_model=GearAndHikeResponse)
async def suggest(request: PromptRequest):
    """Legacy endpoint - redirects to orchestrator"""
    orchestrator_result = await orchestrate(request)
    
    # Parse the response to fit the old format
    gear = []
    hike = []
    
    if orchestrator_result.tool_used == "gear_recommendation_tool":
        # Extract gear items from the response
        lines = orchestrator_result.response.split('\n')
        for line in lines:
            if line.strip().startswith('•'):
                gear.append(line.strip('• '))
    else:
        # For other tools, put the response in hike tips
        hike = [orchestrator_result.response]
    
    # Add default hike tips if empty
    if not hike:
        hike = [
            "Start early to avoid crowds",
            "Stay hydrated throughout your hike",
            "Follow Leave No Trace principles",
            "Check weather before heading out",
            "Tell someone your hiking plans"
        ]
    
    return {"gear": gear, "hike": hike} 