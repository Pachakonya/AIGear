import redis
import os
from typing import Optional

# Redis configuration
REDIS_HOST = os.getenv("REDIS_HOST", "localhost")
REDIS_PORT = int(os.getenv("REDIS_PORT", 6379))
REDIS_DB = int(os.getenv("REDIS_DB", 0))
REDIS_PASSWORD = os.getenv("REDIS_PASSWORD", None)

# Verification code settings
VERIFICATION_CODE_LENGTH = 6
VERIFICATION_CODE_EXPIRY_MINUTES = 10
MAX_ATTEMPTS_PER_EMAIL = 5
ATTEMPT_WINDOW_MINUTES = 15

# Redis key prefixes
VERIFICATION_CODE_PREFIX = "verification_code:"
ATTEMPT_COUNT_PREFIX = "attempt_count:"

# Email settings
EMAIL_SUBJECT = "Your Verification Code"
EMAIL_FROM_NAME = "AIgyr Verification"

# Rate limiting
RATE_LIMIT_PER_MINUTE = 3
RATE_LIMIT_PER_HOUR = 10
