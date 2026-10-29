import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sale_lagi_hai/core/l10n/l10n.dart';
import 'package:sale_lagi_hai/features/follows/application/follow_providers.dart';
import 'package:sale_lagi_hai/features/onboarding/application/preferences_controller.dart';

enum FollowTarget { brand, category }

/// Follow / Following for a brand or a category, with a note each way.
/// Reads as a toggle: "Follow Khaadi, on/off".
class FollowButton extends ConsumerWidget {
  const new({
    required this.target,
    required this.id,
    required this.name,
    super.key,
  });

  final FollowTarget target;
  final String id;
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final following = ref.watch(
      preferencesProvider.select(
        (p) => (target == FollowTarget.brand ? p.brandIds : p.categoryFollowIds)
            .contains(id),
      ),
    );
    Future<void> toggle() async {
      final messenger = ScaffoldMessenger.maybeOf(context);
      final follows = ref.read(followsProvider);
      await (target == FollowTarget.brand
          ? follows.toggleBrand(id)
          : follows.toggleCategory(id));
      // The state after the tap, not before: two quick taps must not say
      // "Following" when the second one unfollowed (QA 4.5 BUG-5).
      final preferences = ref.read(preferencesProvider);
      final now =
          (target == FollowTarget.brand
                  ? preferences.brandIds
                  : preferences.categoryFollowIds)
              .contains(id);
      messenger
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              now ? l10n.followedToast(name) : l10n.unfollowedToast(name),
            ),
          ),
        );
    }

    final label = Text(following ? l10n.actionFollowing : l10n.actionFollow);
    return Semantics(
      // Its own node: with the button's excluded, it would merge
      // into whatever is around it.
      container: true,
      toggled: following,
      label: l10n.followLabel(name),
      excludeSemantics: true,
      button: true,
      onTap: toggle,
      child: following
          ? FilledButton.tonalIcon(
              onPressed: toggle,
              icon: const Icon(Icons.check),
              label: label,
            )
          : OutlinedButton.icon(
              onPressed: toggle,
              icon: const Icon(Icons.add),
              label: label,
            ),
    );
  }
}
