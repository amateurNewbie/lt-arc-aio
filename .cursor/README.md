# Cursor project config

## Structure

```
.cursor/
  rules/                                              # Persistent agent guidance
    project.mdc                                       # Always on — stack, layout, defaults
    flutter.mdc                                       # Flutter/Dart conventions (project)
    flutter-development-guidelines-*.mdc              # Flutter MVVM + Riverpod + Dart style
    flutter-app-expert-*.mdc                          # Flutter expert patterns (BLoC/Material 3)
    flutter-riverpod-*.mdc                            # Flutter Riverpod workflows
    fastapi.mdc                                       # FastAPI best practices
    fastapi-production-architecture-*.mdc             # FastAPI layered production architecture
    postgres.mdc                                      # PostgreSQL + Alembic
  skills/                                             # Workflows the agent can follow
    local-dev-check/
    add-fastapi-endpoint/
    add-flutter-feature/
    flutter-riverpod/                                 # Riverpod provider conventions (deep dive)
    sqlmodel-fastapi/                                 # SQLModel + Alembic conventions (deep dive)
    code-quality-review/                              # 5-axis review, ARC AIO overlay
    # + 37 skills from evanca/flutter-ai-rules (mirrored under .agents/skills/)
```

## Rules

| File | Scope | When it applies |
|------|--------|-----------------|
| `project.mdc` | Always | Every chat — ARC AIO stack, layout, git/secrets defaults |
| `flutter.mdc` | `pubspec.yaml`, `*.dart`, `*.arb` | Project Flutter conventions (API client, emulator hosts) |
| `flutter-development-guidelines-cursorrules-prompt-file.mdc` | `*.dart` | MVVM layout, Riverpod, Material widgets, Dart style |
| `flutter-app-expert-cursorrules-prompt-file.mdc` | `**/*` (manual/agent pick) | Flutter expert patterns, Material 3, clean architecture |
| `flutter-riverpod-cursorrules-prompt-file.mdc` | `**/*` (manual/agent pick) | Riverpod-focused Flutter guidance |
| `fastapi.mdc` | `*.py`, `app/**/*.py`, `api/**/*.py` | FastAPI structure, DI, middleware, API patterns |
| `fastapi-production-architecture-cursorrules-prompt-file.mdc` | `**/*` (manual/agent pick) | Router → Service → Repository layers, bulkhead, idempotency |
| `postgres.mdc` | `*.sql`, `alembic.ini`, `alembic/**` | Local Postgres + Alembic conventions |

### Rule format

- Files must be `.mdc` with YAML frontmatter.
- `alwaysApply: true` → every chat.
- `globs` → when matching files are in context (or when the agent selects the rule).
- Keep each rule focused; split large concerns into separate files.

### Stack notes (from `project.mdc`)

- FE: Flutter (Web, Android; iOS needs macOS later) — state management: **Riverpod**
- BE: FastAPI on Python 3.12 — ORM: **SQLModel** (async) + Alembic
- DB: PostgreSQL
- Prefer `uv` for Python deps; secrets only in `.env`

## Skills

| Skill | Use when |
|-------|----------|
| `local-dev-check` | Checking Windows env, `flutter doctor`, missing installs |
| `add-fastapi-endpoint` | Adding/changing REST endpoints, schemas, routers |
| `add-flutter-feature` | New Flutter screen/feature wired to the API |
| `flutter-riverpod` | Choosing a provider type, wiring `ConsumerWidget`, testing providers |
| `sqlmodel-fastapi` | Defining a table/request/response model, relationships, Alembic migration |
| `code-quality-review` | Reviewing a diff/PR on Security/Logic/Performance/Maintainability/Style |
| `flutter-best-practices`, `effective-dart`, `riverpod`, `testing`, … | Official Flutter/Dart/Firebase guidance from [evanca/flutter-ai-rules](https://github.com/evanca/flutter-ai-rules) — agent auto-loads by task |

Also mirrored at `.agents/skills/` + tracked by root `skills-lock.json` (reinstall: `npx skills experimental_install`).

### Skill format

- Each skill is a folder with `SKILL.md`.
- `name`: lowercase, hyphens only.
- `description`: what it does + when to use it.
- Extra docs go in the same folder (`reference.md`), not nested deep.

Invoke a skill by name, for example: “follow `local-dev-check`”.

## How to extend

1. **New rule** — add `.cursor/rules/<name>.mdc` with `description` + `alwaysApply` or `globs`.
2. **New skill** — add `.cursor/skills/<skill-name>/SKILL.md`.
3. Keep this README in sync when you add or remove rules/skills.
