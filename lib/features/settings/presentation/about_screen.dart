import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/app/config/app_config_provider.dart';
import 'package:sale_lagi_hai/core/core_providers.dart';
import 'package:sale_lagi_hai/core/l10n/l10n.dart';
import 'package:sale_lagi_hai/core/links/open_link.dart';
import 'package:sale_lagi_hai/design_system/tokens/brand_tokens.dart';
import 'package:sale_lagi_hai/features/settings/application/app_info.dart';

/// About: the app, its version, open-source licences, and how to reach us
/// (when this build has a support address).
class AboutScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final config = ref.watch(appConfigProvider);
    final version = ref.watch(appVersionProvider).value ?? '';
    final email = config.supportEmail;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsAbout)),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.all(BrandSpacing.s5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    l10n.appTitle,
                    style: theme.textTheme.headlineSmall,
                  ),
                ),
                const SizedBox(height: BrandSpacing.s2),
                Text(l10n.aboutTagline, style: theme.textTheme.bodyLarge),
                if (version.isNotEmpty) ...[
                  const SizedBox(height: BrandSpacing.s3),
                  Text(
                    l10n.aboutVersion(version),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(),
          if (email.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.mail_outline),
              title: Text(l10n.aboutContact),
              onTap: () =>
                  openLink(context, ref.read(linkServiceProvider).email(email)),
            ),
          ListTile(
            leading: const Icon(Icons.article_outlined),
            title: Text(l10n.aboutLicenses),
            onTap: () => showLicensePage(
              context: context,
              applicationName: l10n.appTitle,
              applicationVersion: version,
            ),
          ),
        ],
      ),
    );
  }
}
