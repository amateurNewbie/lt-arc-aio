---
name: flutter-riverpod
description: >-
  Riverpod provider conventions for ARC AIO (apps/mobile). Use when creating a
  provider, deciding Provider vs FutureProvider vs AsyncNotifier, wiring a
  ConsumerWidget/ConsumerStatefulWidget, testing a provider, or when the user
  mentions Riverpod, ref.watch, ref.read, provider, state management.
---

# Riverpod — ARC AIO

Chosen state management for `apps/mobile`. Codegen style (`riverpod_annotation` +
`riverpod_generator`), not manual `StateNotifierProvider` boilerplate.

## Folder convention

```
lib/features/{feature}/
├── data/            # XxxRepository — talks to FastAPI via the API client
├── application/     # Riverpod providers (xxx_provider.dart, .g.dart generated)
└── presentation/    # ConsumerWidget screens/widgets
```

## Picking a provider type

| Need | Use |
|------|-----|
| Read-only computed/derived value | `@riverpod` function provider (`Provider`) |
| One-shot async fetch (list, detail) | `@riverpod` async function provider (`FutureProvider`) |
| Async state the UI can mutate (create/update/delete, retry) | `@riverpod class ... extends _$Xxx` (`AsyncNotifier`) |
| Local ephemeral UI state (form input, tab index) | `useState` (flutter_hooks) or a small `Notifier` — not a global provider |

Never model server data with plain `StateProvider<T>` — use `AsyncNotifier`/`FutureProvider` so loading/error is handled by `AsyncValue`.

## Widget wiring

```dart
class TaskListScreen extends ConsumerWidget {
  const TaskListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(taskListProvider);
    return tasks.when(
      data: (items) => TaskList(items: items),
      loading: () => const CircularProgressIndicator(),
      error: (e, st) => ErrorView(e),
    );
  }
}
```

- `ref.watch` in `build` to rebuild on change; `ref.read` only inside callbacks (`onPressed`, etc.).
- Mutations go through the notifier's own method (`ref.read(xxxProvider.notifier).create(...)`), which updates its own `AsyncValue` — do not mutate state from the widget.
- Invalidate/refresh with `ref.invalidate(xxxProvider)` after a mutation that another provider depends on, instead of manually re-fetching in the widget.

## Testing

- Use `ProviderContainer` in tests, not pumping a full widget tree, when testing provider logic alone.
- Override the repository provider with a fake in tests (`overrides: [xxxRepositoryProvider.overrideWithValue(FakeRepo())]`).

## Cấm

- `StatefulWidget` + `setState` for anything a provider should own.
- Business/API logic inside a widget's `build` method.
- Mixing Riverpod with Bloc/GetX/`provider` package in the same feature.
- Reading `ref.read` inside `build` for a value that should reactively rebuild.
