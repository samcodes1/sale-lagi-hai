import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/app/config/app_config_provider.dart';
import 'package:sale_lagi_hai/app/router/routes.dart';
import 'package:sale_lagi_hai/core/l10n/l10n.dart';
import 'package:sale_lagi_hai/core/result/result.dart';
import 'package:sale_lagi_hai/design_system/tokens/brand_tokens.dart';
import 'package:sale_lagi_hai/features/auth/application/auth_providers.dart';
import 'package:sale_lagi_hai/features/auth/domain/auth_repository.dart';
import 'package:sale_lagi_hai/features/auth/domain/phone_number.dart';
import 'package:sale_lagi_hai/features/profile/presentation/language_choice.dart';

/// Profile tab: the account (sign in to sync, or who is signed in, sign
/// out, delete), My cards, the language, Settings (and, outside
/// production, developer tools).
class ProfileScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final isProduction = ref.watch(appConfigProvider).flavor.isProduction;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navProfile)),
      body: ListView(
        children: [
          const _AccountSection(),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.credit_card),
            title: Text(l10n.myCardsTitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => const MyCardsRoute().push<void>(context),
          ),
          const Divider(),
          const LanguageChoice(),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: Text(l10n.settingsTitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => const SettingsRoute().push<void>(context),
          ),
          if (!isProduction) ...[
            const Divider(),
            // Developer tool: its label is not localized on purpose.
            ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: const Text('Theme preview (dev)'),
              onTap: () => const ThemePreviewRoute().go(context),
            ),
            ListTile(
              leading: const Icon(Icons.widgets_outlined),
              title: const Text('Widget gallery (dev)'),
              onTap: () => const WidgetGalleryRoute().go(context),
            ),
          ],
        ],
      ),
    );
  }
}

/// A guest sees why and how to sign in; a signed-in shopper sees who they
/// are (the number partly hidden), and can sign out or delete the account.
class _AccountSection extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider).value;

    Widget heading() => ListTile(
      title: Semantics(
        header: true,
        child: Text(l10n.settingsAccount, style: theme.textTheme.titleMedium),
      ),
    );

    if (user == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          heading(),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              BrandSpacing.s5,
              0,
              BrandSpacing.s5,
              BrandSpacing.s5,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.profileGuestTitle, style: theme.textTheme.bodyLarge),
                const SizedBox(height: BrandSpacing.s4),
                FilledButton(
                  onPressed: () => const SignInRoute().push<bool>(context),
                  child: Text(l10n.actionSignIn),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final who = switch (user) {
      AppUser(phone: final phone?) => PakistanPhone.masked(phone),
      AppUser(email: final email?) => email,
      _ => l10n.settingsAccount,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        heading(),
        ListTile(
          leading: const ExcludeSemantics(child: Icon(Icons.person_outline)),
          // Numbers and addresses read left to right in both languages,
          // but sit at the start of the row like everything else.
          title: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(who, textDirection: TextDirection.ltr),
          ),
          subtitle: Text(
            user.method == SignInMethod.google
                ? l10n.profileSignedInGoogle
                : l10n.profileSignedInPhone,
          ),
        ),
        ListTile(
          leading: const ExcludeSemantics(child: Icon(Icons.logout)),
          title: Text(l10n.actionSignOut),
          onTap: () async {
            final messenger = ScaffoldMessenger.maybeOf(context);
            final done = l10n.signedOutToast;
            final result = await ref.read(authRepositoryProvider).signOut();
            if (result is Success) {
              messenger
                ?..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text(done)));
            }
          },
        ),
        ListTile(
          leading: ExcludeSemantics(
            child: Icon(
              Icons.delete_forever_outlined,
              color: theme.colorScheme.error,
            ),
          ),
          title: Text(
            l10n.actionDeleteAccount,
            style: TextStyle(color: theme.colorScheme.error),
          ),
          onTap: () => const DeleteAccountRoute().push<void>(context),
        ),
      ],
    );
  }
}
