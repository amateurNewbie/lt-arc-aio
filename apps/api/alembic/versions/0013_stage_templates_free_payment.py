"""project stage templates + free-form payment note

Revision ID: 0013
Revises: 0012
Create Date: 2026-09-06 23:40:00.000000

"""

from alembic import op
import sqlalchemy as sa

revision = "0013"
down_revision = "0012"
branch_labels = None
depends_on = None

_DEFAULT_STAGES = (
    ("design", "Thiết kế", 0),
    ("permit", "Xin phép xây dựng", 1),
    ("rough_construction", "Thi công phần thô", 2),
    ("interior_finish", "Hoàn thiện nội thất", 3),
    ("handover", "Nghiệm thu & bàn giao", 4),
)


def upgrade() -> None:
    op.create_table(
        "projectstagetemplate",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("key", sa.String(), nullable=False),
        sa.Column("name", sa.String(), nullable=False),
        sa.Column("sort_order", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("active", sa.Boolean(), nullable=False, server_default=sa.text("true")),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("key", name="uq_projectstagetemplate_key"),
    )
    op.create_index(op.f("ix_projectstagetemplate_active"), "projectstagetemplate", ["active"], unique=False)

    import uuid

    conn = op.get_bind()
    for key, name, sort_order in _DEFAULT_STAGES:
        conn.execute(
            sa.text(
                "INSERT INTO projectstagetemplate (id, key, name, sort_order, active) "
                "VALUES (:id, :key, :name, :sort_order, true)"
            ),
            {"id": str(uuid.uuid4()), "key": key, "name": name, "sort_order": sort_order},
        )

    op.alter_column("payment", "contract_milestone_id", existing_type=sa.Uuid(), nullable=True)
    op.add_column("payment", sa.Column("note", sa.String(), nullable=True))


def downgrade() -> None:
    op.drop_column("payment", "note")
    op.alter_column("payment", "contract_milestone_id", existing_type=sa.Uuid(), nullable=False)
    op.drop_index(op.f("ix_projectstagetemplate_active"), table_name="projectstagetemplate")
    op.drop_table("projectstagetemplate")
