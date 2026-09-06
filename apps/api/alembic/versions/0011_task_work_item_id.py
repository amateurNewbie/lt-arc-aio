"""task.work_item_id link to hạng mục công việc

Revision ID: 0011
Revises: 0010
Create Date: 2026-09-06 22:00:00.000000

"""

from alembic import op
import sqlalchemy as sa

revision = "0011"
down_revision = "0010"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("task", sa.Column("work_item_id", sa.Uuid(), nullable=True))
    op.create_index(op.f("ix_task_work_item_id"), "task", ["work_item_id"], unique=False)
    op.create_foreign_key(
        op.f("fk_task_work_item_id_workitem"),
        "task",
        "workitem",
        ["work_item_id"],
        ["id"],
    )


def downgrade() -> None:
    op.drop_constraint(op.f("fk_task_work_item_id_workitem"), "task", type_="foreignkey")
    op.drop_index(op.f("ix_task_work_item_id"), table_name="task")
    op.drop_column("task", "work_item_id")
