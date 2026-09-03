---
name: sqlmodel-fastapi
description: >-
  SQLModel conventions for ARC AIO (apps/api) — table models, request/response
  models, async session, Alembic migrations. Use when defining a DB model,
  writing a query, adding a migration, or when the user mentions SQLModel,
  Alembic, AsyncSession, relationship, or database schema.
---

# SQLModel — ARC AIO

Chosen ORM for `apps/api`. SQLModel wraps SQLAlchemy Core + Pydantic — do not
import `sqlalchemy.orm.declarative_base` or bare Pydantic `BaseModel` for
anything that maps to a table.

## Two kinds of SQLModel class — never conflate them

```python
class TaskBase(SQLModel):
    title: str
    done: bool = False

class Task(TaskBase, table=True):          # DB table model
    id: int | None = Field(default=None, primary_key=True)
    owner_id: int = Field(foreign_key="user.id", index=True)

class TaskCreate(TaskBase):                 # request model (table=False)
    pass

class TaskRead(TaskBase):                   # response model (table=False)
    id: int
```

- `table=True` model = DB shape. Never return it directly from a router — map to a `Read` model.
- Request/response models never set `table=True`.

## Session & engine

- Async engine: `create_async_engine(url, ...)`; session via `AsyncSession` + `Depends(get_session)`.
- One session per request; never share a session across requests or background tasks.
- All queries `await session.exec(select(...))` — no sync `Session`/`session.query()` in an async handler.

## Relationships

- Declare with `Relationship(back_populates=...)`, index the FK column explicitly (`Field(foreign_key=..., index=True)` — SQLModel does not auto-index FKs).
- Prefer explicit `select(...).where(...)` joins over lazy relationship access inside a loop (N+1).

## Migrations (Alembic)

- `env.py` target metadata = `SQLModel.metadata`; import every table model module before `autogenerate` or Alembic won't see it.
- Autogenerate, then hand-review the diff — SQLModel/Alembic sometimes misses type/server-default changes.
- One revision per logical schema change; never edit an already-applied revision.

## Cấm

- Returning a `table=True` model straight out of a FastAPI endpoint.
- Raw SQL strings where `select()` + SQLModel expressions work.
- Creating tables via `SQLModel.metadata.create_all()` outside test setup / local bootstrap scripts.
- Sync `Session`/`psycopg2` engine mixed into async request handlers.
- Un-indexed foreign key columns.
