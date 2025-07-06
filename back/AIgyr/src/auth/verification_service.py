import redis
import random
import string
import asyncio
from datetime import datetime, timedelta
from typing import Optional, Tuple
from .constants import (
    REDIS_HOST, REDIS_PORT, REDIS_DB, REDIS_PASSWORD,
    VERIFICATION_CODE_LENGTH, VERIFICATION_CODE_EXPIRY_MINUTES,
    MAX_ATTEMPTS_PER_EMAIL, ATTEMPT_WINDOW_MINUTES,
    VERIFICATION_CODE_PREFIX, ATTEMPT_COUNT_PREFIX,
    RATE_LIMIT_PER_MINUTE, RATE_LIMIT_PER_HOUR
)
from .exceptions import (
    CodeExpiredError, InvalidCodeError, TooManyAttemptsError
)

class VerificationCodeService:
    def __init__(self):
        self.redis_client = redis.Redis(
            host=REDIS_HOST,
            port=REDIS_PORT,
            db=REDIS_DB,
            password=REDIS_PASSWORD,
            decode_responses=True
        )
    
    def _generate_code(self) -> str:
        """Generate a random numeric verification code"""
        return ''.join(random.choices(string.digits, k=VERIFICATION_CODE_LENGTH))
    
    def _get_verification_key(self, email: str) -> str:
        """Get Redis key for verification code"""
        return f"{VERIFICATION_CODE_PREFIX}{email}"
    
    def _get_attempt_key(self, email: str) -> str:
        """Get Redis key for attempt count"""
        return f"{ATTEMPT_COUNT_PREFIX}{email}"
    
    def _get_rate_limit_key(self, email: str, window: str) -> str:
        """Get Redis key for rate limiting"""
        return f"rate_limit:{window}:{email}"
    
    async def check_rate_limit(self, email: str) -> bool:
        """Check if email is rate limited"""
        current_time = datetime.now()
        
        # Check per-minute rate limit
        minute_key = self._get_rate_limit_key(email, "minute")
        minute_count = self.redis_client.get(minute_key)
        if minute_count and int(minute_count) >= RATE_LIMIT_PER_MINUTE:
            return False
        
        # Check per-hour rate limit
        hour_key = self._get_rate_limit_key(email, "hour")
        hour_count = self.redis_client.get(hour_key)
        if hour_count and int(hour_count) >= RATE_LIMIT_PER_HOUR:
            return False
        
        return True
    
    async def increment_rate_limit(self, email: str):
        """Increment rate limit counters"""
        current_time = datetime.now()
        
        # Increment per-minute counter
        minute_key = self._get_rate_limit_key(email, "minute")
        pipe = self.redis_client.pipeline()
        pipe.incr(minute_key)
        pipe.expire(minute_key, 60)  # Expire in 60 seconds
        pipe.execute()
        
        # Increment per-hour counter
        hour_key = self._get_rate_limit_key(email, "hour")
        pipe = self.redis_client.pipeline()
        pipe.incr(hour_key)
        pipe.expire(hour_key, 3600)  # Expire in 1 hour
        pipe.execute()
    
    async def check_attempt_limit(self, email: str) -> bool:
        """Check if email has exceeded attempt limit"""
        attempt_key = self._get_attempt_key(email)
        attempt_count = self.redis_client.get(attempt_key)
        
        if attempt_count and int(attempt_count) >= MAX_ATTEMPTS_PER_EMAIL:
            return False
        return True
    
    async def increment_attempt_count(self, email: str):
        """Increment attempt count for email"""
        attempt_key = self._get_attempt_key(email)
        pipe = self.redis_client.pipeline()
        pipe.incr(attempt_key)
        pipe.expire(attempt_key, ATTEMPT_WINDOW_MINUTES * 60)
        pipe.execute()
    
    async def reset_attempt_count(self, email: str):
        """Reset attempt count for email (on successful verification)"""
        attempt_key = self._get_attempt_key(email)
        self.redis_client.delete(attempt_key)
    
    async def generate_and_store_code(self, email: str) -> str:
        """Generate a verification code and store it in Redis"""
        # Check rate limits
        if not await self.check_rate_limit(email):
            raise TooManyAttemptsError("Rate limit exceeded. Please try again later.")
        
        # Check attempt limits
        if not await self.check_attempt_limit(email):
            raise TooManyAttemptsError("Too many verification attempts. Please try again later.")
        
        # Generate code
        code = self._generate_code()
        
        # Store in Redis with expiration
        verification_key = self._get_verification_key(email)
        expiry_seconds = VERIFICATION_CODE_EXPIRY_MINUTES * 60
        
        self.redis_client.setex(verification_key, expiry_seconds, code)
        
        # Increment rate limit counters
        await self.increment_rate_limit(email)
        
        return code
    
    async def verify_code(self, email: str, code: str) -> bool:
        """Verify the provided code for the email"""
        verification_key = self._get_verification_key(email)
        stored_code = self.redis_client.get(verification_key)
        
        if not stored_code:
            await self.increment_attempt_count(email)
            raise CodeExpiredError("Verification code has expired or doesn't exist")
        
        if stored_code != code:
            await self.increment_attempt_count(email)
            raise InvalidCodeError("Invalid verification code")
        
        # Code is valid - clean up
        self.redis_client.delete(verification_key)
        await self.reset_attempt_count(email)
        
        return True
    
    async def get_stored_code(self, email: str) -> Optional[str]:
        """Get the stored verification code for an email (for testing/debugging)"""
        verification_key = self._get_verification_key(email)
        return self.redis_client.get(verification_key)
    
    async def delete_code(self, email: str):
        """Delete the stored verification code for an email"""
        verification_key = self._get_verification_key(email)
        self.redis_client.delete(verification_key)

# Global instance
verification_service = VerificationCodeService() 