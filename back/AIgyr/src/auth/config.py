from dotenv import load_dotenv
import os

# Load environment variables from .env file
load_dotenv()

def get_bool(var, default=False):
    val = os.getenv(var)
    if val is None:
        return default
    return val.lower() in ("1", "true", "yes", "on")

# --- SendGrid Config ---
SENDGRID_API_KEY = os.getenv("SENDGRID_API_KEY")
SENDGRID_FROM_EMAIL = os.getenv("SENDGRID_FROM_EMAIL")

# --- Redis Config ---
REDIS_HOST = os.getenv("REDIS_HOST", "localhost")
REDIS_PORT = int(os.getenv("REDIS_PORT", 6379))
REDIS_DB = int(os.getenv("REDIS_DB", 1))
REDIS_PASSWORD = os.getenv("REDIS_PASSWORD", "")

# --- JWT Config ---
SECRET_KEY = os.getenv("SECRET_KEY", "your-secret-key")
ALGORITHM = os.getenv("ALGORITHM", "HS256")
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", 10080))

# --- Email Verification Config ---
EMAIL_VERIFICATION_CODE_LENGTH = int(os.getenv("EMAIL_VERIFICATION_VERIFICATION_CODE_LENGTH", 6))
EMAIL_VERIFICATION_CODE_EXPIRY_MINUTES = int(os.getenv("EMAIL_VERIFICATION_VERIFICATION_CODE_EXPIRY_MINUTES", 10))
EMAIL_VERIFICATION_EMAIL_SUBJECT = os.getenv("EMAIL_VERIFICATION_EMAIL_SUBJECT", "Your Verification Code")
EMAIL_VERIFICATION_EMAIL_TEMPLATE = os.getenv("EMAIL_VERIFICATION_EMAIL_TEMPLATE", """
<html>
<body>
    <h2>Email Verification</h2>
    <p>Your verification code is: <strong>{code}</strong></p>
    <p>This code will expire in {expiry_minutes} minutes.</p>
    <p>If you didn't request this code, please ignore this email.</p>
</body>
</html>
""")
