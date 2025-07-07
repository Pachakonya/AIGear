from fastapi import APIRouter, Depends, HTTPException, status, Body
from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError
from src.auth.schemas import (
    UserCreate, UserLogin, UserVerify, TokenResponse, UserResponse,
    SendCodeRequest, SendCodeResponse, VerifyCodeRequest, VerifyCodeResponse
)
from src.auth.service import create_user, authenticate_user, delete_user_account
from src.auth.utils import create_access_token
from src.auth.dependencies import get_current_user
from src.auth.verification_service import verification_service
from src.auth.email_service import email_service
from src.auth.exceptions import (
    EmailVerificationError, CodeExpiredError, InvalidCodeError, 
    EmailSendError, TooManyAttemptsError
)
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

@router.delete("/delete-account", summary="Delete current user account")
def delete_account(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    delete_user_account(current_user, db)
    return {"msg": "Account deleted"}

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

# Email verification endpoints
@router.post("/send-code", response_model=SendCodeResponse, status_code=200)
async def send_verification_code(request: SendCodeRequest):
    """Send a verification code to the provided email address"""
    try:
        # Generate and store verification code
        code = await verification_service.generate_and_store_code(request.email)
        
        # Send email with verification code
        await email_service.send_verification_email(request.email, code)
        
        return SendCodeResponse(
            message="Verification code sent successfully",
            email=request.email
        )
        
    except TooManyAttemptsError as e:
        raise HTTPException(
            status_code=429, 
            detail=str(e)
        )
    except EmailSendError as e:
        # Clean up the stored code if email sending fails
        await verification_service.delete_code(request.email)
        raise HTTPException(
            status_code=500, 
            detail="Failed to send verification email. Please try again."
        )
    except Exception as e:
        raise HTTPException(
            status_code=500, 
            detail="An unexpected error occurred"
        )

@router.post("/verify-code", response_model=VerifyCodeResponse, status_code=200)
async def verify_code(request: VerifyCodeRequest, db: Session = Depends(get_db)):
    """Verify the provided code for the email address"""
    try:
        # Verify the code in Redis
        is_valid = await verification_service.verify_code(request.email, request.code)
        if is_valid:
            # Set user.is_verified = True in PostgreSQL
            user = db.query(User).filter(User.email == request.email).first()
            if user:
                user.is_verified = True
                db.commit()
                db.refresh(user)
            return VerifyCodeResponse(
                message="Code verified successfully",
                email=request.email,
                verified=True
            )
        else:
            return VerifyCodeResponse(
                message="Invalid verification code",
                email=request.email,
                verified=False
            )
    except CodeExpiredError as e:
        raise HTTPException(
            status_code=400, 
            detail=str(e)
        )
    except InvalidCodeError as e:
        raise HTTPException(
            status_code=400, 
            detail=str(e)
        )
    except TooManyAttemptsError as e:
        raise HTTPException(
            status_code=429, 
            detail=str(e)
        )
    except Exception as e:
        raise HTTPException(
            status_code=500, 
            detail="An unexpected error occurred"
        )
