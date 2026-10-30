import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/app/router/routes.dart';
import 'package:sale_lagi_hai/core/device/device_providers.dart';
import 'package:sale_lagi_hai/core/device/notification_permission.dart';
import 'package:sale_lagi_hai/core/l10n/l10n.dart';
import 'package:sale_lagi_hai/core/result/app_failure.dart';
import 'package:sale_lagi_hai/design_system/tokens/brand_tokens.dart';
import 'package:sale_lagi_hai/design_system/widgets/message_view.dart';
import 'package:sale_lagi_hai/design_system/widgets/state_views.dart';
import 'package:sale_lagi_hai/features/settings/application/alert_prefs_providers.dart';
import 'package:sale_lagi_hai/features/settings/domain/alert_prefs.dart';

/// Notification settings (screen S19): push on or off, what to be told
/// about, how often, and quiet hours. Each change saves at once; a failed
/// save comes back as it was, with a note.
class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  AlertPermission? _permission;

  @override
  void initState() {
    super.initState();
    unawaited(_checkPermission());
  }

  Future<void> _checkPermission() async {
    final status = await ref.read(notificationPermissionProvider).status();
    if (mounted) setState(() => _permission = status);
  }

  Future<void> _save(AlertPrefs next) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final note = context.l10n.notifSaveFailed;
    final failure = await ref.read(alertPrefsProvider.notifier).change(next);
    if (failure != null) {
      messenger
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(note)));
    }
  }

  /// Turning push on asks the system first (Android 13+); only a grant
  /// turns it on.
  Future<void> _setPush(AlertPrefs prefs, {required bool on}) async {
    if (!on) return await _save(_with(prefs, pushEnabled: false));
    final permission = ref.read(notificationPermissionProvider);
    var status = await permission.status();
    if (status == AlertPermission.denied) status = await permission.request();
    if (!mounted) return;
    setState(() => _permission = status);
    if (status == AlertPermission.granted ||
        status == AlertPermission.unavailable) {
      await _save(_with(prefs, pushEnabled: true));
    }
  }

  Future<void> _pickTime(AlertPrefs prefs, {required bool start}) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final current = start ? prefs.quietStart : prefs.quietEnd;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current.hour, minute: current.minute),
    );
    if (picked == null || !mounted) return;
    final value = (hour: picked.hour, minute: picked.minute);
    final other = start ? prefs.quietEnd : prefs.quietStart;
    if (value == other) {
      messenger
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.quietSame)));
      return;
    }
    await _save(
      start ? _with(prefs, quietStart: value) : _with(prefs, quietEnd: value),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final prefs = ref.watch(alertPrefsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsNotifications)),
      body: switch (prefs) {
        AsyncData(value: null) => MessageView(
          icon: Icons.notifications_none,
          message: l10n.notifSignIn,
          actionLabel: l10n.actionSignIn,
          onAction: () => const SignInRoute().push<bool>(context),
        ),
        AsyncData(:final value?) => _form(context, value),
        AsyncError(:final error) => ErrorView(
          failure: error is AppFailure ? error : const UnexpectedFailure(),
          onRetry: () => ref.invalidate(alertPrefsProvider),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Widget _form(BuildContext context, AlertPrefs prefs) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final local = MaterialLocalizations.of(context);
    String time(({int hour, int minute}) t) =>
        local.formatTimeOfDay(TimeOfDay(hour: t.hour, minute: t.minute));
    // Android won't ask again: only its settings page can turn them on.
    final blocked = _permission == AlertPermission.permanentlyDenied;

    Widget heading(String text) => Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        BrandSpacing.s5,
        BrandSpacing.s6,
        BrandSpacing.s5,
        BrandSpacing.s2,
      ),
      child: Semantics(
        header: true,
        child: Text(text, style: theme.textTheme.titleMedium),
      ),
    );

    Widget topic(
      String title, {
      required bool value,
      required AlertPrefs Function({required bool on}) next,
    }) => SwitchListTile(
      title: Text(title),
      value: value,
      onChanged: (on) => _save(next(on: on)),
    );

    return ListView(
      children: [
        SwitchListTile(
          title: Text(l10n.notifPush),
          subtitle: Text(l10n.notifPushHint),
          value: prefs.pushEnabled,
          onChanged: (on) => _setPush(prefs, on: on),
        ),
        if (blocked)
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: BrandSpacing.s5,
            ),
            child: Semantics(
              liveRegion: true,
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: BrandSpacing.s3,
                children: [
                  Text(l10n.notifBlocked),
                  TextButton(
                    onPressed: () async {
                      await ref
                          .read(notificationPermissionProvider)
                          .openSettings();
                      await _checkPermission();
                    },
                    child: Text(l10n.actionOpenSettings),
                  ),
                ],
              ),
            ),
          ),
        heading(l10n.notifTopics),
        topic(
          l10n.topicBrands,
          value: prefs.followedBrands,
          next: ({required on}) => _with(prefs, followedBrands: on),
        ),
        topic(
          l10n.topicCategories,
          value: prefs.followedCategories,
          next: ({required on}) => _with(prefs, followedCategories: on),
        ),
        topic(
          l10n.topicCards,
          value: prefs.myCards,
          next: ({required on}) => _with(prefs, myCards: on),
        ),
        topic(
          l10n.topicCity,
          value: prefs.myCity,
          next: ({required on}) => _with(prefs, myCity: on),
        ),
        topic(
          l10n.topicPriceDrops,
          value: prefs.savedPriceDrops,
          next: ({required on}) => _with(prefs, savedPriceDrops: on),
        ),
        topic(
          l10n.topicExpiring,
          value: prefs.savedExpiring,
          next: ({required on}) => _with(prefs, savedExpiring: on),
        ),
        heading(l10n.notifFrequency),
        RadioGroup<AlertFrequency>(
          groupValue: prefs.frequency,
          onChanged: (f) {
            if (f != null) unawaited(_save(_with(prefs, frequency: f)));
          },
          child: Column(
            children: [
              for (final (f, label) in [
                (AlertFrequency.low, l10n.freqLow),
                (AlertFrequency.normal, l10n.freqNormal),
                (AlertFrequency.high, l10n.freqHigh),
              ])
                RadioListTile<AlertFrequency>(value: f, title: Text(label)),
            ],
          ),
        ),
        heading(l10n.notifQuiet),
        ListTile(
          leading: const Icon(Icons.bedtime_outlined),
          title: Text(l10n.quietFrom(time(prefs.quietStart))),
          onTap: () => _pickTime(prefs, start: true),
        ),
        ListTile(
          leading: const Icon(Icons.wb_sunny_outlined),
          title: Text(l10n.quietTo(time(prefs.quietEnd))),
          onTap: () => _pickTime(prefs, start: false),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            BrandSpacing.s5,
            0,
            BrandSpacing.s5,
            BrandSpacing.s8,
          ),
          child: Text(
            l10n.quietHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

AlertPrefs _with(
  AlertPrefs p, {
  bool? pushEnabled,
  AlertFrequency? frequency,
  ({int hour, int minute})? quietStart,
  ({int hour, int minute})? quietEnd,
  bool? followedBrands,
  bool? followedCategories,
  bool? myCards,
  bool? myCity,
  bool? savedPriceDrops,
  bool? savedExpiring,
}) => AlertPrefs(
  pushEnabled: pushEnabled ?? p.pushEnabled,
  frequency: frequency ?? p.frequency,
  quietStart: quietStart ?? p.quietStart,
  quietEnd: quietEnd ?? p.quietEnd,
  timeZone: p.timeZone,
  followedBrands: followedBrands ?? p.followedBrands,
  followedCategories: followedCategories ?? p.followedCategories,
  myCards: myCards ?? p.myCards,
  myCity: myCity ?? p.myCity,
  savedPriceDrops: savedPriceDrops ?? p.savedPriceDrops,
  savedExpiring: savedExpiring ?? p.savedExpiring,
);
