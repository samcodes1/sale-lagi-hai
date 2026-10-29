import 'dart:io';

import 'package:sale_lagi_hai/app/config/env_file.dart';

/// Validates an env file before it is compiled into a build.
///
/// Usage:
/// ```sh
/// dart run tool/check_env.dart <env file> [--flavor <name>]
///   [--allow-placeholders]
/// ```
void main(List<String> args) {
  String? path;
  String? flavor;
  var allowPlaceholders = false;
  // Strict parsing: an unknown or misspelled flag must fail, never silently
  // skip a check.
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '--flavor' && i + 1 < args.length) {
      flavor = args[++i];
    } else if (arg == '--allow-placeholders') {
      allowPlaceholders = true;
    } else if (!arg.startsWith('-') && path == null) {
      path = arg;
    } else {
      _usage('Unexpected argument: $arg');
    }
  }
  if (path == null) _usage('Missing env file path.');

  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('$path does not exist.');
    exit(1);
  }

  final problems = validateEnvFile(
    file.readAsStringSync(),
    expectedFlavor: flavor,
    allowPlaceholders: allowPlaceholders,
  );
  if (problems.isEmpty) {
    stdout.writeln('$path is valid.');
    return;
  }
  stderr.writeln('$path is invalid:');
  for (final problem in problems) {
    stderr.writeln('- $problem');
  }
  exit(1);
}

Never _usage(String problem) {
  stderr
    ..writeln(problem)
    ..writeln(
      'Usage: dart run tool/check_env.dart <env file> '
      '[--flavor <name>] [--allow-placeholders]',
    );
  exit(64);
}
