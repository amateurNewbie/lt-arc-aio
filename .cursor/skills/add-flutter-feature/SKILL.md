---
name: add-flutter-feature
description: Adds a Flutter screen or feature wired to the FastAPI backend. Use when building UI, navigation, or client API calls in the Flutter app.
---

# Add Flutter feature

## Steps

1. Identify screen, route, and data from the API.
2. Put API calls in a repository class (e.g. `XxxRepository`), exposed to widgets only through a Riverpod provider — never called directly from a widget. See `flutter-riverpod` skill for provider shape (`FutureProvider` / `AsyncNotifier`).
3. Widget consuming state extends `ConsumerWidget` / `ConsumerStatefulWidget`, watches the provider with `ref.watch`, and renders the `AsyncValue` (loading / data / error) — do not hand-roll `FutureBuilder` + `setState` for server data.
4. Use `10.0.2.2` for Android emulator localhost; `127.0.0.1` for Chrome.
5. Keep widgets small; extract private widgets in the same file until reuse is real.
6. Run `flutter analyze` on touched Dart files.

## Do not

- Add Bloc/GetX/the standalone `provider` package on top of Riverpod.
- Use `StatefulWidget` + `setState` for state that a provider should own (server data, cross-widget state).
- Hardcode production URLs.
