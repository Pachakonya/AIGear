from sqlalchemy.orm import Session
from src.auth.models import User
from src.auth.utils import hash_password, verify_password
import uuid
import random

def create_user(db: Session, email: str, password: str, username: str = None):
    hashed_pw = hash_password(password)
    user = User(
        id=str(uuid.uuid4()),
        email=email,
        username=username,
        hashed_password=hashed_pw,
        is_verified=False
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user

def authenticate_user(db: Session, email: str, password: str):
    user = db.query(User).filter(User.email == email).first()
    if not user or not verify_password(password, user.hashed_password):
        return None
    return user

def delete_user_account(user, db):
    db.delete(user)
    db.commit()
