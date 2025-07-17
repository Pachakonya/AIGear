"""Fix NULL usernames to prevent constraint violations

Revision ID: fix_null_usernames
Revises: add_user_id_to_trail
Create Date: 2025-01-10 14:45:00

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect, text

# revision identifiers, used by Alembic.
revision = 'fix_null_usernames'
down_revision = 'add_user_id_to_trail'
branch_labels = None
depends_on = None

def upgrade() -> None:
    # Get database connection
    conn = op.get_bind()
    inspector = inspect(conn)
    
    # Check if users table exists
    if 'users' not in inspector.get_table_names():
        print("users table does not exist, skipping migration")
        return
    
    # Update NULL usernames to unique values to prevent constraint violations
    conn.execute(text("""
        UPDATE users 
        SET username = 'user_' || SUBSTRING(id FROM 1 FOR 8) || '_' || EXTRACT(EPOCH FROM created_at)::bigint
        WHERE username IS NULL OR username = '';
    """))

def downgrade() -> None:
    # This migration is not easily reversible as we're fixing data integrity
    # We don't want to set usernames back to NULL as that would cause issues
    pass 