# LT ARC — ARC AIO

Flutter (Web/Android/iOS) + FastAPI + PostgreSQL. Xem [docs/IMPLEMENTATION-PLAN-v2.md](../docs/IMPLEMENTATION-PLAN-v2.md) cho phạm vi đầy đủ, [.cursor/README.md](.cursor/README.md) cho quy ước rules/skills.

## Trạng thái: Phase 0 (Foundation) — DONE, đã xác minh trên Postgres thật

- ✅ `apps/api` — FastAPI + SQLModel + Alembic, auth (login/me), RBAC deps, grant CRUD
  - 6 test pass (SQLite in-memory cho tốc độ — xem `apps/api/tests/conftest.py`)
  - **Đã chạy thật trên PostgreSQL 16 (Docker)**: `alembic upgrade head` tạo đúng 8 bảng, seed data, `uvicorn` thật (không phải test client) — login trả JWT, `/api/auth/me` đúng, lockout 5-lần-sai hoạt động đúng (verify trực tiếp trong DB)
  - 2 bug chỉ lộ ra khi chạy Postgres thật (test SQLite không bắt được) đã fix: `app/db/session.py` dùng nhầm `AsyncSession` của SQLAlchemy thuần (thiếu `.exec()`), `app/main.py` thiếu import `app.db.base` gây `NoReferencedTableError` ngay request đầu tiên trên tiến trình mới
- ✅ `apps/mobile` — Flutter (Android + Web), theme 2 bộ token, i18n VI/EN, Riverpod codegen, go_router, màn login → shell rỗng
  - `flutter analyze`: **0 lỗi, 0 cảnh báo**
  - Đã nâng `flutter_riverpod`/`riverpod_generator`/`build_runner` lên bản mới nhất (Riverpod 3.x, `analyzer` 13.x) — bản ghim ban đầu (Riverpod 2.6.x) bị crash codegen (`visitDotShorthandPropertyAccess`) do không tương thích với Dart 3.13.2 (Flutter 3.47.2 quá mới so với hệ sinh thái analyzer lúc ghim); xem lịch sử fix nếu gặp lại lỗi này khi thêm SDK mới.
  - API `valueOrNull` bị Riverpod 3.x gộp vào `.value` (giờ nullable) — đã cập nhật `app_router.dart`

## Chạy backend (cần Docker Desktop hoặc PostgreSQL cài local trước)

```bash
cd apps/api
cp .env.example .env        # sửa JWT_SECRET, DATABASE_URL nếu cần
uv sync
uv run alembic upgrade head
uv run python scripts/seed.py
uv run uvicorn app.main:app --reload
```

Hoặc qua Docker (từ `infra/`):

```bash
cd infra
docker compose up -d postgres redis
# rồi chạy alembic/seed như trên (DATABASE_URL trỏ localhost:5432)
docker compose up -d api    # hoặc chạy uvicorn cục bộ khi dev
```

Test: `cd apps/api && uv run pytest`

## Chạy Flutter

```bash
cd apps/mobile
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # sinh *.g.dart (Riverpod) + app_localizations.dart
flutter run -d chrome        # Web
flutter run -d <android-id>  # Android (emulator dùng 10.0.2.2 để gọi API)
```

Tài khoản seed mặc định: `admin@ltarc.vn` / `director@ltarc.vn`, mật khẩu `ChangeMe123!`.

## Phase 0 — Definition of Done: ĐẠT

- [x] Docker Desktop + PostgreSQL local, migration thật chạy trên Postgres (không chỉ SQLite test)
- [x] `flutter analyze` sạch sau build_runner
- [ ] Đổi `JWT_SECRET` trong `.env` trước khi deploy thật (không dùng giá trị mặc định — hiện chỉ dùng default cho dev)
- [ ] Lượt `code-quality-review` (skill) đầy đủ trước khi merge — chưa chạy chính thức, chỉ mới tự sửa 2 bug phát hiện qua chạy Postgres thật

## Phase 1 — Core ops

- ✅ **Backend hoàn chỉnh, đã xác minh trên Postgres thật** — Departments/Employees CRUD, Leads (FR-2, filter theo bộ phận cho Trưởng BP, chặn Nhân viên), convert Lead→Project (FR-2.3, chặn convert 2 lần), Projects (FR-3, mã tự sinh `LT-YYMM-NN`, gán nhiều Trưởng bộ phận FR-3.5, cập nhật tiến độ theo giai đoạn FR-3.4), Tasks + subtask (FR-5.1/5.2 — cha không tự Done khi con dở dang, đã test cả 2 chiều), WorkItems (FR-5.5, tự tính thành tiền), Activities tự động ghi + thu hẹp phạm vi theo vai trò (FR-18.2)
  - 15/15 test pass (SQLite) + full smoke test thật qua HTTP trên Postgres: login → tạo bộ phận → tạo lead → convert thành dự án (409 khi convert lần 2) → tạo task cha/con → chặn hoàn thành cha khi con dở dang (409) → hoàn thành con → hoàn thành cha → tạo work item (thành tiền đúng) → activity log đúng số lượng
  - **3 bug thật phát hiện qua Postgres** (SQLite không bắt được), đã fix:
    1. FK vòng `Lead.converted_project_id ↔ Project.lead_id` — Alembic cảnh báo "unresolvable cycles"; `use_alter=True` inline trong `create_table()` bị **rơi mất constraint** (không lỗi, chỉ âm thầm thiếu) — phải tách thành `op.create_foreign_key()` riêng sau khi cả 2 bảng tồn tại
    2. Migration downgrade không `DROP TYPE` cho Postgres ENUM (`role`, `leadstatus`, `projectcategory`,...) — enum mồ côi lại collide `DuplicateObjectError` ở lần upgrade kế tiếp; đã thêm drop tường minh vào cả 2 migration
  - RBAC đã test tận API: Nhân viên bị 403 với `/api/leads`; Nhân viên chỉ sửa được task của chính mình (403 nếu không phải); Trưởng bộ phận không tạo được task ngoài bộ phận (403)
- ✅ **Flutter UI Phase 1** — `features/{dashboard,leads,projects,tasks,activities,departments}` theo đúng skill `flutter-riverpod` (`data/application/presentation`):
  - Dashboard: stat card (dự án/việc đang làm/việc quá hạn) + feed hoạt động gần đây, tự refresh
  - Leads: danh sách + filter theo trạng thái (chip) + form tạo nhanh (bottom sheet)
  - Projects: danh sách dạng card (mã, khách hàng, tiến độ) + trang chi tiết skeleton (tab Tổng quan/Công việc)
  - Tasks: Kanban 3 cột (Cần làm/Đang làm/Đã hoàn thành), cập nhật tiến độ qua slider, cảnh báo quá hạn
  - `mobile_shell.dart`/`web_shell.dart` nối điều hướng thật (bottom nav / sidebar) thay placeholder Phase 0
  - **Đã verify:** `flutter analyze` 0 issues, `build_runner` codegen thành công, **`flutter build web` build thật thành công** (bắt lỗi runtime/type mà `analyze` bỏ sót)
  - **Chưa verify được bằng tương tác trình duyệt thật** — đã thử mở bản build trong Browser pane (serve qua `python -m http.server`, trỏ vào API Postgres thật) nhưng môi trường phiên này không compositing được canvas của Flutter Web (`screenshot`/`read_page` không truy cập được nội dung do Flutter Web dùng CanvasKit, không phải DOM thường) — đây là giới hạn công cụ của phiên làm việc, không phải lỗi code. **Cần người dùng tự mở `flutter run -d chrome` và click thử** (đăng nhập → xem dashboard → tạo lead → xem Kanban) trước khi coi Phase 1 UI là DoD đầy đủ.

Xem checklist đầy đủ (kèm SRS FR tham chiếu) ở [docs/IMPLEMENTATION-PLAN-v2.md](../docs/IMPLEMENTATION-PLAN-v2.md) §7 Phase 1.
