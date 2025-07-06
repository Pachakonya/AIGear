from pydantic_settings import BaseSettings
from pydantic import EmailStr

# SMTP Config
class SMTPConfig(BaseSettings):
    smtp_host: str = "smtp.gmail.com"
    smtp_port: int = 587
    smtp_user: EmailStr
    smtp_app_password: str
    smtp_use_tls: bool = True
    smtp_use_ssl: bool = False

    model_config = {
        "env_prefix": "SMTP_",
    }

# Redis Config
class RedisConfig(BaseSettings):
    redis_host: str = "localhost"
    redis_port: int = 6379
    redis_db: int = 1
    redis_password: str = ""

    model_config = {
        "env_prefix": "REDIS_",
    }

# JWT Config
class JWTConfig(BaseSettings):
    secret_key: str
    algorithm: str = "HS256"
    access_token_expire_minutes: int = 10080

    model_config = {
        "env_prefix": "",
    }

# Email Verification Config
class EmailVerificationConfig(BaseSettings):
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

    model_config = {
        "env_prefix": "EMAIL_VERIFICATION_",
    }

# Global config instances
smtp_config = SMTPConfig()
redis_config = RedisConfig()
jwt_config = JWTConfig()
email_verification_config = EmailVerificationConfig()
