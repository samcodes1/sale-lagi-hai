import 'package:material_ui/material_ui.dart';

/// Maps a category's Material Symbols name (`categories.icon`) to an icon.
/// Names the app doesn't know yet (added in the admin console after this
/// build) fall back to a generic offer tag.
IconData categoryIcon(String name) =>
    _icons[name] ?? Icons.local_offer_outlined;

const _icons = <String, IconData>{
  'cell_tower': Icons.cell_tower,
  'chair': Icons.chair_outlined,
  'checkroom': Icons.checkroom,
  'child_care': Icons.child_care,
  'confirmation_number': Icons.confirmation_number_outlined,
  'credit_card': Icons.credit_card,
  'fitness_center': Icons.fitness_center,
  'flight': Icons.flight,
  'local_cafe': Icons.local_cafe_outlined,
  'local_offer': Icons.local_offer_outlined,
  'local_pizza': Icons.local_pizza_outlined,
  'lunch_dining': Icons.lunch_dining_outlined,
  'man': Icons.man,
  'movie': Icons.movie_outlined,
  'outdoor_grill': Icons.outdoor_grill_outlined,
  'restaurant': Icons.restaurant,
  'rice_bowl': Icons.rice_bowl_outlined,
  'school': Icons.school_outlined,
  'shopping_cart': Icons.shopping_cart_outlined,
  'smartphone': Icons.smartphone,
  'spa': Icons.spa_outlined,
  'steps': Icons.directions_walk,
  'woman': Icons.woman,
};
