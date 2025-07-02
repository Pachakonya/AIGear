from fastapi import APIRouter, Depends, HTTPException, status, Body
from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError
from src.auth.schemas import UserCreate, UserLogin, UserVerify, TokenResponse, UserResponse
from src.auth.service import create_user, authenticate_user, verify_user
from src.auth.utils import create_access_token
from src.database import get_db
from src.auth.models import User
from google.oauth2 import id_token
from google.auth.transport import requests

router = APIRouter(prefix="/auth", tags=["auth"])

@router.post("/register", response_model=UserResponse, status_code=201)
def register(user: UserCreate, db: Session = Depends(get_db)):
    try:
        db_user, code = create_user(db, user.email, user.password, user.username)
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=409, detail="Email already exists")
    # In production, send code via email
    return UserResponse(id=db_user.id, email=db_user.email, username=db_user.username)

@router.post("/login", response_model=TokenResponse)
def login(user: UserLogin, db: Session = Depends(get_db)):
    db_user = authenticate_user(db, user.email, user.password)
    if not db_user or not db_user.is_verified:
        raise HTTPException(status_code=401, detail="Invalid credentials or email not verified")
    token = create_access_token({"sub": db_user.id})
    return TokenResponse(
        access_token=token,
        token_type="bearer",
        user=UserResponse(id=db_user.id, email=db_user.email, username=db_user.username)
    )

@router.post("/verify", response_model=TokenResponse)
def verify(user: UserVerify, db: Session = Depends(get_db)):
    db_user = verify_user(db, user.email, user.code)
    if not db_user:
        raise HTTPException(status_code=400, detail="Invalid verification code")
    token = create_access_token({"sub": db_user.id})
    return TokenResponse(
        access_token=token,
        token_type="bearer",
        user=UserResponse(id=db_user.id, email=db_user.email, username=db_user.username)
    )

@router.post("/google", response_model=TokenResponse)
def google_auth(data: dict = Body(...), db: Session = Depends(get_db)):
    token = data.get("token")
    if not token:
        raise HTTPException(status_code=400, detail="Google token required")
    try:
        idinfo = id_token.verify_oauth2_token(token, requests.Request())
        email = idinfo["email"]
        username = idinfo.get("name")
        user = db.query(User).filter(User.email == email).first()
        if not user:
            user = User(email=email, username=username, is_verified=True, hashed_password="")
            db.add(user)
            db.commit()
            db.refresh(user)
        jwt_token = create_access_token({"sub": user.id})
        return TokenResponse(
            access_token=jwt_token,
            token_type="bearer",
            user=UserResponse(id=user.id, email=user.email, username=user.username)
        )
    except Exception as e:
        raise HTTPException(status_code=400, detail="Invalid Google token")
