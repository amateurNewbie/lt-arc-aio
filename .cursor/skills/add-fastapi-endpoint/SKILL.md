---
name: add-fastapi-endpoint
description: Adds a FastAPI route with Pydantic schema, service, and tests. Use when creating or changing REST endpoints, routers, or API contracts for the Python backend.
---

# Add FastAPI endpoint

## Steps

1. Confirm router prefix (`/api/v1/...`) and HTTP method.
2. Add or extend request/response models as plain SQLModel classes (`table=False`) — keep them separate from the DB table model (`table=True`). See `sqlmodel-fastapi` skill.
3. Implement handler in the matching router; keep DB access in a service/repo, injected via `Depends`. Router functions stay thin — no business logic, no direct `AsyncSession` queries inline.
4. Wire the router in the FastAPI app if new.
5. Add a pytest (async, `httpx.AsyncClient`) for success + 1 failure/validation case.
6. If the table model changed, add an Alembic revision (autogenerate against SQLModel metadata) instead of creating tables in the request path.

## Contract

- Status codes explicit (`201` create, `404` missing, `422` validation).
- No secrets in responses.
- Type hints on public functions.
