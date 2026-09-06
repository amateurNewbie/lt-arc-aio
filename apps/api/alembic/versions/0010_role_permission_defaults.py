"""role permission defaults matrix

Revision ID: 0010
Revises: 0009
Create Date: 2026-09-06 16:00:00.000000

"""

from alembic import op
import sqlalchemy as sa

revision = "0010"
down_revision = "0009"
branch_labels = None
depends_on = None

_ROLES = ("ADMIN", "DIRECTOR", "DEPARTMENT_HEAD", "EMPLOYEE")
_GROUPS = (
    "PROJECT_CASHBOOK",
    "OVERHEAD_ALLOCATE",
    "FUNDS",
    "DEBTS",
    "CONTRACTS_COLLECT",
    "WORKDAYS_ENTRY",
)
_DEFAULT_ON = {"ADMIN", "DIRECTOR"}


def upgrade() -> None:
    op.create_table(
        "rolepermissiondefault",
        sa.Column("role", sa.String(), nullable=False),
        sa.Column("permission_group", sa.String(), nullable=False),
        sa.Column("enabled", sa.Boolean(), nullable=False, server_default=sa.text("false")),
        sa.PrimaryKeyConstraint("role", "permission_group"),
    )

    rows = [
        {
            "role": role,
            "permission_group": group,
            "enabled": role in _DEFAULT_ON,
        }
        for role in _ROLES
        for group in _GROUPS
    ]
    op.bulk_insert(
        sa.table(
            "rolepermissiondefault",
            sa.column("role", sa.String),
            sa.column("permission_group", sa.String),
            sa.column("enabled", sa.Boolean),
        ),
        rows,
    )


def downgrade() -> None:
    op.drop_table("rolepermissiondefault")
