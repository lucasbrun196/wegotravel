import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/theme/app_theme.dart';
import '../shared/widgets/feedback/app_toast.dart';
import '../shared/widgets/feedback/sync_banner.dart';
import 'providers.dart';
import 'router.dart';

class VacationApp extends ConsumerWidget {
  const VacationApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'WeGoTravel',
      debugShowCheckedModeBanner: false,
      routerConfig: ref.watch(routerProvider),
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(themeModeProvider),
      themeAnimationDuration: const Duration(milliseconds: 240),
      themeAnimationCurve: Curves.easeOutCubic,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      scrollBehavior: const _AppScrollBehavior(),

      // Acima de qualquer rota: o aviso de offline é da sessão, não de
      // uma tela. Fica fora do `routerConfig` para não ser remontado a
      // cada navegação.
      builder: (context, child) => ToastHost(
        child: SyncBanner(child: child ?? const SizedBox.shrink()),
      ),
    );
  }
}

/// Na web, arrastar com o mouse precisa rolar a lista — o padrão do
/// Flutter só permite roda do mouse e trackpad.
class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}
