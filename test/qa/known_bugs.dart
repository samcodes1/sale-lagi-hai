/// Tests for open QA bugs assert the **expected** behaviour and are skipped by
/// default, so the suite stays green while the bug is open.
///
/// To see them fail (and, once a bug is fixed, pass), run:
/// `flutter test test/qa --dart-define=QA_KNOWN_BUGS=true`
///
/// When you fix a bug, delete its `skip: knownBug(...)` so the test guards
/// against regressions.
const _runKnownBugs = bool.fromEnvironment('QA_KNOWN_BUGS');

/// The `skip:` value for a test that documents open bug [id], e.g.
/// `knownBug('1.2 BUG-1')`.
Object knownBug(String id) => _runKnownBugs
    ? false
    : 'Open QA $id (run with --dart-define=QA_KNOWN_BUGS=true)';
