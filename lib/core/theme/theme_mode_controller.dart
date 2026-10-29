import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sale_lagi_hai/core/core_providers.dart';

/// Light, dark, or as the phone is set (the default).
enum AppThemeMode {
  system,
  light,
  dark;

  static AppThemeMode fromName(String? name) =>
      values.where((m) => m.name == name).firstOrNull ?? system;

  Brightness? get brightness => switch (this) {
    system => null,
    light => Brightness.light,
    dark => Brightness.dark,
  };
}

/// Storage key for the chosen theme.
const themeModeStorageKey = 'settings.theme';

/// The theme saved by an earlier session, read once in `bootstrap` before
/// the first frame (no flash of the wrong theme).
final savedThemeModeProvider = Provider<AppThemeMode>(
  (ref) => AppThemeMode.system,
);

final themeModeProvider = NotifierProvider<ThemeModeController, AppThemeMode>(
  ThemeModeController.new,
);

final class ThemeModeController extends Notifier<AppThemeMode> {
  @override
  AppThemeMode build() => ref.watch(savedThemeModeProvider);

  /// Switches and saves. A failed save is logged; the switch still applies
  /// for this session.
  Future<void> select(AppThemeMode mode) async {
    state = mode;
    try {
      await ref
          .read(keyValueStoreProvider)
          .setString(themeModeStorageKey, mode.name);
    } on Object catch (error) {
      ref
          .read(loggerProvider)
          .warning(
            'Could not save the theme choice',
            context: {'error': error.runtimeType.toString()},
          );
    }
  }
}
