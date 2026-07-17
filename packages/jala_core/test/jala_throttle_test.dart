import 'dart:math';

import 'package:jala_core/jala_core.dart';
import 'package:test/test.dart';

void main() {
  group('JalaThrottleProfile presets', () {
    test('slow3g', () {
      const p = JalaThrottleProfile.slow3g;
      expect(p.id, 'slow3g');
      expect(p.latencyMs, 400);
      expect(p.jitterMs, 100);
      expect(p.downloadBytesPerSec, 50 * 1024);
      expect(p.uploadBytesPerSec, 25 * 1024);
      expect(p.dropRate, 0);
    });

    test('fast3g', () {
      const p = JalaThrottleProfile.fast3g;
      expect(p.id, 'fast3g');
      expect(p.latencyMs, 150);
      expect(p.jitterMs, 50);
      expect(p.downloadBytesPerSec, 180 * 1024);
      expect(p.uploadBytesPerSec, isNull);
      expect(p.dropRate, 0);
    });

    test('flaky', () {
      const p = JalaThrottleProfile.flaky;
      expect(p.id, 'flaky');
      expect(p.latencyMs, 200);
      expect(p.jitterMs, 200);
      expect(p.downloadBytesPerSec, isNull);
      expect(p.uploadBytesPerSec, isNull);
      expect(p.dropRate, 0.15);
    });

    test('offline', () {
      const p = JalaThrottleProfile.offline;
      expect(p.id, 'offline');
      expect(p.dropRate, 1);
    });

    test('presets list has all four in order', () {
      expect(JalaThrottleProfile.presets.map((p) => p.id), [
        'slow3g',
        'fast3g',
        'flaky',
        'offline',
      ]);
    });

    test('value equality', () {
      expect(JalaThrottleProfile.slow3g, JalaThrottleProfile.slow3g);
      expect(
        const JalaThrottleProfile(id: 'x', name: 'X', latencyMs: 1),
        const JalaThrottleProfile(id: 'x', name: 'X', latencyMs: 1),
      );
    });
  });

  group('JalaThrottleRegistry', () {
    late JalaThrottleRegistry registry;

    tearDown(() async {
      await registry.dispose();
    });

    test('off by default', () {
      registry = JalaThrottleRegistry();
      expect(registry.activeProfile, isNull);
      expect(registry.hostPattern, isNull);
    });

    test('setActive activates a profile and hostPattern', () {
      registry = JalaThrottleRegistry();
      registry.setActive(JalaThrottleProfile.slow3g, hostPattern: '*.api.dev');
      expect(registry.activeProfile, JalaThrottleProfile.slow3g);
      expect(registry.hostPattern, '*.api.dev');
    });

    test('clear deactivates', () {
      registry = JalaThrottleRegistry();
      registry.setActive(JalaThrottleProfile.flaky);
      registry.clear();
      expect(registry.activeProfile, isNull);
      expect(registry.hostPattern, isNull);
    });

    group('watch', () {
      test('replays current value on listen', () async {
        registry = JalaThrottleRegistry();
        registry.setActive(JalaThrottleProfile.fast3g);

        final first = await registry.watch.first;
        expect(first, JalaThrottleProfile.fast3g);
      });

      test('emits null initially when off', () async {
        registry = JalaThrottleRegistry();
        final first = await registry.watch.first;
        expect(first, isNull);
      });

      test('emits on every setActive/clear, multiple listeners', () async {
        registry = JalaThrottleRegistry();
        final a = <JalaThrottleProfile?>[];
        final b = <JalaThrottleProfile?>[];
        final subA = registry.watch.listen(a.add);
        final subB = registry.watch.listen(b.add);

        registry.setActive(JalaThrottleProfile.slow3g);
        registry.clear();
        await Future<void>.delayed(Duration.zero);
        await subA.cancel();
        await subB.cancel();

        expect(a, [isNull, JalaThrottleProfile.slow3g, isNull]);
        expect(b, [isNull, JalaThrottleProfile.slow3g, isNull]);
      });
    });

    group('disabled binding reports off', () {
      test('activeProfile/hostPattern report null while disabled', () {
        registry = JalaThrottleRegistry(isEnabled: () => false);
        registry.setActive(
          JalaThrottleProfile.offline,
          hostPattern: '*.api.dev',
        );
        expect(registry.activeProfile, isNull);
        expect(registry.hostPattern, isNull);
      });

      test('shouldDrop is always false while disabled', () {
        registry = JalaThrottleRegistry(isEnabled: () => false);
        registry.setActive(JalaThrottleProfile.offline); // dropRate 1.0
        expect(registry.shouldDrop(), isFalse);
      });

      test('latencyFor is zero while disabled', () {
        registry = JalaThrottleRegistry(isEnabled: () => false);
        registry.setActive(JalaThrottleProfile.slow3g);
        expect(registry.latencyFor(), Duration.zero);
      });

      test('paceFor is zero while disabled', () {
        registry = JalaThrottleRegistry(isEnabled: () => false);
        registry.setActive(JalaThrottleProfile.slow3g);
        expect(registry.paceFor(1000, 100), Duration.zero);
      });
    });

    group('shouldDrop', () {
      test('dropRate 0 never drops regardless of random', () {
        registry = JalaThrottleRegistry(random: Random(1));
        registry.setActive(
          const JalaThrottleProfile(id: 'x', name: 'X', latencyMs: 0),
        );
        for (var i = 0; i < 50; i++) {
          expect(registry.shouldDrop(), isFalse);
        }
      });

      test('dropRate 1 always drops regardless of random', () {
        registry = JalaThrottleRegistry(random: Random(1));
        registry.setActive(JalaThrottleProfile.offline);
        for (var i = 0; i < 50; i++) {
          expect(registry.shouldDrop(), isTrue);
        }
      });

      test('mid-range dropRate is deterministic with a seeded Random', () async {
        final r1 = JalaThrottleRegistry(random: Random(42));
        r1.setActive(JalaThrottleProfile.flaky); // dropRate 0.15
        final seq1 = [for (var i = 0; i < 20; i++) r1.shouldDrop()];

        final r2 = JalaThrottleRegistry(random: Random(42));
        r2.setActive(JalaThrottleProfile.flaky);
        final seq2 = [for (var i = 0; i < 20; i++) r2.shouldDrop()];

        expect(seq1, seq2);
        registry = r1;
        await r2.dispose();
      });

      test('no active profile never drops', () {
        registry = JalaThrottleRegistry();
        expect(registry.shouldDrop(), isFalse);
      });
    });

    group('latencyFor', () {
      test('no jitter returns exactly latencyMs', () {
        registry = JalaThrottleRegistry();
        registry.setActive(JalaThrottleProfile.offline); // latencyMs 0
        expect(registry.latencyFor(), Duration.zero);
      });

      test('jitter stays within bounds and is never negative', () {
        registry = JalaThrottleRegistry(random: Random(7));
        registry.setActive(JalaThrottleProfile.slow3g); // 400ms +/-100
        for (var i = 0; i < 100; i++) {
          final d = registry.latencyFor();
          expect(d.inMilliseconds, greaterThanOrEqualTo(300));
          expect(d.inMilliseconds, lessThanOrEqualTo(500));
        }
      });

      test('jitter never goes negative even when latencyMs < jitterMs', () {
        registry = JalaThrottleRegistry(random: Random(3));
        registry.setActive(
          const JalaThrottleProfile(
            id: 'x',
            name: 'X',
            latencyMs: 5,
            jitterMs: 50,
          ),
        );
        for (var i = 0; i < 100; i++) {
          expect(registry.latencyFor().inMilliseconds, greaterThanOrEqualTo(0));
        }
      });

      test('no active profile returns zero', () {
        registry = JalaThrottleRegistry();
        expect(registry.latencyFor(), Duration.zero);
      });
    });

    group('paceFor', () {
      test('null perSec is zero', () {
        registry = JalaThrottleRegistry();
        expect(registry.paceFor(10000, null), Duration.zero);
      });

      test('non-positive perSec/bytes is zero', () {
        registry = JalaThrottleRegistry();
        expect(registry.paceFor(0, 100), Duration.zero);
        expect(registry.paceFor(100, 0), Duration.zero);
        expect(registry.paceFor(100, -1), Duration.zero);
      });

      test('computes proportional delay', () {
        registry = JalaThrottleRegistry();
        // 1000 bytes at 100 bytes/sec = 10 seconds.
        expect(registry.paceFor(1000, 100), const Duration(seconds: 10));
      });

      test('sub-second math uses microsecond precision', () {
        registry = JalaThrottleRegistry();
        // 512 bytes at 1024 bytes/sec = 0.5 sec.
        expect(
          registry.paceFor(512, 1024),
          const Duration(milliseconds: 500),
        );
      });
    });

    group('hostMatches', () {
      test('null pattern matches every host', () {
        registry = JalaThrottleRegistry();
        registry.setActive(JalaThrottleProfile.slow3g);
        expect(registry.hostMatches('api.example.com'), isTrue);
        expect(registry.hostMatches('anything.dev'), isTrue);
      });

      test('glob pattern matches case-insensitively', () {
        registry = JalaThrottleRegistry();
        registry.setActive(
          JalaThrottleProfile.slow3g,
          hostPattern: '*.EXAMPLE.com',
        );
        expect(registry.hostMatches('api.example.com'), isTrue);
        expect(registry.hostMatches('example.com'), isFalse);
        expect(registry.hostMatches('other.dev'), isFalse);
      });

      test('exact pattern (no wildcard) matches only that host', () {
        registry = JalaThrottleRegistry();
        registry.setActive(
          JalaThrottleProfile.slow3g,
          hostPattern: 'api.example.com',
        );
        expect(registry.hostMatches('api.example.com'), isTrue);
        expect(registry.hostMatches('sub.api.example.com'), isFalse);
      });
    });
  });
}
