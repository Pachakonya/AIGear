from fastapi import APIRouter, Depends, HTTPException, status, Body
from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError
from src.auth.schemas import (
    UserCreate, UserLogin, UserVerify, TokenResponse, UserResponse,
    SendCodeRequest, SendCodeResponse, VerifyCodeRequest, VerifyCodeResponse,
    ProfileUpdate, ProfileResponse, MessageResponse
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
import jwt

router = APIRouter(prefix="/auth", tags=["auth"])

def create_user_response(user: User) -> UserResponse:
    """Helper function to safely create UserResponse from User model"""
    return UserResponse(
        id=user.id,
        email=user.email,
        username=user.username,
        age=user.age,
        gender=user.gender,
        fitness_level=user.fitness_level,
        hiking_experience_years=user.hiking_experience_years,
        profile_completed=user.profile_completed if user.profile_completed is not None else False
    )

@router.post("/register", response_model=UserResponse, status_code=201)
def register(user: UserCreate, db: Session = Depends(get_db)):
    try:
        db_user = create_user(db, user.email, user.password, user.username)
    except IntegrityError:
        db.rollback()
        raise HTTPException(status_code=409, detail="Email already exists")
    # In production, send code via email
    return create_user_response(db_user)

@router.post("/login", response_model=TokenResponse)
def login(user: UserLogin, db: Session = Depends(get_db)):
    db_user = authenticate_user(db, user.email, user.password)
    if not db_user or not db_user.is_verified:
        raise HTTPException(status_code=401, detail="Invalid credentials or email not verified")
    token = create_access_token({"sub": db_user.id})
    return TokenResponse(
        access_token=token,
        token_type="bearer",
        user=create_user_response(db_user)
    )

@router.delete("/delete-account", summary="Delete current user account")
def delete_account(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    delete_user_account(current_user, db)
    return {"msg": "Account deleted"}

@router.get("/me", response_model=UserResponse)
def get_current_user_info(current_user: User = Depends(get_current_user)):
    return create_user_response(current_user)

@router.put("/profile", response_model=ProfileResponse)
def update_profile(
    profile_data: ProfileUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    # Validate age (must be greater than 4 as per frontend validation)
    if profile_data.age <= 4:
        raise HTTPException(status_code=400, detail="Age must be greater than 4")
    
    # Validate gender options
    valid_genders = ["Male", "Female", "Other"]
    if profile_data.gender not in valid_genders:
        raise HTTPException(status_code=400, detail="Gender must be one of: Male, Female, Other")
    
    # Validate fitness level options
    valid_fitness_levels = ["Beginner", "Intermediate", "Advanced"]
    if profile_data.fitness_level not in valid_fitness_levels:
        raise HTTPException(status_code=400, detail="Fitness level must be one of: Beginner, Intermediate, Advanced")
    
    # Validate hiking experience (must be >= 0)
    if profile_data.hiking_experience_years < 0:
        raise HTTPException(status_code=400, detail="Hiking experience cannot be negative")
    
    # Update user profile
    current_user.age = profile_data.age
    current_user.gender = profile_data.gender
    current_user.fitness_level = profile_data.fitness_level
    current_user.hiking_experience_years = profile_data.hiking_experience_years
    current_user.profile_completed = True
    
    db.commit()
    db.refresh(current_user)
    
    return ProfileResponse(
        age=current_user.age,
        gender=current_user.gender,
        fitness_level=current_user.fitness_level,
        hiking_experience_years=current_user.hiking_experience_years,
        profile_completed=current_user.profile_completed
    )

@router.get("/profile", response_model=ProfileResponse)
def get_profile(current_user: User = Depends(get_current_user)):
    if not current_user.profile_completed:
        raise HTTPException(status_code=404, detail="Profile not completed")
    
    return ProfileResponse(
        age=current_user.age,
        gender=current_user.gender,
        fitness_level=current_user.fitness_level,
        hiking_experience_years=current_user.hiking_experience_years,
        profile_completed=current_user.profile_completed
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
            user=create_user_response(user)
        )
    except Exception as e:
        raise HTTPException(status_code=400, detail="Invalid Google token")

@router.post("/apple", response_model=TokenResponse)
def apple_auth(data: dict = Body(...), db: Session = Depends(get_db)):
    """
    Handle Apple Sign-In authentication
    Expected data: {
        "identityToken": "...",  # JWT from Apple
        "user": {                # Only provided on first sign-in
            "email": "...",      # May be a proxy email
            "name": {...}        # Optional name components
        }
    }
    """
    identity_token = data.get("identityToken")
    user_info = data.get("user", {})
    
    if not identity_token:
        raise HTTPException(status_code=400, detail="Apple identity token required")
    
    try:
        # In production, you should verify the Apple JWT token
        # For now, we'll decode it without verification (NOT SECURE)
        # TODO: Implement proper Apple token verification
        decoded_token = jwt.decode(identity_token, options={"verify_signature": False})
        
        # Get the Apple user ID (sub) and email
        apple_user_id = decoded_token.get("sub")
        email = decoded_token.get("email") or user_info.get("email")
        
        if not apple_user_id:
            raise HTTPException(status_code=400, detail="Invalid Apple token")
        
        # Check if user already exists
        user = db.query(User).filter(User.email == email).first() if email else None
        
        if not user:
            # Create new user
            # Generate a unique username
            name_info = user_info.get("name", {})
            first_name = name_info.get("firstName", "")
            last_name = name_info.get("lastName", "")
            
            # Generate base username from name or use Apple ID
            if first_name:
                base_username = f"{first_name}_{last_name}".strip("_").lower()
            else:
                base_username = f"apple_user_{apple_user_id[-8:]}"  # Use last 8 chars of Apple ID
            
            # Ensure username is unique by checking database and adding number if needed
            username = base_username
            counter = 1
            while db.query(User).filter(User.username == username).first():
                username = f"{base_username}_{counter}"
                counter += 1
            
            try:
                user = User(
                    email=email or f"{apple_user_id}@privaterelay.appleid.com",  # Fallback email
                    username=username,
                    is_verified=True,  # Apple emails are pre-verified
                    hashed_password=""  # No password for OAuth users
                )
                db.add(user)
                db.commit()
                db.refresh(user)
            except IntegrityError:
                db.rollback()
                raise HTTPException(status_code=400, detail="User creation failed due to duplicate data")
        
        # Generate JWT token
        jwt_token = create_access_token({"sub": user.id})
        return TokenResponse(
            access_token=jwt_token,
            token_type="bearer",
            user=create_user_response(user)
        )
        
    except Exception as e:
        print(f"Apple auth error: {e}")
        raise HTTPException(status_code=400, detail="Invalid Apple token")

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
