import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sale_lagi_hai/core/device/device_providers.dart';
import 'package:sale_lagi_hai/core/device/location_service.dart';
import 'package:sale_lagi_hai/features/catalog/application/catalog_providers.dart';
import 'package:sale_lagi_hai/features/catalog/domain/catalog.dart';
import 'package:sale_lagi_hai/features/onboarding/application/preferences_controller.dart';

/// What [locateCity] found.
typedef CityLocation = ({LocationOutcome outcome, City? city});

/// Asks for the phone's approximate location (the system dialog, if the
/// shopper hasn't answered it yet), matches it to the nearest city on the
/// phone and makes that the shopper's city. Outside every city (or without
/// a location, or offline without the city list) the city is left as it
/// is: All Pakistan until they pick one.
///
/// Play policy (User Data, Location): only ever called from a button the
/// shopper taps under a screen that says what location is for; coarse,
/// foreground only; the coordinates never leave the phone here and are not
/// kept.
Future<CityLocation> locateCity(WidgetRef ref) async {
  LocationOutcome outcome;
  try {
    outcome = await ref.read(locationServiceProvider).approximateLocation();
  } on Object {
    // Never leave a button spinning (QA 4.1 BUG-2).
    outcome = const LocationUnavailable();
  }
  if (outcome is! Located) return (outcome: outcome, city: null);
  final List<City> cities;
  try {
    cities = await ref.read(citiesProvider.future);
  } on Object {
    // Offline before the cities ever loaded: nothing to match against.
    return (outcome: const LocationUnavailable(), city: null);
  }
  final city = nearestCity(cities, outcome.latitude, outcome.longitude);
  if (city != null) {
    await ref.read(preferencesProvider.notifier).setCity(city.id);
  }
  return (outcome: outcome, city: city);
}
