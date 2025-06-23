from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from src.posts import schemas, models
from src.posts.dependencies import get_db

router = APIRouter(prefix="/posts", tags=["Posts"])

# Create
@router.post("/", response_model=schemas.PostOut)
def create_post(post: schemas.PostCreate, db: Session = Depends(get_db)):
    db_post = models.Post(**post.dict())
    db.add(db_post)
    db.commit()
    db.refresh(db_post)
    return db_post

# Read All
@router.get("/", response_model=list[schemas.PostOut])
def read_posts(db: Session = Depends(get_db)):
    return db.query(models.Post).all()

# Read One
@router.get("/{post_id}", response_model=schemas.PostOut)
def read_post(post_id: int, db: Session = Depends(get_db)):
    post = db.query(models.Post).filter(models.Post.id == post_id).first()
    if not post:
        raise HTTPException(status_code=404, detail="Post not found")
    return post

# Update
@router.put("/{post_id}", response_model=schemas.PostOut)
def update_post(post_id: int, updated: schemas.PostUpdate, db: Session = Depends(get_db)):
    post = db.query(models.Post).filter(models.Post.id == post_id).first()
    if not post:
        raise HTTPException(status_code=404, detail="Post not found")
    for key, value in updated.dict().items():
        setattr(post, key, value)
    db.commit()
    return post

# Delete
@router.delete("/{post_id}")
def delete_post(post_id: int, db: Session = Depends(get_db)):
    post = db.query(models.Post).filter(models.Post.id == post_id).first()
    if not post:
        raise HTTPException(status_code=404, detail="Post not found")
    db.delete(post)
    db.commit()
    return {"message": "Post deleted"}
