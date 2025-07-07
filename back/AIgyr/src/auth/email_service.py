import aiosmtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from typing import Optional
from .config import (
    SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_APP_PASSWORD, SMTP_USE_TLS, SMTP_USE_SSL,
    EMAIL_VERIFICATION_EMAIL_SUBJECT, EMAIL_VERIFICATION_EMAIL_TEMPLATE, EMAIL_VERIFICATION_CODE_EXPIRY_MINUTES
)
from .exceptions import EmailSendError

class EmailService:
    def __init__(self):
        self.smtp_host = SMTP_HOST
        self.smtp_port = SMTP_PORT
        self.smtp_user = SMTP_USER
        self.smtp_password = SMTP_APP_PASSWORD
        self.smtp_use_tls = SMTP_USE_TLS
        self.smtp_use_ssl = SMTP_USE_SSL
    
    async def send_verification_email(self, to_email: str, code: str) -> bool:
        """Send verification code email asynchronously"""
        try:
            # Create message
            message = MIMEMultipart("alternative")
            message["Subject"] = EMAIL_VERIFICATION_EMAIL_SUBJECT
            message["From"] = f"AIgyr Verification <{self.smtp_user}>"
            message["To"] = to_email
            
            # Create HTML content
            html_content = EMAIL_VERIFICATION_EMAIL_TEMPLATE.format(
                code=code,
                expiry_minutes=EMAIL_VERIFICATION_CODE_EXPIRY_MINUTES
            )
            
            # Create plain text content
            text_content = f"""
            Email Verification
            
            Your verification code is: {code}
            
            This code will expire in {EMAIL_VERIFICATION_CODE_EXPIRY_MINUTES} minutes.
            
            If you didn't request this code, please ignore this email.
            """
            
            # Attach parts
            text_part = MIMEText(text_content, "plain")
            html_part = MIMEText(html_content, "html")
            
            message.attach(text_part)
            message.attach(html_part)
            
            # Send email
            await self._send_email(message)
            return True
            
        except Exception as e:
            raise EmailSendError(f"Failed to send verification email: {str(e)}")
    
    async def _send_email(self, message: MIMEMultipart):
        """Send email using aiosmtplib"""
        try:
            if self.smtp_use_ssl:
                await aiosmtplib.send(
                    message,
                    hostname=self.smtp_host,
                    port=self.smtp_port,
                    username=self.smtp_user,
                    password=self.smtp_password,
                    use_tls=False,
                    use_ssl=True
                )
            else:
                await aiosmtplib.send(
                    message,
                    hostname=self.smtp_host,
                    port=self.smtp_port,
                    username=self.smtp_user,
                    password=self.smtp_password,
                    use_tls=self.smtp_use_tls,
                    use_ssl=False
                )
        except Exception as e:
            raise EmailSendError(f"SMTP error: {str(e)}")
    
    async def send_custom_email(
        self, 
        to_email: str, 
        subject: str, 
        html_content: str, 
        text_content: Optional[str] = None
    ) -> bool:
        """Send a custom email"""
        try:
            message = MIMEMultipart("alternative")
            message["Subject"] = subject
            message["From"] = f"AIgyr Verification <{self.smtp_user}>"
            message["To"] = to_email
            
            if text_content:
                text_part = MIMEText(text_content, "plain")
                message.attach(text_part)
            
            html_part = MIMEText(html_content, "html")
            message.attach(html_part)
            
            await self._send_email(message)
            return True
            
        except Exception as e:
            raise EmailSendError(f"Failed to send custom email: {str(e)}")

# Global instance
email_service = EmailService() 