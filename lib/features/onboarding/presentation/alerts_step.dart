import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/core/device/device_providers.dart';
import 'package:sale_lagi_hai/core/device/notification_permission.dart';
import 'package:sale_lagi_hai/core/l10n/l10n.dart';
import 'package:sale_lagi_hai/core/time/clock.dart';
import 'package:sale_lagi_hai/design_system/tokens/brand_tokens.dart';
import 'package:sale_lagi_hai/features/onboarding/application/preferences_controller.dart';
import 'package:sale_lagi_hai/features/onboarding/presentation/onboarding_scaffold.dart';

/// Step 5: notification priming. It shows what an alert looks like and
/// what we promise (caps, quiet hours, topics). The system dialog appears
/// only after "Turn on alerts"; "Not now" never asks. Either way
/// onboarding ends here, and it is never shown again.
class AlertsStep extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<AlertsStep> createState() => _AlertsStepState();
}

class _AlertsStepState extends ConsumerState<AlertsStep> {
  bool _asking = false;
  bool _blocked = false;

  Future<void> _finish() =>
      ref.read(preferencesProvider.notifier).completeOnboarding();

  Future<void> _turnOn() async {
    if (_asking) return;
    setState(() => _asking = true);
    final preferences = ref.read(preferencesProvider.notifier);
    await preferences.markAlertsAsked(ref.read(clockProvider)());
    final result = await ref.read(notificationPermissionProvider).request();
    if (!mounted) return;
    if (result == AlertPermission.permanentlyDenied && kIsWeb) {
      // Browsers have no app settings page to send the shopper to: say so
      // (the blocked note) and finish, never a dead button (BUG-7).
      setState(() => _blocked = true);
      await _finish();
      return;
    }
    if (result == AlertPermission.permanentlyDenied) {
      // Android won't show the dialog: say so and offer settings instead
      // of silently doing nothing.
      setState(() {
        _asking = false;
        _blocked = true;
      });
      return;
    }
    await _finish();
  }

  Future<void> _notNow() async {
    if (_asking) return;
    _asking = true;
    await ref
        .read(preferencesProvider.notifier)
        .markAlertsAsked(ref.read(clockProvider)());
    await _finish();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return OnboardingScaffold(
      step: 5,
      title: l10n.alertsTitle,
      intro: l10n.alertsBody,
      slivers: [
        SliverPadding(
          padding: onboardingContentPadding,
          sliver: SliverList.list(
            children: [
              const _ExampleAlert(),
              const SizedBox(height: BrandSpacing.s7),
              for (final (icon, text) in [
                (Icons.notifications_active_outlined, l10n.alertsPromiseCap),
                (Icons.bedtime_outlined, l10n.alertsPromiseQuiet),
                (Icons.tune, l10n.alertsPromiseTopics),
              ])
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    bottom: BrandSpacing.s4,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ExcludeSemantics(
                        child: Icon(icon, color: scheme.secondary),
                      ),
                      const SizedBox(width: BrandSpacing.s4),
                      Expanded(
                        child: Text(text, style: theme.textTheme.bodyLarge),
                      ),
                    ],
                  ),
                ),
              if (_blocked)
                Semantics(
                  liveRegion: true,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(
                      top: BrandSpacing.s3,
                    ),
                    child: Text(
                      l10n.alertsBlocked,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
      primaryLabel: _blocked
          ? l10n.actionOpenSettings
          : l10n.actionTurnOnAlerts,
      onPrimary: _asking
          ? null
          : _blocked
          ? () async {
              await ref.read(notificationPermissionProvider).openSettings();
              await _finish();
            }
          : _turnOn,
      secondaryLabel: _blocked ? l10n.actionContinue : l10n.actionNotNow,
      onSecondary: _asking ? null : (_blocked ? _finish : _notNow),
    );
  }
}

/// A sample notification, drawn like Android's, so shoppers see exactly
/// what they would get. Read as one item: "Example alert: Threads: up to
/// 50% off. Winter collection sale, ends Sunday".
class _ExampleAlert extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      container: true,
      label:
          '${l10n.alertsExampleLabel}: ${l10n.alertsExampleTitle}. '
          '${l10n.alertsExampleBody}',
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BrandRadii.card,
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.all(BrandSpacing.s5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: scheme.primary,
                  foregroundColor: scheme.onPrimary,
                  child: const Icon(Icons.local_offer, size: 18),
                ),
                const SizedBox(width: BrandSpacing.s4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.appTitle,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: BrandSpacing.s2),
                      Text(
                        l10n.alertsExampleTitle,
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(
                        l10n.alertsExampleBody,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
