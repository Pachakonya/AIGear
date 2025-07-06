class EmailVerificationError(Exception):
    """Base exception for email verification errors"""
    pass

class CodeExpiredError(EmailVerificationError):
    """Raised when verification code has expired"""
    pass

class InvalidCodeError(EmailVerificationError):
    """Raised when verification code is invalid"""
    pass

class EmailSendError(EmailVerificationError):
    """Raised when email sending fails"""
    pass

class TooManyAttemptsError(EmailVerificationError):
    """Raised when too many verification attempts"""
    pass
