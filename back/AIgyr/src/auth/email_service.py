from sendgrid import SendGridAPIClient
from sendgrid.helpers.mail import Mail, Email, To, Content
import os
from .config import SENDGRID_API_KEY, SENDGRID_FROM_EMAIL, EMAIL_VERIFICATION_EMAIL_SUBJECT, EMAIL_VERIFICATION_EMAIL_TEMPLATE, EMAIL_VERIFICATION_CODE_EXPIRY_MINUTES
from .exceptions import EmailSendError
from typing import Optional

class EmailService:
    def __init__(self):
        self.api_key = SENDGRID_API_KEY
        self.from_email = SENDGRID_FROM_EMAIL

    async def send_verification_email(self, to_email: str, code: str) -> bool:
        """Send verification code email asynchronously"""
        try:
            html_content = EMAIL_VERIFICATION_EMAIL_TEMPLATE.format(
                code=code,
                expiry_minutes=EMAIL_VERIFICATION_CODE_EXPIRY_MINUTES
            )
            message = Mail(
                from_email=self.from_email,
                to_emails=to_email,
                subject=EMAIL_VERIFICATION_EMAIL_SUBJECT,
                html_content=html_content
            )
            sg = SendGridAPIClient(self.api_key)
            response = sg.send(message)
            if response.status_code >= 200 and response.status_code < 300:
                return True
            else:
                raise EmailSendError(f"SendGrid error: {response.status_code} {response.body}")
        except Exception as e:
            print("EMAIL ERROR:", e)
            raise EmailSendError(f"Failed to send verification email: {str(e)}")
    
    async def send_custom_email(
        self, 
        to_email: str, 
        subject: str, 
        html_content: str, 
        text_content: Optional[str] = None
    ) -> bool:
        """Send a custom email using SendGrid"""
        try:
            # If text_content is provided, include both plain and HTML parts
            if text_content:
                message = Mail(
                    from_email=self.from_email,
                    to_emails=to_email,
                    subject=subject,
                    plain_text_content=text_content,
                    html_content=html_content
                )
            else:
                message = Mail(
                    from_email=self.from_email,
                    to_emails=to_email,
                    subject=subject,
                    html_content=html_content
                )
            sg = SendGridAPIClient(self.api_key)
            response = sg.send(message)
            if response.status_code >= 200 and response.status_code < 300:
                return True
            else:
                raise EmailSendError(f"SendGrid error: {response.status_code} {response.body}")
        except Exception as e:
            print("EMAIL ERROR:", e)
            raise EmailSendError(f"Failed to send custom email: {str(e)}")

# Global instance
email_service = EmailService() 