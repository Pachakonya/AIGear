"""Add user_id to trail_data table

Revision ID: add_user_id_to_trail
Revises: 
Create Date: 2025-01-10 12:03:42

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy import inspect


# revision identifiers, used by Alembic.
revision = 'add_user_id_to_trail'
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Get database connection
    conn = op.get_bind()
    inspector = inspect(conn)
    
    # Check if trail_data table exists
    if 'trail_data' not in inspector.get_table_names():
        print("trail_data table does not exist, skipping migration")
        return
    
    # Get existing columns
    columns = [col['name'] for col in inspector.get_columns('trail_data')]
    
    # Add user_id column if it doesn't exist
    if 'user_id' not in columns:
        op.add_column('trail_data', sa.Column('user_id', sa.String(), nullable=True))
        # Create index on user_id for better query performance
        op.create_index('ix_trail_data_user_id', 'trail_data', ['user_id'])
    
    # Add created_at column if it doesn't exist
    if 'created_at' not in columns:
        op.add_column('trail_data', sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now()))


def downgrade() -> None:
    # Get database connection
    conn = op.get_bind()
    inspector = inspect(conn)
    
    # Check if trail_data table exists
    if 'trail_data' not in inspector.get_table_names():
        return
    
    # Get existing columns and indexes
    columns = [col['name'] for col in inspector.get_columns('trail_data')]
    indexes = [idx['name'] for idx in inspector.get_indexes('trail_data')]
    
    # Remove the index if it exists
    if 'ix_trail_data_user_id' in indexes:
        op.drop_index('ix_trail_data_user_id', 'trail_data')
    
    # Remove the columns if they exist
    if 'created_at' in columns:
        op.drop_column('trail_data', 'created_at')
    if 'user_id' in columns:
        op.drop_column('trail_data', 'user_id') 