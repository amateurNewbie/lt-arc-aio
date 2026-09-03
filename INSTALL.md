# Hướng dẫn cài đặt môi trường local
## Stack: Flutter (Web + Android) · FastAPI · PostgreSQL · Windows 10/11

> **Lưu ý iOS:** Windows không thể build/run iOS. Viết shared Flutter code trên Windows được, nhưng cần macOS + Xcode để build IPA hoặc chạy iOS Simulator.

---

## Trạng thái hiện tại (đã cài sẵn)

| Tool | Version | Ghi chú |
|------|---------|---------|
| Python | 3.12.6 | ✅ Đã cài, `JAVA_HOME` có sẵn |
| pip | 24.2 | ✅ |
| uv | 0.12.5 | ✅ Package manager tốc độ cao |
| Git | 2.55.0 | ✅ |
| Java (JDK 17) | Temurin 17.0.20 | ✅ `JAVA_HOME` đã có |

---

## Cần cài thêm (theo thứ tự)

---

### 1. Flutter SDK

**Download:**
```
https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.47.2-stable.zip
```

**Các bước:**

1. Tải file zip về
2. Giải nén ra `C:\tools\flutter` (tạo thư mục nếu chưa có)
3. Thêm `C:\tools\flutter\bin` vào **System PATH**:
   - Nhấn `Win + S` → tìm **"Edit the system environment variables"**
   - Chọn **Environment Variables…**
   - Chọn `Path` ở **System variables** → **Edit** → **New**
   - Nhập `C:\tools\flutter\bin` → OK hết

4. Mở terminal mới, kiểm tra:
```powershell
flutter --version
```

---

### 2. Chrome (để chạy Flutter Web)

Nếu chưa có Chrome:
```
https://www.google.com/chrome/
```

Kiểm tra Flutter nhận browser:
```powershell
flutter devices
```
Phải thấy `Chrome (web)` trong danh sách.

---

### 3. Android Studio

**Download:**
```
https://developer.android.com/studio
```

**Khi cài, chọn đầy đủ các component sau (bỏ qua là thiếu toolchain):**
- ✅ Android SDK
- ✅ Android SDK Platform
- ✅ Android Virtual Device (AVD)
- ✅ Android SDK Command-line Tools

**Sau khi cài xong Android Studio:**

Mở Android Studio → **SDK Manager** → tab **SDK Tools** → bật thêm:
- ✅ Android SDK Command-line Tools (latest)
- ✅ Android SDK Platform-Tools
- ✅ Android SDK Build-Tools (34 trở lên)

---

### 4. Biến môi trường Android

Sau khi cài Android Studio, thêm các biến này vào **System Environment Variables**:

| Tên biến | Giá trị mặc định |
|----------|-----------------|
| `ANDROID_HOME` | `C:\Users\<tên_user>\AppData\Local\Android\Sdk` |
| `ANDROID_SDK_ROOT` | `C:\Users\<tên_user>\AppData\Local\Android\Sdk` |

Thêm vào **System PATH**:
```
%ANDROID_HOME%\platform-tools
%ANDROID_HOME%\cmdline-tools\latest\bin
```

> Thay `<tên_user>` bằng tên user Windows của bạn (ví dụ: `Windows`).
> Ví dụ: `C:\Users\Windows\AppData\Local\Android\Sdk`

**Sau đó chạy:**
```powershell
flutter doctor --android-licenses
```
Nhấn `y` cho tất cả các license rồi Enter.

**Kiểm tra:**
```powershell
adb version
flutter doctor -v
```

---

### 5. PostgreSQL

**Download (EDB official installer):**
```
https://www.enterprisedb.com/downloads/postgres-postgresql-downloads
```
Chọn **PostgreSQL 16** → **Windows x86-64**

**Cài đặt:**
- Port: `5432` (giữ mặc định)
- Superuser: `postgres`
- Password: tự đặt (ghi lại, dùng sau trong FastAPI `.env`)
- Bỏ chọn **StackBuilder** ở bước cuối (không cần)

**Thêm vào PATH** (nếu installer chưa tự thêm):
```
C:\Program Files\PostgreSQL\16\bin
```

**Kiểm tra:**
```powershell
psql --version
psql -U postgres -W
```

---

### 6. Docker Desktop *(khuyến nghị)*

Docker giúp chạy PostgreSQL, Redis hoặc các service khác qua container, không cần cài thẳng lên máy.

**Download:**
```
https://www.docker.com/products/docker-desktop/
```

> Yêu cầu: WSL 2 (Windows 10 build 19041+). Nếu bị hỏi, chọn **Use WSL 2 based engine**.

**Kiểm tra:**
```powershell
docker --version
docker compose version
```

---

## Kiểm tra tổng thể sau khi cài xong

Chạy lệnh này để kiểm tra một lần:

```powershell
python --version
java -version
flutter --version
flutter doctor -v
adb version
psql --version
docker --version
docker compose version
```

Kết quả mong đợi của `flutter doctor -v`:

```
[✓] Flutter
[✓] Windows Version
[✓] Android toolchain
[✓] Chrome - develop for the web
[✓] Android Studio
[!] VS Code (optional)
[✓] Connected device
[✓] Network resources
```

> Mục `[!] VS Code` không ảnh hưởng, bỏ qua được.

---

## Thứ tự cài nếu muốn bắt đầu nhanh nhất

```
Flutter SDK  →  Android Studio  →  Set ANDROID_HOME  →  flutter doctor --android-licenses  →  PostgreSQL
```

Docker Desktop có thể cài sau, khi cần chạy Postgres bằng container thay vì cài thẳng.
