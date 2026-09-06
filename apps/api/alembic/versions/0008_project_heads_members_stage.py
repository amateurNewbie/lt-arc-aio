"""project heads, members, normalize stage_progress

Revision ID: 0008
Revises: 0007
Create Date: 2026-09-06 01:10:00.000000

"""

import json
from alembic import op
import sqlalchemy as sa


revision = "0008"
down_revision = "0007"
branch_labels = None
depends_on = None

_STAGE_KEYS = (
    "design",
    "permit",
    "rough_construction",
    "interior_finish",
    "handover",
)


def _normalize_stage(raw: dict | None) -> dict:
    base = {key: {"progress": 0, "deadline": None} for key in _STAGE_KEYS}
    if not raw:
        return base
    for key in _STAGE_KEYS:
        value = raw.get(key)
        if isinstance(value, dict):
            progress = int(value.get("progress") or 0)
            base[key] = {"progress": max(0, min(100, progress)), "deadline": value.get("deadline")}
        elif isinstance(value, (int, float)):
            base[key] = {"progress": max(0, min(100, int(value))), "deadline": None}
    return base


def upgrade() -> None:
    op.add_column("project", sa.Column("construction_head_id", sa.Uuid(), nullable=True))
    op.add_column("project", sa.Column("design_head_id", sa.Uuid(), nullable=True))
    op.create_foreign_key(
        "fk_project_construction_head_id_user",
        "project",
        "user",
        ["construction_head_id"],
        ["id"],
    )
    op.create_foreign_key(
        "fk_project_design_head_id_user",
        "project",
        "user",
        ["design_head_id"],
        ["id"],
    )

    op.create_table(
        "projectmember",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("project_id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(["project_id"], ["project.id"]),
        sa.ForeignKeyConstraint(["user_id"], ["user.id"]),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("project_id", "user_id", name="uq_project_member_project_user"),
    )
    op.create_index(op.f("ix_projectmember_project_id"), "projectmember", ["project_id"], unique=False)
    op.create_index(op.f("ix_projectmember_user_id"), "projectmember", ["user_id"], unique=False)

    conn = op.get_bind()
    rows = conn.execute(sa.text("SELECT id, stage_progress FROM project")).fetchall()
    for row in rows:
        project_id, raw = row[0], row[1]
        if isinstance(raw, str):
            raw = json.loads(raw)
        normalized = _normalize_stage(raw if isinstance(raw, dict) else None)
        conn.execute(
            sa.text("UPDATE project SET stage_progress = CAST(:sp AS json) WHERE id = :id"),
            {"sp": json.dumps(normalized), "id": str(project_id)},
        )


def downgrade() -> None:
    op.drop_index(op.f("ix_projectmember_user_id"), table_name="projectmember")
    op.drop_index(op.f("ix_projectmember_project_id"), table_name="projectmember")
    op.drop_table("projectmember")
    op.drop_constraint("fk_project_design_head_id_user", "project", type_="foreignkey")
    op.drop_constraint("fk_project_construction_head_id_user", "project", type_="foreignkey")
    op.drop_column("project", "design_head_id")
    op.drop_column("project", "construction_head_id")
