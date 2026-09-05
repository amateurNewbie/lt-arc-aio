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
flutter run -d chrome --web-port 5173   # Web — port PHẢI nằm trong `cors_origins` (apps/api/app/core/config.py,
                                         # mặc định cho phép localhost/127.0.0.1 ở 5173 và 8010); port khác bị
                                         # trình duyệt chặn CORS, Flutter hiện nhầm lỗi "Invalid email or password"
flutter run -d <android-id>  # Android (emulator dùng 10.0.2.2 để gọi API)

# Nếu backend không chạy ở cổng mặc định 8000 (vd cổng 8000 bị chiếm), trỏ Flutter sang cổng khác:
flutter run -d chrome --web-port 5173 --dart-define=API_BASE_URL=http://127.0.0.1:8010
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

## Phase 2 — Finance

- ✅ **Backend hoàn chỉnh, đã xác minh trên Postgres thật** — Migration 0003 (7 bảng mới: BudgetEstimate/Line, FundAccount, CashLedgerEntry, Contract/Milestone, ProjectCost, Payment, Payable, OverheadCost/Allocation):
  - Cost categories CRUD (FR-7, thiếu từ Phase 0 — bổ sung luôn)
  - Budget: Nháp → Chờ duyệt → Đã duyệt (FR-4.2, không ngưỡng tự duyệt)
  - Sổ Thu&Chi: Chi bắt buộc gắn hạng mục PROJECT-scope (FR-6.2) + cảnh báo trùng ±3 ngày (FR-6.6, trả `duplicate_warning` chứ không tự chặn — client tự confirm lại)
  - Hợp đồng + đợt thanh toán: tổng tỷ lệ phải = 100% (FR-9.2); **collect milestone atomic** — 1 Payment + 1 CashLedgerEntry + cập nhật milestone + cập nhật số dư quỹ trong cùng transaction (invariant #3), chặn thu vượt phần còn lại
  - Công nợ 2 chiều: Receivables (từ milestone còn dở dang) + Payables (+settle, atomic với Sổ quỹ)
  - Quỹ & Sổ quỹ (FR-12)
  - Chi phí chung & phân bổ: 2 công thức (doanh thu / chia đều), preview không ghi DB, apply **idempotent theo tháng** (FR-8.2/8.3)
  - Báo cáo P&L theo dự án + theo tháng, Cashflow theo tháng (FR-11/FR-12.4)
  - Cấp quyền theo FR-1.7 thật sự được dùng lần đầu: `PROJECT_CASHBOOK`/`CONTRACTS_COLLECT`/`DEBTS`/`FUNDS`/`OVERHEAD_ALLOCATE` — Trưởng bộ phận mặc định thao tác được trên dự án mình phụ trách (FR-3.5) qua `require_project_finance_write`, người khác cần được cấp quyền bổ sung
  - 21/21 test pass (SQLite, +6 test tài chính mới) + full smoke test thật qua HTTP trên Postgres: budget approve → chi phí (dup warning + confirm) → hợp đồng 3 đợt → collect (chặn overpay) → payable settle → overhead declare/preview/apply (chặn apply 2 lần) → P&L dự án khớp số → cashflow khớp số
  - **3 bug thật phát hiện qua Postgres/pytest** (không phải lỗi giả định), đã fix:
    1. Field tên `date` trùng type `date` (từ `datetime import date`) gây lỗi Pydantic khó hiểu ở nhiều model **và** schema mới — fix bằng alias `date as date_type` toàn bộ
    2. FK vòng thật thứ 2 phát hiện qua Alembic (`fundtype`/enum khác) — không có, nhưng khi drop enum ở downgrade migration 0003 suýt drop nhầm `projectcategory` (dùng chung với `Project.category` từ migration 0002) gây lỗi "type in use" — đã loại khỏi danh sách drop của 0003
    3. `PayableSettleRequest` thiếu field `date` (khác `MilestoneCollectRequest` có) — luôn ghi ngày hiện tại, phát hiện khi cashflow report tháng cũ không thấy khoản chi vừa settle; đã bổ sung cho nhất quán
- ✅ **Flutter UI Phase 2** — `features/{budget,contracts,cashbook,funds,debts,overhead,reports,finance,cost_categories,more}`:
  - **Trong chi tiết dự án** (5 tab, thêm 3 so với Phase 1): Dự toán (tạo dòng động + Nháp→Gửi duyệt→Duyệt), Hợp đồng (tạo + validate tổng tỷ lệ 100% client-side + thu tiền theo đợt qua dialog chọn quỹ), Thu & Chi (sổ hợp nhất Chi+Thu, form ghi Chi có hỏi lại khi trùng đúng theo FR-6.6)
  - **Trang mới cấp công ty**: Tài chính (3 tab: P&L | Chi phí chung & phân bổ có Xem trước/Áp dụng riêng theo đúng FR-8.3 | Quỹ & dòng tiền theo tháng), Công nợ (Phải thu/Phải trả + dialog trả nợ), Quỹ (danh sách + sổ quỹ chi tiết từng quỹ)
  - Điều hướng: thêm nhóm "TÀI CHÍNH" vào sidebar Web; mobile thêm màn "Menu" (đúng concept topbar-menu của UI gốc) mở từ icon trên Dashboard vì bottom nav chỉ có 4 chỗ cố định
  - **Đã verify:** `flutter analyze` 0 issues, codegen thành công, `flutter build web` build thật thành công; backend không đổi trong lượt này nên không chạy lại full Postgres E2E (đã verify ở mục backend trên) — **chưa verify bằng tương tác trình duyệt thật**, cùng giới hạn công cụ đã ghi ở Phase 1

Xem checklist đầy đủ ở [docs/IMPLEMENTATION-PLAN-v2.md](../docs/IMPLEMENTATION-PLAN-v2.md) §7 Phase 2.

## Phase 3 — HR + system

- ✅ **Backend hoàn chỉnh, đã xác minh trên Postgres thật** — Migration 0004 (4 bảng mới: `MonthlyWorkDays`, `PayrollRecord`, `FileAsset`, `Notification`) + Migration 0005 (3 cột cấu hình nhắc việc trên `CompanySettings`):
  - Pay profiles (FR-16.5, thiếu từ Phase 0 — bổ sung luôn) + ghi đè lương riêng từng nhân viên qua `PATCH /api/employees/{id}/pay`; `effective_pay()` ưu tiên override cá nhân trên chức danh
  - Workdays: nhập/sửa số công cuối tháng (FR-15.1/15.2), khoá cứng khi kỳ đã trả lương (FR-15.3, invariant #8)
  - Payroll: `run` tính `net_pay = actual_days × daily_rate + Σallowances` (FR-16.1, invariant #7), giữ nguyên snapshot kỳ đã PAID dù chạy lại (FR-16.6); `pay` tạo đúng 1 `CashLedgerEntry` + trừ quỹ + khoá `MonthlyWorkDays` trong cùng luồng nghiệp vụ (FR-16.3); nhân viên chỉ xem phiếu lương của chính mình (FR-16.4)
  - Files project: upload (giới hạn 20MB)/list/download/delete, lưu local disk dưới `FILE_ROOT` (FR-17)
  - Notifications + `run_daily_reminders()` — nhắc việc sắp đến hạn, công nợ/đợt sắp đến hạn, nhắc chạy phân bổ chi phí chung ngày cấu hình được (FR-19.2/FR-8.4); chạy hằng ngày qua APScheduler (cron 01:00, wired trong `app/main.py` lifespan)
  - Settings: thông tin studio + cấu hình số ngày nhắc (FR-20.1/20.2), bảng minh bạch biện pháp bảo mật (FR-20.4, trung thực báo "Chưa áp dụng" cho idle-logout 24h vì thật sự chưa code)
  - **FR-1.6 — Xem thử theo vai trò**: `POST /api/auth/preview-role` (chỉ ADMIN) phát hành access token mang claim `preview_role`; `get_current_user` ghi đè `user.role` trong bộ nhớ (không commit) khi thấy claim này và **chặn cứng mọi method khác GET** (403 "Preview mode is read-only") — toàn bộ `require_roles`/`require_perm` sẵn có tự động tôn trọng vai trò xem thử mà không cần sửa endpoint nào khác
  - Hoàn thiện Activity writers còn thiếu từ Phase 1–2 (FR-18.1): budget submit/approve, task create/update-progress, overhead apply-allocation, contract create — payroll `mark_paid` và workdays `upsert_entries` đã ghi log từ lúc viết
  - Bổ sung `GET /api/users` (chưa từng có ở Phase 0–2) — cần thiết để UI liệt kê người dùng cho Phân quyền bổ sung (FR-1.7) và gán hồ sơ nhân sự (FR-14)
  - 28/28 test pass (SQLite, +7 test HR/payroll/files/notifications mới, gồm cả test 403 cho xem-thử-vai-trò ghi) + full smoke test thật qua HTTP trên Postgres: login → tạo chức danh lương → cấu hình settings → xem thử vai trò (chặn ghi 403) → danh sách thông báo
  - **Bug thật phát hiện khi đóng gap migration** (không phải giả định): 3 cột `*_reminder_days`/`overhead_reminder_day` được thêm thẳng vào model `CompanySettings` nhưng **quên tạo migration** — nếu không phát hiện, `get_company_settings()` sẽ vỡ với lỗi cột không tồn tại ngay khi chạy trên Postgres thật (SQLite test không bắt được vì `metadata.create_all()` tạo bảng từ model hiện tại, không qua Alembic); đã tạo migration 0005 với `server_default` để không vỡ dữ liệu `CompanySettings` đã seed
- ✅ **Flutter UI Phase 3** — `features/{pay_profiles,employees,workdays,payroll,hr,files,notifications,settings,users}` theo đúng skill `flutter-riverpod`:
  - **Trang mới "Nhân sự & Lương"** (4 tab): Nhân viên (gán chức danh/ghi đè lương), Chức danh lương (CRUD đơn giá + phụ cấp động), Số công (lưới nhập theo tháng, khoá rõ ràng khi đã trả lương), Lương (tính lương/trả lương theo tháng, chọn quỹ chi)
  - **Trang mới "Cài đặt"** (4 tab): Thông tin chung (studio info + cấu hình nhắc việc), Bảo mật (đọc từ `/api/settings/security-status`), Phân quyền (chọn người dùng → cấp/thu hồi quyền theo 6 nhóm, chọn toàn bộ hoặc một số dự án), Xem thử vai trò
  - **FR-1.6 UI**: dải cảnh báo màu vàng cố định phía trên toàn app khi đang xem thử ("Đang xem thử vai trò: X — Thoát"); token xem thử chỉ giữ trong bộ nhớ `ApiClient` (không lưu `SecureStorage`), thoát là phục hồi ngay phiên thật
  - **Tab "Tệp" mới trong chi tiết dự án** (6 tab, thêm 1 so với Phase 2): upload qua `file_picker`, tải xuống cross-platform (Web dùng `dart:html` Blob + `<a download>`, desktop/mobile dùng hộp thoại lưu tệp gốc — 2 cách hoàn toàn khác nhau nên phải viết `core/download/` với conditional export theo nền tảng biên dịch)
  - Icon chuông thông báo có badge số chưa đọc trên Dashboard (dùng chung cho cả mobile và web vì `DashboardPage` là trang đầu tiên của cả 2 shell)
  - Điều hướng: thêm 2 nhóm "TỔ CHỨC"/"HỆ THỐNG" vào sidebar Web; mobile thêm 2 mục vào màn "Menu" đã có từ Phase 2
  - **Đã verify:** `flutter analyze` sạch (chỉ 2 info-level lint về cú pháp null-aware, nhất quán với style đã có sẵn ở 3 file Phase 1–2 khác — không sửa để giữ nhất quán), codegen thành công (25 file `.g.dart` mới), **`flutter build web --release` build thật thành công**
  - **Chưa verify được bằng tương tác trình duyệt thật** — đã khởi động `flutter run -d web-server` thật + trỏ vào API Postgres thật qua Browser pane, nhưng công cụ `screenshot` báo lỗi "Browser pane is not displayed, so the page is not compositing frames"; kiểm tra sâu hơn cho thấy Flutter Web engine tự nó cũng không commit được frame đầu tiên (mọi module `.dart.lib.js` tải thành công 200 OK, không lỗi console, nhưng `<flt-scene>` luôn rỗng) — nhất quán với việc pane không được compositor hiển thị, cùng giới hạn công cụ đã ghi nhận ở Phase 1–2, không phải lỗi code. **Cần người dùng tự chạy `flutter run -d chrome` và click thử** (Nhân sự & Lương, Cài đặt → Xem thử vai trò, tab Tệp trong 1 dự án) trước khi coi Phase 3 UI là DoD đầy đủ.

Xem checklist đầy đủ ở [docs/IMPLEMENTATION-PLAN-v2.md](../docs/IMPLEMENTATION-PLAN-v2.md) §7 Phase 3.
