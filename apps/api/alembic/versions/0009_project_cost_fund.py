"""project cost fund_account_id

Revision ID: 0009
Revises: 0008
Create Date: 2026-09-06 01:30:00.000000

"""

from alembic import op
import sqlalchemy as sa

revision = "0009"
down_revision = "0008"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("projectcost", sa.Column("fund_account_id", sa.Uuid(), nullable=True))
    op.create_foreign_key(
        "fk_projectcost_fund_account_id_fundaccount",
        "projectcost",
        "fundaccount",
        ["fund_account_id"],
        ["id"],
    )


def downgrade() -> None:
    op.drop_constraint("fk_projectcost_fund_account_id_fundaccount", "projectcost", type_="foreignkey")
    op.drop_column("projectcost", "fund_account_id")
