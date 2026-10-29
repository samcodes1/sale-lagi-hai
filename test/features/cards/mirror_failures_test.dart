import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sale_lagi_hai/core/backend/backend_gateway.dart';
import 'package:sale_lagi_hai/core/backend/backend_setup.dart';
import 'package:sale_lagi_hai/core/backend/demo/demo_data.dart';
import 'package:sale_lagi_hai/core/backend/demo/demo_gateway.dart';
import 'package:sale_lagi_hai/core/core_providers.dart';
import 'package:sale_lagi_hai/core/logging/app_logger.dart';
import 'package:sale_lagi_hai/core/logging/log_sinks.dart';
import 'package:sale_lagi_hai/core/result/app_failure.dart';
import 'package:sale_lagi_hai/core/storage/key_value_store.dart';
import 'package:sale_lagi_hai/features/auth/application/auth_providers.dart';
import 'package:sale_lagi_hai/features/auth/data/demo_auth_repository.dart';
import 'package:sale_lagi_hai/features/cards/application/my_cards_providers.dart';
import 'package:sale_lagi_hai/features/follows/application/follow_providers.dart';
import 'package:sale_lagi_hai/features/saved/application/saved_providers.dart';

import '../../helpers/fakes.dart';

/// The demo backend, with every write to the account failing (offline).
final class _WritesFail implements BackendGateway {
  final _demo = DemoGateway();

  @override
  Future<List<Map<String, Object?>>> select(TableQuery query) =>
      _demo.select(query);

  @override
  Future<List<Map<String, Object?>>> rpc(
    String function, [
    Map<String, Object?> params = const {},
  ]) => _demo.rpc(function, params);

  @override
  Future<void> insert(String table, Map<String, Object?> row) async =>
      throw const OfflineFailure();

  @override
  Future<void> delete(String table, Map<String, Object?> match) async =>
      throw const OfflineFailure();
}

void main() {
  late InMemoryKeyValueStore store;
  late MemoryLogSink logs;
  late DemoAuthRepository auth;

  Future<ProviderContainer> signedIn() async {
    await auth.sendPhoneCode('+923001234567');
    await auth.verifyPhoneCode('+923001234567', DemoAuthRepository.code);
    final c = ProviderContainer(
      overrides: [
        keyValueStoreProvider.overrideWithValue(store),
        loggerProvider.overrideWithValue(AppLogger(sinks: [logs])),
        backendGatewayProvider.overrideWithValue(_WritesFail()),
        authRepositoryProvider.overrideWithValue(auth),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    store = InMemoryKeyValueStore();
    logs = MemoryLogSink();
    auth = DemoAuthRepository();
  });

  Iterable<String> warnings() => logs.records.map((r) => r.message);

  test('a failed card mirror keeps the phone copy and logs only the kind '
      'of error', () async {
    final c = await signedIn();
    final card = demoCardProducts.first['id']! as String;
    expect(await c.read(myCardsProvider.notifier).add(card), isTrue);
    await c.read(myCardsProvider.notifier).remove(card);
    expect(
      warnings().where((m) => m == 'Could not sync my cards'),
      hasLength(2),
    );
    expect(
      logs.records.map((r) => r.context.toString()),
      everyElement(isNot(contains(card))),
    );
  });

  test('a failed save mirror keeps the phone copy', () async {
    final c = await signedIn();
    final deal = demoDeals.first.id;
    await c.read(savedDealsProvider.notifier).toggle(deal);
    expect(c.read(savedDealsProvider), [deal]);
    await c.read(savedDealsProvider.notifier).toggle(deal);
    expect(c.read(savedDealsProvider), isEmpty);
    expect(
      warnings().where((m) => m == 'Could not sync a saved deal'),
      hasLength(2),
    );
  });

  test('a failed follow mirror keeps the phone copy', () async {
    final c = await signedIn();
    final brand = demoBrands.first['id']! as String;
    await c.read(followsProvider).toggleBrand(brand);
    expect(c.read(followsProvider).followsBrand(brand), isTrue);
    await c.read(followsProvider).toggleBrand(brand);
    expect(
      warnings().where((m) => m == 'Could not sync a follow'),
      hasLength(2),
    );
  });

  test('a card list that could not be read is not overwritten; the next '
      'change reads it again', () async {
    store.values[myCardsKey] = '["kept"]';
    final flaky = _FailingReads(store, failures: 2);
    final c = ProviderContainer(
      overrides: [
        keyValueStoreProvider.overrideWithValue(flaky),
        loggerProvider.overrideWithValue(AppLogger(sinks: [logs])),
        backendGatewayProvider.overrideWithValue(DemoGateway()),
        authRepositoryProvider.overrideWithValue(auth),
      ],
    );
    addTearDown(c.dispose);
    c.read(myCardsProvider);
    await Future<void>.delayed(Duration.zero);
    // First read and the re-read both fail: in memory only.
    await c.read(myCardsProvider.notifier).add('new');
    expect(c.read(myCardsProvider), ['new']);
    expect(store.values[myCardsKey], '["kept"]');
    // The third read works: merged and written.
    await c.read(myCardsProvider.notifier).add('newer');
    expect(c.read(myCardsProvider), ['kept', 'newer']);
    expect(store.values[myCardsKey], '["kept","newer"]');
  });
}

/// A store whose first `failures` reads throw.
final class _FailingReads implements KeyValueStore {
  new(this._inner, {required int failures}) : _left = failures;

  final InMemoryKeyValueStore _inner;
  int _left;

  @override
  Future<String?> getString(String key) async {
    if (_left-- > 0) throw StateError('disk busy');
    return await _inner.getString(key);
  }

  @override
  Future<void> setString(String key, String value) =>
      _inner.setString(key, value);

  @override
  Future<void> remove(String key) => _inner.remove(key);

  @override
  Future<Set<String>> keys() => _inner.keys();

  @override
  Future<void> clear() => _inner.clear();
}
