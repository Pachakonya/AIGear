from pydantic import BaseSettings, EmailStr
from typing import Optional
import os

class SMTPConfig(BaseSettings):
    """SMTP configuration for email verification"""
    smtp_host: str = "smtp.gmail.com"
    smtp_port: int = 587
    smtp_user: EmailStr
    smtp_app_password: str
    smtp_use_tls: bool = True
    smtp_use_ssl: bool = False
    
    class Config:
        env_file = ".env"
        env_prefix = "SMTP_"

class EmailVerificationConfig(BaseSettings):
    """Email verification configuration"""
    verification_code_length: int = 6
    verification_code_expiry_minutes: int = 10
    email_subject: str = "Your Verification Code"
    email_template: str = """
    <html>
    <body>
        <h2>Email Verification</h2>
        <p>Your verification code is: <strong>{code}</strong></p>
        <p>This code will expire in {expiry_minutes} minutes.</p>
        <p>If you didn't request this code, please ignore this email.</p>
    </body>
    </html>
    """
    
    class Config:
        env_file = ".env"
        env_prefix = "EMAIL_VERIFICATION_"

# Global instances
smtp_config = SMTPConfig()
email_verification_config = EmailVerificationConfig()
