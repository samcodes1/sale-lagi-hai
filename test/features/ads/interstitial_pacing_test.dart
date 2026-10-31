import 'package:flutter_test/flutter_test.dart';
import 'package:sale_lagi_hai/features/ads/application/ad_service.dart';
import 'package:sale_lagi_hai/features/ads/application/ads_providers.dart';
import 'package:sale_lagi_hai/features/ads/domain/interstitial_pacing.dart';

final class _Service extends NoAdService {
  const new({this.enabled = true, this.ready = true});

  @override
  final bool enabled;

  final bool ready;

  static var shows = 0;

  @override
  Future<bool> showInterstitial() async {
    shows++;
    return ready;
  }
}

void main() {
  var now = DateTime.utc(2026, 10, 31, 12);
  InterstitialPacing pacing() => InterstitialPacing(clock: () => now);

  setUp(() {
    now = DateTime.utc(2026, 10, 31, 12);
    _Service.shows = 0;
  });

  void wait(Duration time) => now = now.add(time);

  test('never in the first minutes of a session', () {
    final subject = pacing();
    expect([for (var i = 0; i < 5; i++) subject.onBreak()], everyElement(false));
  });

  test('on every third break once the wait is over', () {
    final subject = pacing();
    wait(const Duration(minutes: 2));
    expect(subject.onBreak(), isFalse);
    expect(subject.onBreak(), isFalse);
    expect(subject.onBreak(), isTrue);
  });

  test('showing one starts the wait again', () {
    final subject = pacing()..markShown();
    wait(const Duration(minutes: 1, seconds: 59));
    for (var i = 0; i < 3; i++) {
      expect(subject.onBreak(), isFalse);
    }
    wait(const Duration(seconds: 1));
    expect(subject.onBreak(), isTrue);
  });

  test('a break keeps counting while no ad was ready', () {
    final subject = pacing();
    wait(const Duration(minutes: 5));
    for (var i = 0; i < 3; i++) {
      subject.onBreak();
    }
    expect(subject.onBreak(), isTrue);
  });

  test('stops at the session limit', () {
    final subject = pacing();
    for (var i = 0; i < subject.maxPerSession; i++) {
      wait(subject.minGap);
      for (var b = 0; b < subject.breaksPerAd; b++) {
        subject.onBreak();
      }
      subject.markShown();
    }
    wait(const Duration(hours: 1));
    for (var b = 0; b < subject.breaksPerAd; b++) {
      expect(subject.onBreak(), isFalse);
    }
  });

  group('Interstitials', () {
    test('shows when the pacing allows, and counts only a real show', () async {
      final subject = pacing();
      wait(const Duration(minutes: 5));
      final ads = Interstitials(const _Service(ready: false), subject);
      for (var i = 0; i < 3; i++) {
        ads.onBreak();
      }
      await pumpEventQueue();
      expect(_Service.shows, 1);
      // Nothing showed, so the next break may try again.
      ads.onBreak();
      await pumpEventQueue();
      expect(_Service.shows, 2);
    });

    test('does nothing in a build without ads', () async {
      final subject = pacing();
      wait(const Duration(minutes: 5));
      final ads = Interstitials(const _Service(enabled: false), subject);
      for (var i = 0; i < 6; i++) {
        ads.onBreak();
      }
      await pumpEventQueue();
      expect(_Service.shows, 0);
    });
  });
}
