from sqlalchemy import Column, Integer, String, Text, DateTime, Float, String, func
from sqlalchemy.dialects.postgresql import ARRAY
from src.database import Base

class Post(Base):
    __tablename__ = "posts"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String, nullable=False)
    content = Column(Text, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    author = Column(String, nullable=True)

class TrailData(Base):
    __tablename__ = "trail_data"

    id = Column(Integer, primary_key=True, index=True)
    coordinates = Column(ARRAY(Float))  # Or JSON if preferred
    distance_meters = Column(Float)
    elevation_gain_meters = Column(Float)
    trail_conditions = Column(ARRAY(String))