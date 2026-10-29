import 'package:flutter_test/flutter_test.dart';
import 'package:sale_lagi_hai/app/config/flavor.dart';

void main() {
  group('Flavor.tryParse', () {
    test('parses every flavor by name', () {
      for (final flavor in Flavor.values) {
        expect(Flavor.tryParse(flavor.name), flavor);
      }
    });

    test('returns null for unknown or differently-cased names', () {
      expect(Flavor.tryParse(''), isNull);
      expect(Flavor.tryParse('PROD'), isNull);
      expect(Flavor.tryParse('production'), isNull);
    });
  });

  test('only prod is production', () {
    expect(Flavor.prod.isProduction, isTrue);
    expect(Flavor.staging.isProduction, isFalse);
    expect(Flavor.dev.isProduction, isFalse);
  });
}
