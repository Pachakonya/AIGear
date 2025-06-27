# Simple in-memory knowledge base for gear recommendations
GEAR_KB = [
    {"condition": "rocky", "gear": ["Hiking Boots", "Trekking Poles"]},
    {"condition": "rainy", "gear": ["Rain Jacket", "Waterproof Backpack"]},
    {"condition": "snowy", "gear": ["Insulated Jacket", "Snow Boots", "Gaiters"]},
    {"condition": "muddy", "gear": ["Waterproof Boots", "Gaiters"]},
    {"condition": "steep", "gear": ["Trekking Poles", "High-Traction Shoes"]},
    {"condition": "hot", "gear": ["Sun Hat", "Sunscreen", "Extra Water"]},
    {"condition": "cold", "gear": ["Thermal Layers", "Gloves", "Beanie"]},
    {"condition": "long", "gear": ["Extra Snacks", "Water Reservoir"]},
    {"condition": "river", "gear": ["Water Shoes", "Quick-Dry Towel"]},
]

def retrieve_gear(trail_conditions, elevation, distance):
    gear = set()
    for cond in trail_conditions:
        for entry in GEAR_KB:
            if cond in entry["condition"]:
                gear.update(entry["gear"])
    # Add logic for elevation/distance
    if elevation > 500:
        gear.add("Extra Layers")
    if distance > 10000:
        gear.add("Blister Plasters")
    return list(gear) 