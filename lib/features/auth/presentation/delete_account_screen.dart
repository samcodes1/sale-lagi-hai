import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/app/router/routes.dart';
import 'package:sale_lagi_hai/core/core_providers.dart';
import 'package:sale_lagi_hai/core/l10n/failure_messages.dart';
import 'package:sale_lagi_hai/core/l10n/l10n.dart';
import 'package:sale_lagi_hai/core/result/app_failure.dart';
import 'package:sale_lagi_hai/core/result/result.dart';
import 'package:sale_lagi_hai/design_system/tokens/brand_tokens.dart';
import 'package:sale_lagi_hai/features/auth/application/auth_providers.dart';
import 'package:sale_lagi_hai/features/auth/domain/auth_repository.dart';
import 'package:sale_lagi_hai/features/onboarding/application/preferences_controller.dart';

/// Account deletion (UX flow F7, a Play requirement): what goes, what
/// stays, one confirmation, and a fresh sign-in if the last one is old.
/// Afterwards the shopper is signed out and this phone starts fresh.
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  bool _busy = false;
  AppFailure? _failure;

  Future<bool> _confirm() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteConfirmTitle),
        content: Text(l10n.deleteConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.actionCancel),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.actionDeleteForever),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _delete() async {
    if (!await _confirm() || !mounted) return;
    setState(() {
      _busy = true;
      _failure = null;
    });
    final auth = ref.read(authRepositoryProvider);
    var result = await auth.deleteAccount();
    if (result case Success(value: DeletionOutcome.reauthRequired)) {
      if (!mounted) return;
      final again = await const SignInRoute(reauth: true).push<bool>(context);
      if (!mounted) return;
      if (again != true) {
        setState(() => _busy = false);
        return;
      }
      result = await auth.deleteAccount();
    }
    if (!mounted) return;
    switch (result) {
      case Success(value: DeletionOutcome.deleted):
        await _forgetThisPhone();
      case Success(value: DeletionOutcome.reauthRequired):
        setState(() => _busy = false);
      case Failure(:final failure):
        setState(() {
          _busy = false;
          _failure = failure;
        });
    }
  }

  /// Local data goes too: preferences, cached deals. The router then sends
  /// this phone back to onboarding.
  Future<void> _forgetThisPhone() async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final message = context.l10n.deletedToast;
    try {
      await ref.read(keyValueStoreProvider).clear();
    } on Object catch (error) {
      ref
          .read(loggerProvider)
          .warning('Could not clear local data', error: error);
    }
    await ref.read(preferencesProvider.notifier).reset();
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.deleteTitle)),
      body: SafeArea(
        // Not a lazy list: the whole (short) form is built, so focusing a
        // field below the fold at large text sizes works.
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.all(BrandSpacing.s5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.deleteIntro, style: theme.textTheme.bodyLarge),
              const SizedBox(height: BrandSpacing.s7),
              Semantics(
                header: true,
                child: Text(
                  l10n.deleteListTitle,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: BrandSpacing.s3),
              for (final (icon, text) in [
                (Icons.person_outline, l10n.deleteItemProfile),
                (Icons.bookmark_outline, l10n.deleteItemSaves),
                (Icons.notifications_none, l10n.deleteItemAlerts),
                (Icons.photo_outlined, l10n.deleteItemPhotos),
              ])
                Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    vertical: BrandSpacing.s3,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ExcludeSemantics(
                        child: Icon(icon, color: scheme.onSurfaceVariant),
                      ),
                      const SizedBox(width: BrandSpacing.s4),
                      Expanded(
                        child: Text(text, style: theme.textTheme.bodyLarge),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: BrandSpacing.s5),
              Text(
                l10n.deleteKept,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              if (_failure case final failure?) ...[
                const SizedBox(height: BrandSpacing.s5),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    failure.message(l10n),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.error,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: BrandSpacing.s8),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.error,
                  foregroundColor: scheme.onError,
                ),
                onPressed: _busy ? null : _delete,
                child: _busy
                    ? SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: scheme.onError,
                          semanticsLabel: l10n.actionDeleteForever,
                        ),
                      )
                    : Text(l10n.actionDeleteForever),
              ),
              TextButton(
                onPressed: _busy ? null : () => context.pop(),
                child: Text(l10n.actionCancel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
