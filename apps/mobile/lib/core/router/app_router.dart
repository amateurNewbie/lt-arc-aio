import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../adaptive/adaptive_shell.dart';
import '../../features/auth/application/auth_provider.dart';
import '../../features/auth/presentation/login_page.dart';

part 'app_router.g.dart';

class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(Ref ref) {
    ref.listen(authProvider, (previous, next) => notifyListeners());
  }
}

@riverpod
GoRouter goRouter(Ref ref) {
  final refresh = _AuthRefreshNotifier(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: refresh,
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      if (authState.isLoading) return null;

      final isLoggedIn = authState.value != null;
      final isLoggingIn = state.matchedLocation == '/login';

      if (!isLoggedIn) return isLoggingIn ? null : '/login';
      if (isLoggedIn && isLoggingIn) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(path: '/home', builder: (context, state) => const AdaptiveShell()),
    ],
  );
}
