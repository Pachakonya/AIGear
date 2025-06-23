from fastapi import APIRouter, Depends, HTTPException
from src.posts.schemas import GearRequest, GearResponse 
# from sqlalchemy.orm import Session
# from src.posts import schemas, models
# from src.posts.dependencies import get_db

router = APIRouter(prefix="/gear", tags=["Gear"])

@router.post("/recommend", response_model=GearResponse)
def recommend_gear(request: GearRequest):
    # dummy logic (you can replace this later with AI-based or rules-based)
    recs = []

    if request.weather == "rainy":
        recs.append("Rain Jacket")
    if request.trail_condition == "rocky":
        recs.append("Hiking Boots")

    return {"recommendations": recs}

# # Create
# @router.post("/", response_model=schemas.PostOut)
# def create_post(post: schemas.PostCreate, db: Session = Depends(get_db)):
#     db_post = models.Post(**post.dict())
#     db.add(db_post)
#     db.commit()
#     db.refresh(db_post)
#     return db_post

# # Read All
# @router.get("/", response_model=list[schemas.PostOut])
# def read_posts(db: Session = Depends(get_db)):
#     return db.query(models.Post).all()

# # Read One
# @router.get("/{post_id}", response_model=schemas.PostOut)
# def read_post(post_id: int, db: Session = Depends(get_db)):
#     post = db.query(models.Post).filter(models.Post.id == post_id).first()
#     if not post:
#         raise HTTPException(status_code=404, detail="Post not found")
#     return post

# # Update
# @router.put("/{post_id}", response_model=schemas.PostOut)
# def update_post(post_id: int, updated: schemas.PostUpdate, db: Session = Depends(get_db)):
#     post = db.query(models.Post).filter(models.Post.id == post_id).first()
#     if not post:
#         raise HTTPException(status_code=404, detail="Post not found")
#     for key, value in updated.dict().items():
#         setattr(post, key, value)
#     db.commit()
#     return post

# # Delete
# @router.delete("/{post_id}")
# def delete_post(post_id: int, db: Session = Depends(get_db)):
#     post = db.query(models.Post).filter(models.Post.id == post_id).first()
#     if not post:
#         raise HTTPException(status_code=404, detail="Post not found")
#     db.delete(post)
#     db.commit()
#     return {"message": "Post deleted"}
