import 'dart:io';

/// Fails when line coverage in an lcov file is below a threshold.
/// Generated code is excluded.
///
/// Usage: dart run tool/check_coverage.dart [lcov file] [--min <percent>]
void main(List<String> args) {
  final path = args.firstWhere(
    (a) => !a.startsWith('--') && !_isNumber(a),
    orElse: () => 'coverage/lcov.info',
  );
  final minIndex = args.indexOf('--min');
  final min = minIndex >= 0 && minIndex + 1 < args.length
      ? double.parse(args[minIndex + 1])
      : 80.0;

  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('$path not found. Run: flutter test --coverage');
    exit(1);
  }

  var found = 0;
  var hit = 0;
  var skip = false;
  for (final line in file.readAsLinesSync()) {
    if (line.startsWith('SF:')) {
      final source = line.substring(3);
      skip =
          source.endsWith('.g.dart') ||
          source.endsWith('.freezed.dart') ||
          source.contains('/l10n/gen/');
    } else if (!skip && line.startsWith('LF:')) {
      found += int.parse(line.substring(3));
    } else if (!skip && line.startsWith('LH:')) {
      hit += int.parse(line.substring(3));
    }
  }

  final percent = found == 0 ? 100.0 : hit * 100 / found;
  final summary =
      'Line coverage: ${percent.toStringAsFixed(1)}% ($hit/$found), '
      'minimum ${min.toStringAsFixed(1)}%.';
  if (percent < min) {
    stderr.writeln(summary);
    exit(1);
  }
  stdout.writeln(summary);
}

bool _isNumber(String value) => double.tryParse(value) != null;
