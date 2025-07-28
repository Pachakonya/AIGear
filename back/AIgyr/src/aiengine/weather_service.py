import os
import requests
from typing import Optional, Dict, List, Tuple, Any
import math


def fetch_comprehensive_weather(lat: float, lon: float, exclude: Optional[List[str]] = None) -> Optional[Dict[str, Any]]:
    """Fetch comprehensive weather data from OpenWeatherMap One Call API 3.0.

    Args:
        lat (float): Latitude of the location.
        lon (float): Longitude of the location.
        exclude (Optional[List[str]]): Parts to exclude from response 
                                     (current, minutely, hourly, daily, alerts)

    Returns:
        dict | None: Comprehensive weather data with current, hourly, daily forecasts
                    and alerts, or None if request fails or api key missing.
    """
    api_key = os.getenv("OPENWEATHER_API_KEY")
    if not api_key:
        print("❌ OpenWeather API key not configured")
        return None

    # Build exclude parameter
    exclude_param = ""
    if exclude:
        exclude_param = f"&exclude={','.join(exclude)}"

    url = (
        "https://api.openweathermap.org/data/3.0/onecall?"
        f"lat={lat}&lon={lon}&appid={api_key}&units=metric{exclude_param}"
    )

    try:
        resp = requests.get(url, timeout=15)
        resp.raise_for_status()
        data = resp.json()
        
        # Log successful response
        current = data.get("current", {})
        weather_desc = current.get("weather", [{}])[0].get("description", "unknown")
        temp = current.get("temp", "unknown")
        print(f"📡  OpenWeather One Call API OK  {lat},{lon} -> {weather_desc}, {temp}°C")
        
        return data
    except requests.exceptions.HTTPError as e:
        if e.response.status_code == 401:
            print(f"❌ OpenWeather UNAUTHORIZED {lat},{lon}: Invalid API key or subscription required")
        elif e.response.status_code == 429:
            print(f"❌ OpenWeather RATE LIMITED {lat},{lon}: API limit reached")
        elif e.response.status_code == 404:
            print(f"❌ OpenWeather NOT FOUND {lat},{lon}: Location not found")
        else:
            print(f"❌ OpenWeather HTTP ERROR {lat},{lon}: {e.response.status_code}")
        return None
    except Exception as e:
        print(f"❌ OpenWeather FAIL {lat},{lon}: {e}")
        return None


def fetch_current_weather(lat: float, lon: float) -> Optional[Dict[str, float]]:
    """Fetch current weather from OpenWeatherMap One Call API 3.0.
    
    This function maintains backward compatibility with the existing codebase
    while using the modern One Call API.

    Args:
        lat (float): Latitude of the location.
        lon (float): Longitude of the location.

    Returns:
        dict | None: {
            "description": str,    # e.g. "light rain"
            "temp": float          # temperature in °C
        } or None if request fails or api key missing.
    """
    # Use One Call API but exclude unnecessary data for performance
    weather_data = fetch_comprehensive_weather(
        lat, lon, 
        exclude=["minutely", "hourly", "daily", "alerts"]
    )
    
    if not weather_data:
        return None
    
    current = weather_data.get("current", {})
    weather_list = current.get("weather", [])
    
    if not weather_list:
        return None
    
    weather_desc = weather_list[0].get("description")
    temp = current.get("temp")
    
    if weather_desc is None or temp is None:
        return None
    
    return {
        "description": weather_desc,
        "temp": float(temp)
    }


def fetch_weather_forecast(lat: float, lon: float, days: int = 7) -> Optional[Dict[str, Any]]:
    """Fetch weather forecast for specified number of days.

    Args:
        lat (float): Latitude of the location.
        lon (float): Longitude of the location.
        days (int): Number of days to forecast (max 8)

    Returns:
        dict | None: {
            "current": {...},
            "daily": [...],  # Daily forecast for specified days
            "alerts": [...]  # Weather alerts if any
        } or None if request fails.
    """
    if days > 8:
        days = 8  # One Call API 3.0 provides max 8 days
    
    # Exclude minutely and hourly for performance
    weather_data = fetch_comprehensive_weather(
        lat, lon, 
        exclude=["minutely", "hourly"]
    )
    
    if not weather_data:
        return None
    
    # Limit daily forecast to requested days
    if "daily" in weather_data and len(weather_data["daily"]) > days:
        weather_data["daily"] = weather_data["daily"][:days]
    
    return weather_data


def fetch_hourly_weather(lat: float, lon: float, hours: int = 24) -> Optional[Dict[str, Any]]:
    """Fetch hourly weather forecast.

    Args:
        lat (float): Latitude of the location.
        lon (float): Longitude of the location.
        hours (int): Number of hours to forecast (max 48)

    Returns:
        dict | None: {
            "current": {...},
            "hourly": [...],  # Hourly forecast for specified hours
        } or None if request fails.
    """
    if hours > 48:
        hours = 48  # One Call API 3.0 provides max 48 hours
    
    # Exclude daily and alerts for performance
    weather_data = fetch_comprehensive_weather(
        lat, lon, 
        exclude=["minutely", "daily", "alerts"]
    )
    
    if not weather_data:
        return None
    
    # Limit hourly forecast to requested hours
    if "hourly" in weather_data and len(weather_data["hourly"]) > hours:
        weather_data["hourly"] = weather_data["hourly"][:hours]
    
    return weather_data


def get_weather_alerts(lat: float, lon: float) -> Optional[List[Dict[str, Any]]]:
    """Get weather alerts for a location.

    Args:
        lat (float): Latitude of the location.
        lon (float): Longitude of the location.

    Returns:
        List[Dict] | None: List of weather alerts or None if request fails.
    """
    weather_data = fetch_comprehensive_weather(
        lat, lon, 
        exclude=["minutely", "hourly", "daily"]
    )
    
    if not weather_data:
        return None
    
    return weather_data.get("alerts", [])


def _haversine_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Return great-circle distance between two lat/lon points in kilometres."""
    R = 6371.0  # Earth radius (km)
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    d_phi = math.radians(lat2 - lat1)
    d_lambda = math.radians(lon2 - lon1)

    a = math.sin(d_phi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(d_lambda / 2) ** 2
    return 2 * R * math.atan2(math.sqrt(a), math.sqrt(1 - a))


def sample_coordinates(coords: List, km_between: float = 5.0) -> List[Tuple[float, float]]:
    """Given a list of coordinates (either flat [lat,lon,...] or [[lat,lon],...]), return
    subsampled points such that roughly `km_between` kilometres separate samples.
    Always includes the first point.
    
    Note: This function is kept for backward compatibility but consider using
    sample_trail_endpoints() for more efficient weather sampling.
    """
    if not coords:
        return []

    # Normalise into list of tuple(lat, lon)
    norm: List[Tuple[float, float]] = []
    if isinstance(coords[0], (list, tuple)):
        norm = [(c[0], c[1]) for c in coords if len(c) >= 2]
    else:
        # flat array: [lat, lon, lat, lon, ...]
        it = iter(coords)
        norm = list(zip(it, it))  # type: ignore

    if not norm:
        return []

    sampled = [norm[0]]
    dist_accum = 0.0
    for i in range(1, len(norm)):
        lat1, lon1 = norm[i - 1]
        lat2, lon2 = norm[i]
        seg = _haversine_km(lat1, lon1, lat2, lon2)
        dist_accum += seg
        if dist_accum >= km_between:
            sampled.append((lat2, lon2))
            dist_accum = 0.0
    return sampled


def sample_trail_endpoints(coords: List) -> List[Tuple[float, float]]:
    """Sample only 2 strategic points from a trail: middle and end.
    This minimizes API calls while still providing representative weather data.
    
    Args:
        coords: List of coordinates (either flat [lat,lon,...] or [[lat,lon],...])
        
    Returns:
        List of (lat, lon) tuples - maximum 2 points (middle and end)
    """
    if not coords:
        return []

    # Normalise into list of tuple(lat, lon)
    norm: List[Tuple[float, float]] = []
    if isinstance(coords[0], (list, tuple)):
        norm = [(c[0], c[1]) for c in coords if len(c) >= 2]
    else:
        # flat array: [lat, lon, lat, lon, ...]
        it = iter(coords)
        norm = list(zip(it, it))  # type: ignore

    if not norm:
        return []
    
    # If trail has only 1-2 points, return what we have
    if len(norm) <= 2:
        return norm
    
    # For longer trails, sample middle and end points
    middle_idx = len(norm) // 2
    end_idx = len(norm) - 1
    
    return [norm[middle_idx], norm[end_idx]] 