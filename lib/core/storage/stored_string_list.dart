import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sale_lagi_hai/core/core_providers.dart';

/// One change to a [StoredStringList]: the new list from the current one.
typedef ListChange = List<String> Function(List<String> current);

/// A list of strings kept on the phone under [storageKey] (saved deals,
/// recent searches, my cards), as a Notifier.
///
/// - Changes show at once. One made while the stored copy is still being
///   read is replayed onto it once read, so nothing saved earlier is lost
///   (QA 4.4 BUG-2).
/// - If the stored copy can't be read (a storage error), the next change
///   tries again; until a read works, changes stay in memory and the stored
///   copy is never overwritten, as with preferences (QA 4.1 BUG-1). A
///   corrupt copy reads as empty and may be replaced.
/// - Logs carry only the error's type: a FormatException's text quotes the
///   file.
///
/// Subclasses that must start fresh after an account is deleted watch
/// `onboardedProvider` in their `build` before calling `super.build()`
/// (QA 4.4 BUG-3).
abstract class StoredStringList extends Notifier<List<String>> {
  String get storageKey;

  /// At most this many entries are kept.
  int get limit;

  /// For logs: "saved deals", "recent searches".
  String get what;

  /// A stored entry as kept when read, or `null` to drop it.
  String? decode(String value) => value.isEmpty ? null : value;

  /// Changes made before the stored copy was read; `null` once read.
  List<ListChange>? _pending;

  /// Whether the stored copy was read (and may be written).
  bool _readable = false;

  /// Changes made while the stored copy couldn't be read, replayed onto it
  /// once a read works (QA 4.4 R2-2).
  final _unwritten = <ListChange>[];

  /// Bumped on every build, so a read from before a rebuild is ignored.
  int _generation = 0;

  Completer<void> _loaded = Completer();

  /// Completes once the stored copy was read (or found unreadable), so a
  /// reader such as the guest sync sees what is stored (QA 4.7-A6).
  Future<void> get loaded => _loaded.future;

  @override
  List<String> build() {
    final generation = ++_generation;
    if (_loaded.isCompleted) _loaded = Completer();
    _pending = [];
    _readable = false;
    _unwritten.clear();
    unawaited(_first(generation));
    return const [];
  }

  Future<void> _first(int generation) async {
    final stored = await _read();
    final loaded = _loaded;
    if (!ref.mounted || generation != _generation) {
      // Gone, or rebuilt: no one waits on this read (a rebuild has its own).
      if (!ref.mounted && !loaded.isCompleted) loaded.complete();
      return;
    }
    try {
      await _settle(stored);
    } finally {
      if (!loaded.isCompleted) loaded.complete();
    }
  }

  Future<void> _settle(List<String>? stored) async {
    final pending = _pending ?? const <ListChange>[];
    _pending = null;
    if (stored == null) {
      // Unreadable: keep what is in memory, and the changes to replay.
      _unwritten.addAll(pending);
      return;
    }
    _readable = true;
    if (pending.isEmpty) {
      state = stored;
      return;
    }
    state = _apply(pending, stored);
    await _write(state);
  }

  /// The stored copy, `[]` when there is none or it is corrupt, or `null`
  /// when it couldn't be read.
  Future<List<String>?> _read() async {
    final String? raw;
    try {
      raw = await ref.read(keyValueStoreProvider).getString(storageKey);
    } on Object catch (error) {
      if (ref.mounted) _warn('Could not read $what', error);
      return null;
    }
    if (raw == null) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return [
        for (final value in decoded)
          if (value is String) ?decode(value),
      ].take(limit).toList();
    } on Object catch (error) {
      if (ref.mounted) _warn('Dropping unreadable $what', error);
      return const [];
    }
  }

  List<String> _apply(List<ListChange> changes, List<String> from) =>
      changes.fold(from, (list, change) => change(list)).take(limit).toList();

  /// Applies [change] now and stores the result: after the first read if
  /// it is still running, after a successful re-read if it failed. Returns
  /// the new list, or `null` if the provider went away.
  Future<List<String>?> update(ListChange change) async {
    final generation = _generation;
    state = _apply([change], state);
    if (_pending case final pending?) {
      pending.add(change);
      return state;
    }
    if (!_readable) {
      _unwritten.add(change);
      final stored = await _read();
      if (!ref.mounted || generation != _generation) return null;
      if (stored == null) return state;
      _readable = true;
      state = _apply(_unwritten, stored);
      _unwritten.clear();
    }
    await _write(state);
    return ref.mounted ? state : null;
  }

  /// Empties the list and removes its stored copy (signing out: nothing of
  /// the account is left behind, not even an empty file).
  Future<void> forget() async {
    if (state.isNotEmpty || _pending != null) await update((_) => const []);
    if (!ref.mounted) return;
    try {
      await ref.read(keyValueStoreProvider).remove(storageKey);
    } on Object catch (error) {
      if (ref.mounted) _warn('Could not remove $what', error);
    }
  }

  Future<void> _write(List<String> list) async {
    try {
      await ref
          .read(keyValueStoreProvider)
          .setString(storageKey, jsonEncode(list));
    } on Object catch (error) {
      if (ref.mounted) _warn('Could not save $what', error);
    }
  }

  void _warn(String message, Object error) => ref
      .read(loggerProvider)
      .warning(message, context: {'error': error.runtimeType.toString()});
}
