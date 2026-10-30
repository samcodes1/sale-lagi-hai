import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/app/router/routes.dart';
import 'package:sale_lagi_hai/core/core_providers.dart';
import 'package:sale_lagi_hai/core/l10n/l10n.dart';
import 'package:sale_lagi_hai/design_system/tokens/brand_tokens.dart';
import 'package:sale_lagi_hai/features/auth/application/auth_providers.dart';
import 'package:sale_lagi_hai/features/onboarding/application/preferences_controller.dart';
import 'package:sale_lagi_hai/features/search/application/search_providers.dart';

/// Privacy (Settings): what is kept where, and ways to clear this phone.
/// Deleting the account is on Profile (and linked here when signed in).
class PrivacyScreen extends ConsumerWidget {
  const new({super.key});

  void _cleared(BuildContext context) {
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(context.l10n.clearedToast)));
  }

  /// Everything on this phone goes, and the shopper is signed out; the
  /// router then returns to onboarding. The account is untouched.
  Future<void> _clearPhone(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.clearPhoneTitle),
        content: Text(l10n.clearPhoneBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.actionClear),
          ),
        ],
      ),
    );
    if (sure != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final note = l10n.clearedToast;
    await ref.read(authRepositoryProvider).signOut();
    try {
      await ref.read(keyValueStoreProvider).clear();
    } on Object catch (error) {
      ref
          .read(loggerProvider)
          .warning(
            'Could not clear this phone',
            context: {'error': error.runtimeType.toString()},
          );
    }
    await ref.read(preferencesProvider.notifier).reset();
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(note)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final signedIn = ref.watch(currentUserProvider).value != null;

    Widget block(String title, String body) => Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        BrandSpacing.s5,
        BrandSpacing.s5,
        BrandSpacing.s5,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(title, style: theme.textTheme.titleMedium),
          ),
          const SizedBox(height: BrandSpacing.s2),
          Text(body, style: theme.textTheme.bodyMedium),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsPrivacy)),
      body: ListView(
        children: [
          block(l10n.privacyOnPhone, l10n.privacyOnPhoneBody),
          block(l10n.privacyInAccount, l10n.privacyInAccountBody),
          Padding(
            padding: const EdgeInsetsDirectional.all(BrandSpacing.s5),
            child: Text(
              l10n.privacyNever,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.history),
            title: Text(l10n.actionClearSearches),
            onTap: () async {
              await ref.read(recentSearchesProvider.notifier).clear();
              if (context.mounted) _cleared(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.cached),
            title: Text(l10n.actionClearCache),
            onTap: () async {
              await ref.read(jsonCacheProvider).clear();
              if (context.mounted) _cleared(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.phonelink_erase_outlined),
            title: Text(l10n.actionClearPhone),
            onTap: () => _clearPhone(context, ref),
          ),
          if (signedIn)
            ListTile(
              leading: Icon(
                Icons.delete_forever_outlined,
                color: theme.colorScheme.error,
              ),
              title: Text(l10n.actionDeleteAccount),
              onTap: () => const DeleteAccountRoute().push<void>(context),
            ),
          const SizedBox(height: BrandSpacing.s8),
        ],
      ),
    );
  }
}
