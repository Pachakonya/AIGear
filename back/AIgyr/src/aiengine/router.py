from fastapi import APIRouter, Depends, HTTPException, Body
from sqlalchemy.orm import Session
from .schemas import TrailDataInput, GearRecommendation, GearAndHikeResponse
from .knowledge_base import retrieve_gear
import openai
import os
import json
import requests
from datetime import datetime, timedelta
from src.database import get_db
from src.posts.models import TrailData
from pydantic import BaseModel
from typing import List, Dict, Any, Optional
from src.auth.dependencies import get_current_user
from src.auth.models import User
from .weather_service import (
    fetch_current_weather, 
    fetch_comprehensive_weather,
    fetch_weather_forecast,
    fetch_hourly_weather,
    get_weather_alerts,
    sample_coordinates,
    sample_trail_endpoints
)

router = APIRouter(prefix="/aiengine", tags=["AIEngine"])

# Create OpenAI client instance
openai_client = openai.OpenAI(api_key=os.getenv("OPENAI_API_KEY"))

class PromptRequest(BaseModel):
    prompt: str
    user_latitude: Optional[float] = None
    user_longitude: Optional[float] = None
    location_accuracy: Optional[float] = None

class OrchestratorResponse(BaseModel):
    tool_used: str
    parameters: Dict[str, Any]
    response: str
    raw_response: Optional[str] = None

# Tool implementations
def gear_recommendation_tool(
    terrain: List[str] = None,
    weather: str = None,
    distance: float = None,
    elevation: float = None,
    days: int = None,
    overnight: bool = False,
    season: str = None,
    companions: int = None,
    user_id: str = None
) -> str:
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
    
    # ⛅️ Only auto-fetch weather if explicitly requested via weather parameter
    temp_c: Optional[float] = None  # Track temperature for advice later
    # Note: Removed automatic weather fetching to avoid unwanted weather info in responses
    # Weather will only be included if explicitly passed as a parameter
    
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
        elif "cold" in weather_lower or (temp_c is not None and temp_c < 5):
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
    
    # ✅ NEW LOGIC – trip-specific parameters ---------------------------

    # Overnight trips => shelter & camp systems
    if overnight:
        recommendations.extend([
            "Tent or Tarp (suitable for conditions)",
            "Sleeping bag rated for expected lows",
            "Sleeping pad",
            "Backpacking stove & fuel",
            "Cookware & utensils",
            "Food storage / Bear canister if required"
        ])

    # Multi-day factor – food, clothing redundancy, water treatment
    if days and days > 1:
        recommendations.extend([
            f"Meals & snacks for {days} days",
            "Spare socks (≥2 pairs)",
            "Water treatment / filtration system",
            "Extra fuel (if using stove)"
        ])

    # Seasonal adjustments
    if season:
        season_lower = season.lower()
        if season_lower == "winter":
            recommendations.extend([
                "Insulating mid-layer (fleece or puffy)",
                "Down or synthetic parka",
                "Snow shovel",
                "Four-season (winter-rated) tent",
                "Crampons / snow spikes"
            ])
        elif season_lower == "shoulder":
            recommendations.extend([
                "Light insulation layer",
                "Pack rain cover or dry bags"
            ])
        # Summer – usually covered by hot/sunny weather logic, but add bugs
        elif season_lower == "summer":
            recommendations.extend([
                "Insect repellent",
                "Lightweight sleeping bag or liner"
            ])

    # Group size could influence first-aid or shelter; simple example
    if companions and companions > 4:
        recommendations.append("Group-sized first-aid kit")
    
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
    
    # 🌤 Weather & timing information
    if weather:
        response += f"🌤 **Current Weather:** {weather.capitalize()}"
        if temp_c is not None:
            response += f", {temp_c:.1f}°C"
        response += "\n"

        # Basic timing advice based on weather / temperature
        advice_parts = []
        harsh_conditions = any(w in weather.lower() for w in ["storm", "thunder", "heavy rain", "snow"])
        if harsh_conditions:
            advice_parts.append("⚠️ Forecast looks harsh – consider rescheduling or selecting an alternative day with better weather.")
        else:
            if "rain" in weather.lower():
                advice_parts.append("☔ Expect rainfall – start early and pack waterproof gear.")
            if temp_c is not None:
                if temp_c > 30:
                    advice_parts.append("🥵 High temperatures – start at sunrise to avoid midday heat and carry extra water.")
                elif temp_c < 0:
                    advice_parts.append("❄️ Sub-zero temperatures – begin later in the morning when it's a bit warmer and dress in insulated layers.")
        if advice_parts:
            response += "\n".join(advice_parts) + "\n\n"
    
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

def hiking_plan_tool(
    start_time: str = None,
    include_safety_prep: bool = True,
    include_duration_estimate: bool = True,
    user_id: str = None
) -> str:
    """Generate comprehensive hiking plan with timing, safety, and preparation recommendations"""
    db = next(get_db())
    trail = db.query(TrailData).filter(
        TrailData.user_id == user_id
    ).order_by(TrailData.id.desc()).first()
    
    # Default to 6:00 AM if no start time specified
    if not start_time:
        start_time = "6:00 AM"
    
    plan_sections = []
    
    # Header
    plan_sections.append("🗓️ Comprehensive Hiking Plan")
    plan_sections.append("")
    
    if trail:
        distance_km = (trail.distance_meters or 0) / 1000
        elevation_m = trail.elevation_gain_meters or 0
        
        # Calculate estimated duration using Naismith's rule + modifications
        # Base time: 1 hour per 5km + 1 hour per 600m elevation gain
        base_time_hours = (distance_km / 5) + (elevation_m / 600)
        
        # Add time for breaks (10 minutes per hour of hiking)
        break_time_hours = base_time_hours * 0.17
        total_time_hours = base_time_hours + break_time_hours
        
        # Convert to hours and minutes
        hours = int(total_time_hours)
        minutes = int((total_time_hours - hours) * 60)
        
        if include_duration_estimate:
            plan_sections.append("⏰ **Timing & Duration**")
            plan_sections.append(f"• **Recommended start time:** {start_time}")
            plan_sections.append(f"• **Estimated hiking time:** {hours}h {minutes}min")
            plan_sections.append(f"• **Distance:** {distance_km:.1f} km")
            plan_sections.append(f"• **Elevation gain:** {elevation_m:.0f}m")
            
            # Calculate return time
            try:
                start_dt = datetime.strptime(start_time, "%I:%M %p")
                end_dt = start_dt + timedelta(hours=total_time_hours)
                plan_sections.append(f"• **Estimated return:** {end_dt.strftime('%I:%M %p')}")
            except ValueError:
                # Fallback for invalid time format
                plan_sections.append(f"• **Estimated return:** Approximately {hours} hours after {start_time}")
            
            plan_sections.append("")
    
    if include_safety_prep:
        plan_sections.append("🛡️ **Essential Safety Preparations**")
        plan_sections.append("")
        
        plan_sections.append("**Before You Leave:**")
        plan_sections.append("• **Inform trusted contacts** - Share your hiking plan, route, and expected return time with family/friends")
        plan_sections.append("• **Check weather forecast** - Verify conditions and adjust plans if necessary")
        plan_sections.append("• **Prepare gear the night before** - Lay out all clothing and equipment to avoid morning rush")
        plan_sections.append("• **Charge devices** - Ensure phone, GPS, and any electronic gear are fully charged")
        plan_sections.append("")
        
        plan_sections.append("**Gear & Clothing Prep:**")
        plan_sections.append("• **Layer your clothing** - Base layer, insulating layer, and weather-proof outer shell")
        plan_sections.append("• **Pack extra clothing** - Bring backup layers in case of weather changes")
        plan_sections.append("• **Check your boots** - Ensure they're broken in and suitable for the terrain")
        plan_sections.append("• **Emergency supplies** - First aid kit, whistle, emergency shelter/blanket")
        plan_sections.append("")
        
        plan_sections.append("**Day-of Checklist:**")
        plan_sections.append(f"• **Early start advantage** - Starting early (like {start_time}) helps avoid crowds, heat, and afternoon weather")
        plan_sections.append("• **Hydration strategy** - Bring more water than you think you need (0.5L per hour minimum)")
        plan_sections.append("• **Nutrition planning** - Pack high-energy snacks and a proper lunch if it's a long hike")
        plan_sections.append("• **Leave No Trace** - Pack out all trash and respect wildlife")
        plan_sections.append("")
    
    plan_sections.append("**Why Start Early?**")
    plan_sections.append("• **Cooler temperatures** - More comfortable hiking conditions")
    plan_sections.append("• **Better visibility** - Clearer views before afternoon haze")
    plan_sections.append("• **Avoid crowds** - Peaceful trail experience")
    plan_sections.append("• **Weather safety** - Return before potential afternoon storms")
    plan_sections.append("• **Wildlife activity** - Better chances of spotting morning-active animals")
    plan_sections.append("")
    
    plan_sections.append("⚠️ **Important Safety Reminders:**")
    plan_sections.append("• Always tell someone your specific hiking plans and expected return time")
    plan_sections.append("• Turn back if weather conditions deteriorate")
    plan_sections.append("• Stay on marked trails and follow all posted regulations")
    plan_sections.append("• Carry emergency communication device for remote areas")
    
    return "\n".join(plan_sections)

def gear_rental_tool(
    location: str = None,
    latitude: float = None,
    longitude: float = None,
    radius: int = 25000,
    user_id: str = None
) -> str:
    """Find hiking gear rental locations using Google Places API"""
    api_key = os.getenv("GOOGLE_PLACES_API_KEY")
    if not api_key:
        return """⚠️ **Google Places API Setup Required**

To enable gear rental search, please:
1. Visit Google Cloud Console: https://console.cloud.google.com/
2. Enable Geocoding API and Places API (New)
3. Create an API key and add it to your .env file"""
    
    lat = None
    lng = None
    formatted_address = None
    
    # Priority 1: Use provided coordinates if available
    if latitude is not None and longitude is not None:
        lat = latitude
        lng = longitude
        formatted_address = f"Your current location ({lat:.4f}, {lng:.4f})"
        
        # Reverse geocode to get readable address
        try:
            reverse_geocode_url = "https://maps.googleapis.com/maps/api/geocode/json"
            reverse_params = {
                "latlng": f"{lat},{lng}",
                "key": api_key
            }
            reverse_response = requests.get(reverse_geocode_url, params=reverse_params, timeout=10)
            reverse_data = reverse_response.json()
            
            if reverse_data.get("status") == "OK" and reverse_data.get("results"):
                formatted_address = reverse_data["results"][0]["formatted_address"]
        except (requests.RequestException, KeyError, ValueError):
            # If reverse geocoding fails, use coordinates
            pass
    
    # Priority 2: Use location string if no coordinates provided
    elif location:
        geocode_url = "https://maps.googleapis.com/maps/api/geocode/json"
        geocode_params = {
            "address": location,
            "key": api_key
        }
        
        try:
            geocode_response = requests.get(geocode_url, params=geocode_params, timeout=10)
            geocode_data = geocode_response.json()
            
            # Handle API authorization errors
            if geocode_data.get("status") == "REQUEST_DENIED":
                error_msg = geocode_data.get("error_message", "API access denied")
                return f"""❌ **Google Places API Configuration Issue**

{error_msg}

**Quick Fix:**
1. Go to Google Cloud Console: https://console.cloud.google.com/
2. Navigate to APIs & Services > Library
3. Enable: Geocoding API and Places API (New)
4. Check your API key restrictions"""
            
            if geocode_data["status"] != "OK" or not geocode_data["results"]:
                return f"""❌ Could not find location: {location}

**Try these alternatives:**
• Use a more specific address (e.g., "Seattle, Washington, USA")
• Include state/country (e.g., "Denver, Colorado")
• Try nearby major cities

**Popular hiking areas to search:**
• Seattle, WA (for Cascades access)
• Denver, CO (for Rocky Mountains)
• Salt Lake City, UT (for Utah's national parks)
• Asheville, NC (for Appalachian trails)"""
            
            # Get coordinates from geocoding result
            location_data = geocode_data["results"][0]
            lat = location_data["geometry"]["location"]["lat"]
            lng = location_data["geometry"]["location"]["lng"]
            formatted_address = location_data["formatted_address"]
            
        except (requests.RequestException, KeyError, ValueError) as e:
            return f"""❌ **Connection Error**

Unable to connect to Google Places API: {str(e)}

**Manual alternatives for finding gear rentals:**
• Search "outdoor gear rental near [your location]" on Google Maps
• Check REI, Patagonia, or local outdoor stores
• Visit camping/hiking forums for local recommendations
• Ask at visitor centers near trailheads"""
    
    # Priority 3: No location provided - ask user
    else:
        return """📍 **Location needed for gear rental search**

I can help you find nearby gear rental shops! Please either:
• Share your current location 📍
• Tell me a city or area (e.g., "Seattle, WA")
• Or specify where you're planning to hike

**Popular hiking areas:**
• Seattle, WA (for Cascades access)
• Denver, CO (for Rocky Mountains)  
• Salt Lake City, UT (for Utah's national parks)
• Asheville, NC (for Appalachian trails)"""
    
    # Search for outdoor gear rental places
    places_url = "https://maps.googleapis.com/maps/api/place/nearbysearch/json"
    
    # Search terms for hiking/outdoor gear rental - more specific to avoid unrelated businesses
    search_queries = [
        "outdoor equipment rental hiking camping",
        "sporting goods rental outdoor gear", 
        "adventure gear rental hiking",
        "outdoor outfitters rental",
        "camping hiking equipment rental",
        "REI outdoor gear rental"  # Include known outdoor brands
    ]
    
    all_places = []
    
    for query in search_queries:
        params = {
            "location": f"{lat},{lng}",
            "radius": radius,
            "keyword": query,
            "type": "store",
            "key": api_key
        }
        
        try:
            response = requests.get(places_url, params=params, timeout=10)
            data = response.json()
            
            if data["status"] == "OK":
                all_places.extend(data["results"])
                
        except (requests.RequestException, KeyError, ValueError):
            continue
    
    # Filter out businesses that are clearly not outdoor gear related
    outdoor_keywords = [
        "outdoor", "hiking", "camping", "adventure", "mountain", "trek", 
        "climbing", "backpack", "gear", "equipment", "outfitter", "sporting goods",
        "rei", "patagonia", "north face", "sports", "expedition", "alpine", "trail"
    ]
    
    exclude_keywords = [
        "car", "auto", "vehicle", "truck", "motorcycle", "scooter", "bike rental",
        "apartment", "house", "property", "real estate", "gravity", "finance"
    ]
    
    filtered_places = []
    for place in all_places:
        name = place.get("name", "").lower()
        types = place.get("types", [])
        
        # Skip if it contains excluded keywords
        if any(keyword in name for keyword in exclude_keywords):
            continue
            
        # Skip if it's clearly not outdoor-related establishment type
        if "car_rental" in types or "gas_station" in types or "real_estate_agency" in types:
            continue
            
        # Only include if it has outdoor-related keywords OR is a sporting goods store
        has_outdoor_keywords = any(keyword in name for keyword in outdoor_keywords)
        is_sporting_goods = "sporting_goods_store" in types
        is_general_store = "store" in types or "establishment" in types
        
        if has_outdoor_keywords or is_sporting_goods or (is_general_store and "rental" in name):
            filtered_places.append(place)
    
    # Remove duplicates based on place_id
    unique_places = {}
    for place in filtered_places:
        place_id = place.get("place_id")
        if place_id and place_id not in unique_places:
            unique_places[place_id] = place
    
    places = list(unique_places.values())
    
    if not places:
        return f"🔍 No hiking gear rental shops found within {radius/1000:.0f}km of {formatted_address}. Try expanding your search area or checking nearby cities."
    
    # Sort by number of reviews (user_ratings_total) and limit to top 3 results
    places = sorted(places, key=lambda x: x.get("user_ratings_total", 0), reverse=True)[:3]
    
    # Format the response
    result_sections = []
    result_sections.append("🏪 **Hiking Gear Rental Locations**")
    result_sections.append(f"📍 Search area: {formatted_address}")
    result_sections.append("")
    
    for i, place in enumerate(places, 1):
        name = place.get("name", "Unknown")
        rating = place.get("rating", "No rating")
        user_ratings_total = place.get("user_ratings_total", 0)
        vicinity = place.get("vicinity", "Address not available")
        
        # Get business status
        business_status = place.get("business_status", "")
        status_indicator = "🟢" if business_status == "OPERATIONAL" else "🟡" if business_status else ""
        
        # Price level indicator
        price_level = place.get("price_level")
        price_indicator = ""
        if price_level is not None:
            price_indicator = " • " + "💰" * price_level if price_level > 0 else " • Budget-friendly"
        
        result_sections.append(f"**{i}. {name}** {status_indicator}")
        result_sections.append(f"• **Rating:** ⭐ {rating}/5 ({user_ratings_total} reviews)")
        result_sections.append(f"• **Address:** {vicinity}{price_indicator}")
        
        # Add opening hours if available
        if place.get("opening_hours"):
            is_open = place["opening_hours"].get("open_now")
            if is_open is not None:
                status = "Open now" if is_open else "Closed now"
                result_sections.append(f"• **Status:** {status}")
        
        # Add website/phone if available
        place_id = place.get("place_id")
        if place_id:
            # Get additional details for this place (website, phone, etc.)
            try:
                details_url = "https://maps.googleapis.com/maps/api/place/details/json"
                details_params = {
                    "place_id": place_id,
                    "fields": "website,formatted_phone_number,url",
                    "key": api_key
                }
                details_response = requests.get(details_url, params=details_params, timeout=10)
                details_data = details_response.json()
                
                if details_data.get("status") == "OK" and details_data.get("result"):
                    details = details_data["result"]
                    
                    # Add website if available
                    if details.get("website"):
                        result_sections.append(f"• **Website:** {details['website']}")
                    
                    # Add phone if available
                    if details.get("formatted_phone_number"):
                        result_sections.append(f"• **Phone:** {details['formatted_phone_number']}")
                    
                    # Add Google Maps link
                    if details.get("url"):
                        result_sections.append(f"• **Google Maps:** {details['url']}")
                        
            except (requests.RequestException, KeyError, ValueError):
                # If details request fails, continue without additional info
                pass
        
        result_sections.append("")
    
    result_sections.append("💡 **Tips for Gear Rental:**")
    result_sections.append("• Call ahead to check availability of specific items")
    result_sections.append("• Ask about multi-day rental discounts")
    result_sections.append("• Bring valid ID and credit card for deposits")
    result_sections.append("• Inspect gear condition before renting")
    result_sections.append("• Ask about return policies and late fees")
    
    return "\n".join(result_sections)

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

def weather_conditions_tool(detail: bool = False, user_id: str = None) -> str:
    """Return aggregated current weather along the latest trail for the user with enhanced data from One Call API 3.0."""
    db = next(get_db())
    # Fetch latest trail
    query = db.query(TrailData)
    if user_id:
        query = query.filter(TrailData.user_id == user_id)
    trail = query.order_by(TrailData.id.desc()).first()

    if not trail or not trail.coordinates:
        return "No trail data available. Please upload a trail first."

    # Sample only 2 strategic points (middle and end) for minimal API usage
    samples = sample_trail_endpoints(trail.coordinates)
    if not samples:
        return "Coordinates could not be parsed for weather lookup."

    descriptions = []
    temps = []
    weather_alerts = []
    humidity_values = []
    wind_speeds = []
    
    successful_calls = 0
    
    for lat, lon in samples:
        # Use comprehensive weather data with current weather only
        weather_data = fetch_comprehensive_weather(
            lat, lon, 
            exclude=["minutely", "hourly", "daily"]
        )
        
        if weather_data and "current" in weather_data:
            current = weather_data["current"]
            weather_list = current.get("weather", [])
            
            if weather_list:
                descriptions.append(weather_list[0].get("description", "unknown"))
                temps.append(current.get("temp", 0))
                humidity_values.append(current.get("humidity", 0))
                wind_speeds.append(current.get("wind_speed", 0))
                successful_calls += 1
            
            # Collect any alerts
            alerts = weather_data.get("alerts", [])
            for alert in alerts:
                alert_desc = alert.get("event", "Weather Alert")
                if alert_desc not in weather_alerts:
                    weather_alerts.append(alert_desc)

    if not descriptions:
        if successful_calls == 0:
            return ("⚠️ Weather service currently unavailable. This might be due to:\n"
                   "• API rate limits reached\n"
                   "• Service maintenance\n"
                   "• Network connectivity issues\n\n"
                   "💡 Try again in a few minutes, or use the manual trip details (slider icon) for gear recommendations.")
        else:
            return "Weather data partially available but incomplete. Try again later."

    # Enhanced aggregation
    common_desc = max(set(descriptions), key=descriptions.count)
    avg_temp = sum(temps) / len(temps) if temps else None
    avg_humidity = sum(humidity_values) / len(humidity_values) if humidity_values else None
    avg_wind = sum(wind_speeds) / len(wind_speeds) if wind_speeds else None

    if detail:
        breakdown = "\n".join([f"• {d.capitalize()}, {t:.1f}°C" for d, t in zip(descriptions, temps)])
        result = (
            f"🌤️ **Current Weather Along Your Trail** (middle & end points):\n"
            f"**Overall Conditions:** {common_desc.capitalize()}, {avg_temp:.1f}°C average\n"
        )
        
        if avg_humidity:
            result += f"**Humidity:** {avg_humidity:.0f}%\n"
        if avg_wind:
            result += f"**Wind Speed:** {avg_wind:.1f} m/s\n"
        
        if weather_alerts:
            result += f"⚠️ **Active Alerts:** {', '.join(weather_alerts)}\n"
        
        result += f"\n**Detailed Breakdown:**\n{breakdown}"
        result += f"\n\n📊 **Data Quality:** {successful_calls}/{len(samples)} sampling points successful"
        
        return result
    else:
        result = f"🌤️ Current weather: {common_desc.capitalize()}, {avg_temp:.1f}°C"
        if avg_humidity:
            result += f" (humidity: {avg_humidity:.0f}%)"
        if weather_alerts:
            result += f" ⚠️ Alerts: {', '.join(weather_alerts)}"
        return result

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
                    },
                    "days": {
                        "type": "integer",
                        "description": "Total number of days for the trip"
                    },
                    "overnight": {
                        "type": "boolean",
                        "description": "Whether the trip includes overnight camping"
                    },
                    "season": {
                        "type": "string",
                        "enum": ["summer", "winter", "shoulder"],
                        "description": "Season of the trip which can influence gear choices"
                    },
                    "companions": {
                        "type": "integer",
                        "description": "Number of people in the party"
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
            "name": "weather_conditions_tool",
            "description": "Get current weather information along the latest uploaded trail (aggregated)",
            "parameters": {
                "type": "object",
                "properties": {
                    "detail": {
                        "type": "boolean",
                        "description": "If true, include per-sample breakdown instead of only aggregate"
                    }
                },
                "required": []
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "hiking_plan_tool",
            "description": "Create comprehensive hiking plans with timing, duration estimates, safety preparations, and gear recommendations",
            "parameters": {
                "type": "object",
                "properties": {
                    "start_time": {
                        "type": "string",
                        "description": "Preferred start time for the hike (e.g., '6:00 AM', '7:30 AM')"
                    },
                    "include_safety_prep": {
                        "type": "boolean",
                        "description": "Whether to include safety preparation recommendations"
                    },
                    "include_duration_estimate": {
                        "type": "boolean",
                        "description": "Whether to include duration and timing estimates"
                    }
                },
                "required": []
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "gear_rental_tool",
            "description": "Find hiking gear rental shops, equipment rental stores, and places to rent/hire outdoor gear near a location. Use for ANY request about renting, hiring, or finding rental places for hiking/camping equipment.",
            "parameters": {
                "type": "object",
                "properties": {
                    "location": {
                        "type": "string",
                        "description": "Location to search near (e.g., 'Seattle, WA', 'Denver, CO', 'near Yosemite')"
                    },
                    "latitude": {
                        "type": "number",
                        "description": "User's current latitude coordinate for location-based search"
                    },
                    "longitude": {
                        "type": "number", 
                        "description": "User's current longitude coordinate for location-based search"
                    },
                    "radius": {
                        "type": "integer",
                        "description": "Search radius in meters (default: 25000 = 25km)"
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
            "description": "General hiking and travel Q&A for questions not covered by other tools. DO NOT use for gear rental requests - use gear_rental_tool instead.",
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
    "weather_conditions_tool": weather_conditions_tool,
    "hiking_plan_tool": hiking_plan_tool,
    "gear_rental_tool": gear_rental_tool,
    "chat_tool": chat_tool
}

# Weather endpoints using One Call API 3.0
class WeatherRequest(BaseModel):
    lat: float
    lon: float

class WeatherForecastRequest(BaseModel):
    lat: float
    lon: float
    days: Optional[int] = 7

class WeatherHourlyRequest(BaseModel):
    lat: float
    lon: float
    hours: Optional[int] = 24

@router.post("/weather/current")
async def get_current_weather(
    request: WeatherRequest,
    current_user: User = Depends(get_current_user)
):
    """Get current weather for a specific location using One Call API 3.0."""
    weather_data = fetch_comprehensive_weather(
        request.lat, 
        request.lon, 
        exclude=["minutely", "hourly", "daily", "alerts"]
    )
    
    if not weather_data:
        raise HTTPException(
            status_code=503, 
            detail="Weather service unavailable. Please try again later."
        )
    
    return weather_data

@router.post("/weather/forecast")
async def get_weather_forecast(
    request: WeatherForecastRequest,
    current_user: User = Depends(get_current_user)
):
    """Get weather forecast for specified number of days using One Call API 3.0."""
    weather_data = fetch_weather_forecast(request.lat, request.lon, request.days)
    
    if not weather_data:
        raise HTTPException(
            status_code=503, 
            detail="Weather service unavailable. Please try again later."
        )
    
    return weather_data

@router.post("/weather/hourly")
async def get_hourly_weather(
    request: WeatherHourlyRequest,
    current_user: User = Depends(get_current_user)
):
    """Get hourly weather forecast using One Call API 3.0."""
    weather_data = fetch_hourly_weather(request.lat, request.lon, request.hours)
    
    if not weather_data:
        raise HTTPException(
            status_code=503, 
            detail="Weather service unavailable. Please try again later."
        )
    
    return weather_data

@router.post("/weather/alerts")
async def get_weather_alerts(
    request: WeatherRequest,
    current_user: User = Depends(get_current_user)
):
    """Get weather alerts for a location using One Call API 3.0."""
    alerts = get_weather_alerts(request.lat, request.lon)
    
    if alerts is None:
        raise HTTPException(
            status_code=503, 
            detail="Weather service unavailable. Please try again later."
        )
    
    return {"alerts": alerts}

@router.post("/weather/trail-conditions")
async def get_trail_weather_conditions(
    current_user: User = Depends(get_current_user)
):
    """Get comprehensive weather conditions along the user's latest trail."""
    db = next(get_db())
    
    # Fetch latest trail
    trail = (
        db.query(TrailData)
        .filter(TrailData.user_id == current_user.id)
        .order_by(TrailData.id.desc())
        .first()
    )
    
    if not trail or not trail.coordinates:
        raise HTTPException(
            status_code=404,
            detail="No trail data available. Please upload a trail first."
        )
    
    # Sample only 2 strategic points (middle and end) for minimal API usage
    samples = sample_trail_endpoints(trail.coordinates)
    if not samples:
        raise HTTPException(
            status_code=400,
            detail="Coordinates could not be parsed for weather lookup."
        )
    
    # Get weather data for each sample point
    weather_points = []
    for i, (lat, lon) in enumerate(samples):
        weather_data = fetch_comprehensive_weather(
            lat, lon, 
            exclude=["minutely", "hourly"]  # Get current, daily, and alerts
        )
        
        if weather_data:
            weather_points.append({
                "point_index": i,
                "lat": lat,
                "lon": lon,
                "current": weather_data.get("current"),
                "daily_forecast": weather_data.get("daily", [])[:3],  # 3-day forecast
                "alerts": weather_data.get("alerts", [])
            })
    
    if not weather_points:
        raise HTTPException(
            status_code=503,
            detail="Weather service unavailable or API limit reached. Try again later."
        )
    
    return {
        "trail_weather": weather_points,
        "summary": {
            "total_points": len(weather_points),
            "trail_length_km": (trail.distance_meters or 0) / 1000,
            "elevation_gain_m": trail.elevation_gain_meters or 0
        }
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
- weather_conditions_tool: ONLY when user specifically asks about weather/conditions
- hiking_plan_tool: For comprehensive hiking plans with timing, safety prep, and duration estimates
- gear_rental_tool: For finding hiking gear rental locations near user's location or specified area
- chat_tool: For general hiking/travel questions

CRITICAL GEAR RENTAL DETECTION - MANDATORY RULES:
1. If user mentions "rental", "rent", "renting", "hire" + gear/equipment → MUST use gear_rental_tool
2. If user asks for "places" + gear/equipment → MUST use gear_rental_tool  
3. If user provides location after gear rental request → MUST use gear_rental_tool
4. ABSOLUTELY NEVER use chat_tool for ANY gear rental request
5. When in doubt about gear rental vs general info → ALWAYS choose gear_rental_tool

MANDATORY EXAMPLES - THESE MUST USE gear_rental_tool:
- "gear rental places" → gear_rental_tool (NOT chat_tool)
- "give me gear rental places in almaty" → gear_rental_tool (NOT chat_tool)
- "rent hiking equipment" → gear_rental_tool (NOT chat_tool)
- "where can I rent gear" → gear_rental_tool (NOT chat_tool)
- "equipment rental shops" → gear_rental_tool (NOT chat_tool)

FORBIDDEN: Using chat_tool for anything related to renting, hiring, or finding rental places

IMPORTANT: Only use weather_conditions_tool when the user explicitly asks about weather, conditions, or forecast. Do NOT call it automatically for gear suggestions unless weather is specifically mentioned.
{trail_context}
When the user asks for gear recommendations without specifying conditions, use the trail data context to inform your parameters."""

    # Check if this is definitely a gear rental request and force the tool
    prompt_lower = request.prompt.lower()
    gear_rental_keywords = ["rental", "rent", "renting", "hire"]
    gear_keywords = ["gear", "equipment", "hiking", "camping", "outdoor"]
    
    is_gear_rental_request = any(rental_kw in prompt_lower for rental_kw in gear_rental_keywords) and \
                           any(gear_kw in prompt_lower for gear_kw in gear_keywords)
    
    if is_gear_rental_request:
        # Force gear_rental_tool for obvious rental requests
        tool_choice = {"type": "function", "function": {"name": "gear_rental_tool"}}
    else:
        tool_choice = "required"  # Let AI choose but force a tool
    
    # Get tool selection from OpenAI
    response = openai_client.chat.completions.create(
        model="gpt-4o",
        messages=[
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": request.prompt}
        ],
        tools=TOOLS,
        tool_choice=tool_choice
    )
    
    message = response.choices[0].message
    
    # Check if a tool was called
    if message.tool_calls:
        tool_call = message.tool_calls[0]
        tool_name = tool_call.function.name
        tool_args = json.loads(tool_call.function.arguments)
        
        # Add user_id to args for tools that need it
        if tool_name in ["gear_recommendation_tool", "trail_analysis_tool", "weather_conditions_tool", "hiking_plan_tool", "gear_rental_tool"]:
            tool_args["user_id"] = current_user.id
            
        # Add location data to gear_rental_tool if available and not already specified
        if tool_name == "gear_rental_tool" and request.user_latitude is not None and request.user_longitude is not None:
            # Only add coordinates if not already specified in the tool args
            if "latitude" not in tool_args and "longitude" not in tool_args:
                tool_args["latitude"] = request.user_latitude
                tool_args["longitude"] = request.user_longitude
        
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