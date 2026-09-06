"""overheadcost.fund_account_id for cash ledger

Revision ID: 0012
Revises: 0011
Create Date: 2026-09-06 23:30:00.000000

"""

from alembic import op
import sqlalchemy as sa

revision = "0012"
down_revision = "0011"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("overheadcost", sa.Column("fund_account_id", sa.Uuid(), nullable=True))
    op.create_index(op.f("ix_overheadcost_fund_account_id"), "overheadcost", ["fund_account_id"], unique=False)
    op.create_foreign_key(
        op.f("fk_overheadcost_fund_account_id_fundaccount"),
        "overheadcost",
        "fundaccount",
        ["fund_account_id"],
        ["id"],
    )


def downgrade() -> None:
    op.drop_constraint(op.f("fk_overheadcost_fund_account_id_fundaccount"), "overheadcost", type_="foreignkey")
    op.drop_index(op.f("ix_overheadcost_fund_account_id"), table_name="overheadcost")
    op.drop_column("overheadcost", "fund_account_id")
