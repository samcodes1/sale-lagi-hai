// QA, sub-phase 4.1: what the plugins' own manifests merge into the app.
// The Android SDK isn't available here, so this emulates the manifest
// merger for the Flutter plugins in pubspec.lock (their manifests in the pub
// cache) against the app manifest's `tools:node="remove"` entries.
// Maven dependencies (play-services-location etc.) aren't covered: check
// `app/build/intermediates/merged_manifests/<flavor>Release` in CI.
//
// Tests marked `skip: knownBug(...)` assert the expected behaviour of an
// open bug (docs/qa/4.1.md).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';
import 'package:yaml/yaml.dart';

const _android = 'http://schemas.android.com/apk/res/android';
const _tools = 'http://schemas.android.com/tools';

String? _attr(XmlElement e, String name, {String ns = _android}) =>
    e.getAttribute(name, namespaceUri: ns);

/// Every plugin manifest (package name → parsed XML) from the pub cache.
Map<String, XmlDocument> _pluginManifests() {
  final cache =
      Platform.environment['PUB_CACHE'] ??
      '${Platform.environment['HOME']}/.pub-cache';
  final lock = loadYaml(File('pubspec.lock').readAsStringSync()) as YamlMap;
  final out = <String, XmlDocument>{};
  for (final MapEntry(key: name, value: info)
      in (lock['packages'] as YamlMap).entries) {
    if ((info as YamlMap)['source'] != 'hosted') continue;
    final file = File(
      '$cache/hosted/pub.dev/$name-${info['version']}'
      '/android/src/main/AndroidManifest.xml',
    );
    if (file.existsSync()) {
      out['$name'] = XmlDocument.parse(file.readAsStringSync());
    }
  }
  return out;
}

void main() {
  final app = XmlDocument.parse(
    File('android/app/src/main/AndroidManifest.xml').readAsStringSync(),
  );
  Set<String> removed(String tag) => {
    for (final e in app.findAllElements(tag))
      if (_attr(e, 'node', ns: _tools) == 'remove') _attr(e, 'name')!,
  };
  final plugins = _pluginManifests();

  test('the plugin manifests were found (pub get has run)', () {
    expect(plugins.keys, containsAll(['geolocator_android']));
  });

  test('merged permissions: only the documented set survives', () {
    final appRequested = {
      for (final e in app.findAllElements('uses-permission'))
        if (_attr(e, 'node', ns: _tools) != 'remove') _attr(e, 'name')!,
    };
    final merged = {
      ...appRequested,
      for (final doc in plugins.values)
        for (final e in doc.findAllElements('uses-permission'))
          if (!removed('uses-permission').contains(_attr(e, 'name')))
            _attr(e, 'name')!,
    };
    // INTERNET, coarse location and notifications are the app's own.
    // ACCESS_NETWORK_STATE comes from connectivity_plus (1.2): a normal,
    // install-time permission that the offline banner needs.
    expect(merged, {
      'android.permission.INTERNET',
      'android.permission.ACCESS_COARSE_LOCATION',
      'android.permission.POST_NOTIFICATIONS',
      'android.permission.ACCESS_NETWORK_STATE',
    });
    expect(merged, isNot(contains('android.permission.ACCESS_FINE_LOCATION')));
    expect(
      merged,
      isNot(contains('android.permission.ACCESS_BACKGROUND_LOCATION')),
    );
  });

  test('no location foreground service is merged in (the app never tracks '
      'location in the background)', () {
    final removedServices = removed('service');
    final fgs = [
      for (final MapEntry(key: plugin, value: doc) in plugins.entries)
        for (final s in doc.findAllElements('service'))
          if (_attr(s, 'foregroundServiceType') != null)
            (plugin, _attr(s, 'name')!, _attr(s, 'foregroundServiceType')!),
    ];
    final kept = [
      for (final (plugin, name, type) in fgs)
        if (!removedServices.any((r) => r.endsWith(name.split('.').last)))
          '$plugin: $name ($type)',
    ];
    expect(kept, isEmpty);
  });
}
