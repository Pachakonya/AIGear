from pydantic import BaseModel, EmailStr
from typing import Optional

class UserCreate(BaseModel):
    email: EmailStr
    password: str
    username: Optional[str] = None

class UserLogin(BaseModel):
    email: EmailStr
    password: str

class UserVerify(BaseModel):
    email: EmailStr
    code: str

class UserResponse(BaseModel):
    id: str
    email: str
    username: Optional[str] = None
    age: Optional[int] = None
    gender: Optional[str] = None
    fitness_level: Optional[str] = None
    hiking_experience_years: Optional[float] = None
    profile_completed: Optional[bool] = False

class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserResponse

class MessageResponse(BaseModel):
    message: str

# Profile schemas (NEW)
class ProfileUpdate(BaseModel):
    age: int
    gender: str
    fitness_level: str
    hiking_experience_years: float

class ProfileResponse(BaseModel):
    age: int
    gender: str
    fitness_level: str
    hiking_experience_years: float
    profile_completed: bool

# Email verification schemas
class SendCodeRequest(BaseModel):
    email: EmailStr

class SendCodeResponse(BaseModel):
    message: str
    email: str

class VerifyCodeRequest(BaseModel):
    email: EmailStr
    code: str

class VerifyCodeResponse(BaseModel):
    message: str
    email: str
    verified: bool
