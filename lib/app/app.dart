import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/app/config/app_config_provider.dart';
import 'package:sale_lagi_hai/core/l10n/l10n.dart';
import 'package:sale_lagi_hai/core/l10n/locale_controller.dart';
import 'package:sale_lagi_hai/design_system/gallery/theme_preview_page.dart';
import 'package:sale_lagi_hai/design_system/theme/app_theme.dart';

/// Root widget: the brand theme (light, dark and high contrast, following
/// the system) in the chosen language, English or Urdu (right-to-left).
/// Routing (1.5) plugs in here next.
class App extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final locale = ref.watch(localeControllerProvider);
    final script = AppLocales.isRtl(locale) ? AppScript.urdu : AppScript.latin;
    return MaterialApp(
      // The flavor's name (e.g. "SLH Dev") in the task switcher, so test
      // builds are never mistaken for production.
      title: config.appName,
      debugShowCheckedModeBanner: false,
      locale: locale,
      supportedLocales: AppLocales.supported,
      // Not AppLocalizations.localizationsDelegates: the generated list uses
      // the SDK's old Material localizations, which material_ui widgets
      // cannot read.
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      theme: AppTheme.light(script: script),
      darkTheme: AppTheme.dark(script: script),
      highContrastTheme: AppTheme.build(
        brightness: Brightness.light,
        script: script,
        highContrast: true,
      ),
      highContrastDarkTheme: AppTheme.build(
        brightness: Brightness.dark,
        script: script,
        highContrast: true,
      ),
      // Placeholder home until navigation lands in sub-phase 1.5.
      home: const ThemePreviewPage(),
    );
  }
}

/// Shown instead of the app when the build was misconfigured, so a broken
/// build fails loudly on first launch rather than misbehaving later.
class ConfigErrorApp extends StatelessWidget {
  const new({required this.problems, super.key});

  final List<String> problems;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App configuration error',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'App configuration error',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              for (final problem in problems) Text('• $problem'),
            ],
          ),
        ),
      ),
    );
  }
}
