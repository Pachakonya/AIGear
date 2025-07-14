import os
import requests
from typing import Optional, Dict, List, Tuple
import math


def fetch_current_weather(lat: float, lon: float) -> Optional[Dict[str, float]]:
    """Fetch current weather from OpenWeatherMap.

    Args:
        lat (float): Latitude of the location.
        lon (float): Longitude of the location.

    Returns:
        dict | None: {
            "description": str,    # e.g. "light rain"
            "temp": float          # temperature in °C
        } or None if request fails or api key missing.
    """
    api_key = os.getenv("OPENWEATHER_API_KEY")
    if not api_key:
        # API key not configured
        return None

    url = (
        "https://api.openweathermap.org/data/2.5/weather?"
        f"lat={lat}&lon={lon}&appid={api_key}&units=metric"
    )

    try:
        resp = requests.get(url, timeout=10)
        resp.raise_for_status()
        data = resp.json()
        weather_desc = data.get("weather", [{}])[0].get("description")
        temp = data.get("main", {}).get("temp")
        if weather_desc is None or temp is None:
            return None
        print(f"📡  OpenWeather OK  {lat},{lon} -> {weather_desc}, {temp}°C")
        return {"description": weather_desc, "temp": temp}
    except Exception as e:
        # Fail silently – call site can fall back to None
        print(f"❌ OpenWeather FAIL {lat},{lon}: {e}")
        return None


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