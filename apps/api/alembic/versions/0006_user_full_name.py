"""user full name

Revision ID: 0006
Revises: 0005
Create Date: 2026-09-04 23:28:38.728688

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = '0006'
down_revision = '0005'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # FR-1 — tên hiển thị cho người dùng (trước đây chỉ có email); dùng ở mọi
    # nơi cần hiển thị người phụ trách/nhân sự thay vì email kỹ thuật.
    op.add_column('user', sa.Column('full_name', sa.String(), nullable=True))


def downgrade() -> None:
    op.drop_column('user', 'full_name')
