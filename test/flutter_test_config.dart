import 'dart:async';
import 'dart:io';

import 'package:alchemist/alchemist.dart';

/// Applies to every test file under test/.
///
/// Golden tests write two sets:
/// - `goldens/ci/`: text drawn as blocks, stable on any OS. CI compares
///   these.
/// - `goldens/linux/`: real fonts, for reviewing typography by eye (Nastaliq
///   clipping only shows here). Generated and compared only locally on
///   Linux: font rasterization can differ by a few pixels between machines,
///   so CI (which sets `CI=true`) skips them.
Future<void> testExecutable(FutureOr<void> Function() testMain) =>
    AlchemistConfig.runWithConfig(
      config: AlchemistConfig(
        platformGoldensConfig: PlatformGoldensConfig(
          enabled: Platform.environment['CI'] != 'true',
          platforms: {HostPlatform.linux},
        ),
      ),
      run: () async {
        await testMain();
      },
    );
