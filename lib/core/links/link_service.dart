import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens things outside the app. Only these kinds, each with a fixed
/// scheme: web pages (https only, in Custom Tabs), maps, WhatsApp and a
/// phone call. Nothing else from deal data is ever launched.
abstract interface class LinkService {
  /// An https page in an in-app browser tab. Anything else is refused.
  Future<bool> openWeb(String url);

  /// Directions to a place, in the phone's maps app.
  Future<bool> openMap(double latitude, double longitude, String label);

  /// WhatsApp's share screen with [text] filled in.
  Future<bool> shareOnWhatsApp(String text);

  /// The dialler with [e164] filled in (never calls by itself).
  Future<bool> call(String e164);
}

final class UrlLauncherLinkService implements LinkService {
  const new();

  static final _e164 = RegExp(r'^\+92[0-9]{9,10}$');

  static Future<bool> _launch(Uri uri, LaunchMode mode) async {
    try {
      return await launchUrl(uri, mode: mode);
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// [url] if it is an absolute https URL with a host, else `null`.
  @visibleForTesting
  static Uri? safeWebUri(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return null;
    if (uri.userInfo.isNotEmpty) return null;
    return uri;
  }

  @override
  Future<bool> openWeb(String url) async {
    final uri = safeWebUri(url);
    if (uri == null) return false;
    return await _launch(uri, LaunchMode.inAppBrowserView);
  }

  /// Google Maps' universal link: opens the Maps app when installed, the
  /// web map otherwise.
  @visibleForTesting
  static Uri mapUri(double latitude, double longitude) => Uri.https(
    'www.google.com',
    '/maps/search/',
    {'api': '1', 'query': '$latitude,$longitude'},
  );

  @override
  Future<bool> openMap(double latitude, double longitude, String label) =>
      _launch(mapUri(latitude, longitude), LaunchMode.externalApplication);

  @visibleForTesting
  static Uri whatsAppUri(String text) =>
      Uri.https('wa.me', '/', {'text': text});

  @override
  Future<bool> shareOnWhatsApp(String text) =>
      _launch(whatsAppUri(text), LaunchMode.externalApplication);

  @override
  Future<bool> call(String e164) async {
    if (!_e164.hasMatch(e164)) return false;
    return await _launch(
      Uri(scheme: 'tel', path: e164),
      LaunchMode.externalApplication,
    );
  }
}
