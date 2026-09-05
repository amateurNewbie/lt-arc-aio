"""company settings reminder config

Revision ID: 0005
Revises: 0004
Create Date: 2026-09-04 21:37:38.672654

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '0005'
down_revision = '0004'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # FR-19.2/FR-8.4 — cấu hình số ngày nhắc; server_default để không vỡ dữ liệu đã seed.
    op.add_column('companysettings', sa.Column('task_reminder_days', sa.Integer(), nullable=False, server_default='1'))
    op.add_column('companysettings', sa.Column('debt_reminder_days', sa.Integer(), nullable=False, server_default='3'))
    op.add_column('companysettings', sa.Column('overhead_reminder_day', sa.Integer(), nullable=False, server_default='28'))


def downgrade() -> None:
    op.drop_column('companysettings', 'overhead_reminder_day')
    op.drop_column('companysettings', 'debt_reminder_days')
    op.drop_column('companysettings', 'task_reminder_days')
