import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The current time. Widgets that show relative times ("Ends in 2 days")
/// read it here so tests can fix the clock.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
