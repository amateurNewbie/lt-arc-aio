import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/i18n/app_localizations.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_provider.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    final webThemeMode = ref.watch(webThemeModeProvider);

    return MaterialApp.router(
      title: 'LT ARC',
      debugShowCheckedModeBanner: false,
      theme: kIsWeb ? AppTheme.webLight() : AppTheme.mobile(),
      darkTheme: kIsWeb ? AppTheme.webDark() : AppTheme.mobile(),
      themeMode: kIsWeb ? webThemeMode : ThemeMode.light,
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}
