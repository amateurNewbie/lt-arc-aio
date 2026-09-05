"""lead status history

Revision ID: 0007
Revises: 0006
Create Date: 2026-09-06 00:00:00.000000

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import ENUM as PGEnum


# revision identifiers, used by Alembic.
revision = '0007'
down_revision = '0006'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # `leadstatus` đã được tạo ở migration 0002 (cho lead.status) — dùng
    # create_type=False để tránh DuplicateObjectError (xem migration 0003).
    lead_status_enum = PGEnum(
        'NEW', 'CONSULTING', 'QUOTED', 'CONVERTED', 'REJECTED',
        name='leadstatus', create_type=False,
    )
    op.create_table(
        'leadstatushistory',
        sa.Column('id', sa.Uuid(), nullable=False),
        sa.Column('lead_id', sa.Uuid(), nullable=False),
        sa.Column('from_status', lead_status_enum, nullable=False),
        sa.Column('to_status', lead_status_enum, nullable=False),
        sa.Column('note', sa.String(), nullable=True),
        sa.Column('actor_id', sa.Uuid(), nullable=False),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(['lead_id'], ['lead.id']),
        sa.ForeignKeyConstraint(['actor_id'], ['user.id']),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index(op.f('ix_leadstatushistory_lead_id'), 'leadstatushistory', ['lead_id'], unique=False)
    op.create_index(op.f('ix_leadstatushistory_created_at'), 'leadstatushistory', ['created_at'], unique=False)


def downgrade() -> None:
    op.drop_index(op.f('ix_leadstatushistory_created_at'), table_name='leadstatushistory')
    op.drop_index(op.f('ix_leadstatushistory_lead_id'), table_name='leadstatushistory')
    op.drop_table('leadstatushistory')
    # KHÔNG drop `leadstatus` — do migration 0002 tạo và vẫn dùng cho lead.status.
