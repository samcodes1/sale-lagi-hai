import 'package:flutter_test/flutter_test.dart';
import 'package:sale_lagi_hai/core/result/app_failure.dart';
import 'package:sale_lagi_hai/core/result/result.dart';

void main() {
  const offline = OfflineFailure();

  group('Result', () {
    test('Success exposes its value', () {
      const Result<int> result = Success(42);

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, 42);
      expect(result.failureOrNull, isNull);
    });

    test('Failure exposes its failure', () {
      const Result<int> result = Failure(offline);

      expect(result.isSuccess, isFalse);
      expect(result.valueOrNull, isNull);
      expect(result.failureOrNull, same(offline));
    });

    test('map transforms success and passes failure through', () {
      const Result<int> ok = Success(2);
      const Result<int> failed = Failure(offline);

      expect(ok.map((v) => v * 10), const Success(20));
      expect(failed.map((v) => v * 10), const Failure<int>(offline));
    });

    test('fold reduces both cases', () {
      String describe(Result<int> r) => r.fold(
        onSuccess: (v) => 'value $v',
        onFailure: (f) => 'failed ${f.code}',
      );

      expect(describe(const Success(1)), 'value 1');
      expect(describe(const Failure(offline)), 'failed offline');
    });

    test('supports exhaustive switch', () {
      String handle(Result<String> r) => switch (r) {
        Success(:final value) => value,
        Failure(:final failure) => failure.code,
      };

      expect(handle(const Success('ok')), 'ok');
      expect(handle(const Failure(NotFoundFailure())), 'not_found');
    });

    test('equality and hashCode follow the contents', () {
      expect(const Success(1), const Success(1));
      expect(const Success(1).hashCode, const Success(1).hashCode);
      expect(const Success(1), isNot(const Success(2)));
      expect(const Failure<int>(offline), const Failure<int>(offline));
      expect(const Failure<int>(offline).hashCode, offline.hashCode);
    });

    test('toString describes the case', () {
      expect(const Success(1).toString(), 'Success(1)');
      expect(
        const Failure<int>(offline).toString(),
        'Failure(AppFailure(offline))',
      );
    });
  });
}
