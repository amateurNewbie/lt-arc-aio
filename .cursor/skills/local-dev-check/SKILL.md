---
name: local-dev-check
description: Verifies local Flutter, Python, Android SDK, and PostgreSQL tooling. Use when checking the Windows env, flutter doctor, or what is still missing to run the app locally.
---

# Local dev check

## When

User asks if the machine is ready, `flutter doctor`, missing installs, PATH, or local run blockers.

## Steps

1. Check commands (do not assume PATH from old terminals):
   - `python --version`, `uv --version`, `git --version`
   - `flutter --version`, `flutter doctor -v`
   - `adb version`
   - `psql --version` or Docker Postgres
2. Confirm env:
   - `ANDROID_HOME` / `ANDROID_SDK_ROOT` = `C:\Users\Windows\AppData\Local\Android\Sdk`
   - Flutter bin: `C:\tools\flutter\flutter_windows_3.47.2-stable\flutter\bin`
3. Known OK on this machine: Python 3.12.6, JDK 17, Flutter 3.47.2, Chrome, Android SDK 36, licenses accepted.
4. Known not required for Web+Android: Visual Studio C++ workload.
5. Known missing until installed: PostgreSQL and/or Docker Desktop; iOS needs macOS.

## Output

Short list: **Ready** vs **Still missing**, with exact next install if anything is missing.
