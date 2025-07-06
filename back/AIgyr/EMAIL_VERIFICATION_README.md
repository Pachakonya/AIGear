# Email Verification System

This document describes the email verification system implemented in the AIgyr FastAPI backend.

## Overview

The email verification system provides secure one-time verification codes sent via email using Gmail's SMTP. It includes rate limiting, attempt tracking, and comprehensive error handling.

## Architecture

### Components

1. **SMTP Configuration** (`auth/config.py`)
   - Pydantic-based configuration for SMTP settings
   - Environment variable support with validation

2. **Verification Service** (`auth/verification_service.py`)
   - Code generation and storage in Redis
   - Rate limiting and attempt tracking
   - Code expiration management

3. **Email Service** (`auth/email_service.py`)
   - Async email sending using aiosmtplib
   - HTML and plain text email templates
   - Error handling for SMTP failures

4. **API Endpoints** (`auth/router.py`)
   - `POST /auth/send-code/` - Send verification code
   - `POST /auth/verify-code/` - Verify provided code

5. **Custom Exceptions** (`auth/exceptions.py`)
   - Specific exception types for different error scenarios

## Setup

### 1. Environment Configuration

Copy `env.example` to `.env` and configure:

```bash
# SMTP Configuration
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_APP_PASSWORD=your-gmail-app-password
SMTP_USE_TLS=true
SMTP_USE_SSL=false

# Email Verification Settings
EMAIL_VERIFICATION_VERIFICATION_CODE_LENGTH=6
EMAIL_VERIFICATION_VERIFICATION_CODE_EXPIRY_MINUTES=10
EMAIL_VERIFICATION_EMAIL_SUBJECT=Your Verification Code

# Redis Configuration
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_DB=0
REDIS_PASSWORD=
```

### 2. Gmail App Password Setup

1. Enable 2-factor authentication on your Gmail account
2. Generate an App Password:
   - Go to Google Account settings
   - Security → 2-Step Verification → App passwords
   - Generate password for "Mail"
3. Use this password in `SMTP_APP_PASSWORD`

### 3. Redis Setup

Ensure Redis is running:

```bash
# Install Redis (macOS)
brew install redis

# Start Redis
redis-server

# Or using Docker
docker run -d -p 6379:6379 redis:alpine
```

## API Usage

### Send Verification Code

```bash
curl -X POST "http://localhost:8000/auth/send-code" \
  -H "Content-Type: application/json" \
  -d '{"email": "user@example.com"}'
```

**Response:**
```json
{
  "message": "Verification code sent successfully",
  "email": "user@example.com"
}
```

### Verify Code

```bash
curl -X POST "http://localhost:8000/auth/verify-code" \
  -H "Content-Type: application/json" \
  -d '{"email": "user@example.com", "code": "123456"}'
```

**Success Response:**
```json
{
  "message": "Code verified successfully",
  "email": "user@example.com",
  "verified": true
}
```

**Error Response:**
```json
{
  "detail": "Invalid verification code"
}
```

## Features

### Rate Limiting
- **Per-minute limit**: 3 requests per minute per email
- **Per-hour limit**: 10 requests per hour per email
- Automatic cleanup of rate limit counters

### Attempt Tracking
- **Maximum attempts**: 5 attempts per email
- **Attempt window**: 15 minutes
- Automatic reset on successful verification

### Code Management
- **Code length**: 6 digits (configurable)
- **Expiration**: 10 minutes (configurable)
- **Storage**: Redis with automatic expiration
- **Cleanup**: Automatic deletion after verification

### Error Handling
- **SMTP errors**: Graceful handling with cleanup
- **Invalid codes**: Increment attempt counter
- **Expired codes**: Clear error messages
- **Rate limit exceeded**: 429 status code
- **Too many attempts**: 429 status code

## Security Features

1. **Code Generation**: Cryptographically secure random numbers
2. **Rate Limiting**: Prevents abuse and spam
3. **Attempt Tracking**: Prevents brute force attacks
4. **Code Expiration**: Automatic cleanup of old codes
5. **Input Validation**: Pydantic validation for all inputs
6. **Error Sanitization**: No sensitive information in error messages

## Testing

### Manual Testing

1. **Send Code Test:**
   ```bash
   curl -X POST "http://localhost:8000/auth/send-code" \
     -H "Content-Type: application/json" \
     -d '{"email": "test@example.com"}'
   ```

2. **Verify Code Test:**
   ```bash
   # First, check Redis for the stored code
   redis-cli get "verification_code:test@example.com"
   
   # Then verify with the retrieved code
   curl -X POST "http://localhost:8000/auth/verify-code" \
     -H "Content-Type: application/json" \
     -d '{"email": "test@example.com", "code": "RETRIEVED_CODE"}'
   ```

### Rate Limiting Test

```bash
# Send multiple requests quickly to test rate limiting
for i in {1..5}; do
  curl -X POST "http://localhost:8000/auth/send-code" \
    -H "Content-Type: application/json" \
    -d '{"email": "test@example.com"}'
  echo ""
done
```

## Troubleshooting

### Common Issues

1. **SMTP Authentication Error**
   - Verify Gmail app password is correct
   - Ensure 2FA is enabled on Gmail account
   - Check SMTP settings in .env file

2. **Redis Connection Error**
   - Ensure Redis server is running
   - Check Redis connection settings
   - Verify Redis port is not blocked

3. **Rate Limiting Too Strict**
   - Adjust rate limit constants in `auth/constants.py`
   - Modify `RATE_LIMIT_PER_MINUTE` and `RATE_LIMIT_PER_HOUR`

4. **Code Not Received**
   - Check spam folder
   - Verify email address is correct
   - Check SMTP configuration

### Debug Mode

Enable debug logging by setting environment variable:
```bash
export LOG_LEVEL=DEBUG
```

## Integration with Existing Auth System

The email verification system integrates seamlessly with the existing authentication system:

1. **User Registration**: Can be used to verify new user emails
2. **Password Reset**: Can be adapted for password reset functionality
3. **Email Change**: Can be used to verify new email addresses

## Future Enhancements

1. **Email Templates**: Customizable HTML templates
2. **Multiple Email Providers**: Support for other SMTP providers
3. **SMS Verification**: Add SMS-based verification
4. **Webhook Support**: Notify external services on verification
5. **Analytics**: Track verification success rates
6. **A/B Testing**: Test different email templates

## Dependencies

- `aiosmtplib`: Async SMTP client
- `redis`: Redis client for storage
- `pydantic`: Data validation
- `email-validator`: Email validation
- `fastapi`: Web framework

## File Structure

```
src/auth/
├── config.py              # SMTP and verification configuration
├── constants.py           # Constants and Redis configuration
├── exceptions.py          # Custom exception classes
├── verification_service.py # Code generation and storage
├── email_service.py       # Async email sending
├── schemas.py            # Pydantic models (updated)
├── router.py             # API endpoints (updated)
├── models.py             # Database models
├── service.py            # Auth business logic
├── utils.py              # JWT utilities
└── dependencies.py       # FastAPI dependencies
``` 