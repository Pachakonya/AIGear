from pydantic import BaseModel
from datetime import datetime

class PostCreate(BaseModel):
    title: str
    content: str
    author: str | None = None

class PostOut(PostCreate):
    id: int
    created_at: datetime

    class Config:
        orm_mode = True
        
class PostUpdate(PostCreate):
    pass