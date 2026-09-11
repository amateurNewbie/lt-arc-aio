"""device tokens (FCM) + notification kind/entity for push routing

Revision ID: 0014
Revises: 0013
Create Date: 2026-09-11 00:00:00.000000

"""

from alembic import op
import sqlalchemy as sa
import sqlmodel

# revision identifiers, used by Alembic.
revision = "0014"
down_revision = "0013"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "devicetoken",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("fcm_token", sqlmodel.sql.sqltypes.AutoString(), nullable=False),
        sa.Column("platform", sa.Enum("ANDROID", "IOS", name="deviceplatform"), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("last_seen_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["user.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_devicetoken_user_id"), "devicetoken", ["user_id"], unique=False)
    op.create_index(op.f("ix_devicetoken_fcm_token"), "devicetoken", ["fcm_token"], unique=True)

    op.add_column("notification", sa.Column("kind", sqlmodel.sql.sqltypes.AutoString(), nullable=True))
    op.add_column("notification", sa.Column("entity_type", sqlmodel.sql.sqltypes.AutoString(), nullable=True))
    op.add_column("notification", sa.Column("entity_id", sa.Uuid(), nullable=True))
    op.create_index(op.f("ix_notification_kind"), "notification", ["kind"], unique=False)


def downgrade() -> None:
    op.drop_index(op.f("ix_notification_kind"), table_name="notification")
    op.drop_column("notification", "entity_id")
    op.drop_column("notification", "entity_type")
    op.drop_column("notification", "kind")

    op.drop_index(op.f("ix_devicetoken_fcm_token"), table_name="devicetoken")
    op.drop_index(op.f("ix_devicetoken_user_id"), table_name="devicetoken")
    op.drop_table("devicetoken")
    # `op.drop_table` không tự xoá Postgres ENUM đứng sau cột Enum — không xoá
    # thì lần upgrade kế tiếp `CREATE TYPE deviceplatform` sẽ đụng độ type mồ côi.
    sa.Enum(name="deviceplatform").drop(op.get_bind(), checkfirst=True)
