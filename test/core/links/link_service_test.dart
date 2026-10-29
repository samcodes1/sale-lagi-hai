import 'package:flutter_test/flutter_test.dart';
import 'package:sale_lagi_hai/core/links/link_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('only absolute https URLs with a host open', () {
    expect(
      UrlLauncherLinkService.safeWebUri('https://brand.pk/sale'),
      isNotNull,
    );
    for (final bad in [
      'http://brand.pk',
      'javascript:alert(1)',
      'intent://scan#Intent;scheme=zxing;end',
      'file:///etc/passwd',
      'https://',
      '//brand.pk',
      'https://user:pass@brand.pk',
      'tel:+923001234567',
    ]) {
      expect(UrlLauncherLinkService.safeWebUri(bad), isNull, reason: bad);
    }
  });

  test('maps and WhatsApp use fixed https endpoints', () {
    final map = UrlLauncherLinkService.mapUri(24.815, 67.031);
    expect(map.host, 'www.google.com');
    expect(map.queryParameters['query'], '24.815,67.031');
    final wa = UrlLauncherLinkService.whatsAppUri('Khaadi: 40% off & more');
    expect(wa.host, 'wa.me');
    expect(wa.queryParameters['text'], 'Khaadi: 40% off & more');
  });

  test('without a plugin, nothing opens and nothing throws', () async {
    const links = UrlLauncherLinkService();
    expect(await links.openWeb('https://brand.pk'), isFalse);
    expect(await links.openWeb('http://brand.pk'), isFalse);
    expect(await links.call('+923001234567'), isFalse);
    expect(await links.call('0300 1234567; rm'), isFalse);
  });
}
