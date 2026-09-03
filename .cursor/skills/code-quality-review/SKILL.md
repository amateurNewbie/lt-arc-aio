---
name: code-quality-review
description: >-
  Reviews ARC AIO code (Flutter/Riverpod, FastAPI/SQLModel) on five axes
  (Logic, Security, Performance, Maintainability, Style). Use after writing or
  changing code, before claiming done or committing, when reviewing a diff/PR,
  or when the user asks for code review, chất lượng, security, performance.
---

# Code Quality Review — ARC AIO

## Scope

Review the whole affected area, not just the touched lines — callers, sibling
screens/endpoints, and matching patterns elsewhere in `apps/mobile` /
`apps/api`. Narrow scope only if the user explicitly asks; note **Not
reviewed:** when you do.

## Order

Security → Logic → Performance → Maintainability → Style.

## Template

```markdown
# Code Quality Review

**Scope:** whole project (default) | narrowed: …
**Verdict:** Pass | Pass with issues | Block
**Verify:** code | test | runtime

## Findings
### Critical
- [Security|Logic|...] `path:line` — description → **Fix:** …
```

## Overlay — stack-specific checks

### FastAPI / SQLModel
- Business logic in the router instead of a service (see `add-fastapi-endpoint`)
- `table=True` model returned directly as a response
- Sync call (`requests`, sync `Session`) inside an `async def` handler
- Missing/wrong status code (`201` create, `404` missing, `422` validation)
- Unindexed FK, N+1 query, or DB write outside a transaction where it needs one
- `datetime.now()` instead of `datetime.utcnow()`
- Schema change without a matching Alembic revision

### Flutter / Riverpod
- `StatefulWidget`/`setState` used for state a provider should own
- API call made directly inside a widget instead of through a repository + provider
- `ref.read` used in `build` where `ref.watch` was needed (stale UI)
- Bloc/GetX/`provider` package mixed in alongside Riverpod
- Hardcoded host instead of `10.0.2.2` (Android emulator) / `127.0.0.1` (web) / env config
- Missing loading/error branch on an `AsyncValue.when`

### Cross-cutting
- Secrets committed or logged
- New top-level folder outside `apps/mobile` / `apps/api` without being asked (see `project.mdc`)

## Cấm

- Declaring Pass after reading only the current diff.
- Dropping a finding because it's outside the file just edited.
- Unrelated style-only churn unless the user asked for a cleanup pass.
