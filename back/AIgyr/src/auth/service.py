from sqlalchemy.orm import Session
from src.auth.models import User
from src.auth.utils import hash_password, verify_password
import uuid
import random

def create_user(db: Session, email: str, password: str, username: str = None):
    hashed_pw = hash_password(password)
    verification_code = str(random.randint(100000, 999999))
    user = User(
        id=str(uuid.uuid4()),
        email=email,
        username=username,
        hashed_password=hashed_pw,
        is_verified=False,
        verification_code=verification_code
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user, verification_code

def authenticate_user(db: Session, email: str, password: str):
    user = db.query(User).filter(User.email == email).first()
    if not user or not verify_password(password, user.hashed_password):
        return None
    return user

def verify_user(db: Session, email: str, code: str):
    user = db.query(User).filter(User.email == email).first()
    if user and user.verification_code == code:
        user.is_verified = True
        user.verification_code = None
        db.commit()
        db.refresh(user)
        return user
    return None
