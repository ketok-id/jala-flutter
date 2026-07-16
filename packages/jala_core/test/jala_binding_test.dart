import 'package:jala_core/jala_core.dart';
import 'package:test/test.dart';

import 'test_helpers.dart';

class _RecordingReplayer implements JalaReplayer {
  final List<NetworkCallEntry> replayed = <NetworkCallEntry>[];

  @override
  Future<void> replay(NetworkCallEntry entry) async {
    replayed.add(entry);
  }

  @override
  Future<void> replayModified(
    NetworkCallEntry entry, {
    String? method,
    Uri? uri,
    Map<String, String>? headers,
    String? body,
  }) =>
      replay(entry);
}

void main() {
  tearDown(JalaBinding.resetForTesting);

  group('JalaBinding', () {
    test('is disabled and unwired before initialize', () {
      final binding = JalaBinding.instance;
      expect(binding.isInitialized, isFalse);
      expect(binding.isEnabled, isFalse);
      expect(() => binding.config, throwsStateError);
      expect(() => binding.bus, throwsStateError);
      expect(() => binding.store, throwsStateError);
    });

    test('initialize wires config, bus, and store', () {
      final binding = JalaBinding.instance
        ..initialize(config: JalaConfig(enabled: true, maxEntries: 7));

      expect(binding.isInitialized, isTrue);
      expect(binding.isEnabled, isTrue);
      expect(binding.config.maxEntries, 7);
      expect(binding.store.maxEntries, 7);
      expect(binding.bus, isA<JalaEventBus>());
    });

    test('initialize with no config yields a disabled binding', () {
      final binding = JalaBinding.instance..initialize();
      expect(binding.isInitialized, isTrue);
      expect(binding.isEnabled, isFalse);
    });

    test('initialize is idempotent — first config wins', () {
      final binding = JalaBinding.instance
        ..initialize(config: JalaConfig(enabled: true, maxEntries: 7))
        ..initialize(config: JalaConfig(enabled: false, maxEntries: 99));

      expect(binding.config.maxEntries, 7);
      expect(binding.isEnabled, isTrue);
    });

    test(
      'events emitted on the binding bus land in the binding store',
      () async {
        final binding = JalaBinding.instance
          ..initialize(config: JalaConfig(enabled: true));

        emitRequest(binding.bus, 'a');
        emitResponse(binding.bus, 'a', statusCode: 204);
        await pump();

        expect(binding.store.byId('a')!.statusCode, 204);
      },
    );

    test('bus drops events while config is disabled', () async {
      final binding = JalaBinding.instance
        ..initialize(config: JalaConfig(enabled: false));

      emitRequest(binding.bus, 'a');
      await pump();
      expect(binding.store.entries, isEmpty);
    });

    test('config defaults are safe', () {
      final config = JalaConfig();
      expect(config.enabled, isFalse, reason: 'safe by default in pure core');
      expect(config.maxEntries, 300);
      expect(config.maxBodyBytes, 512 * 1024);
      expect(
        config.redactor.redactHeaders({'authorization': 'x'}),
        {'authorization': JalaRedactor.mask},
        reason: 'redaction on by default',
      );
    });
  });

  group('JalaReplayRegistry', () {
    test('replay returns false when no replayer is registered', () async {
      final registry = JalaReplayRegistry();
      expect(registry.hasReplayer, isFalse);
      expect(await registry.replay(makeEntry()), isFalse);
    });

    test(
      'registered replayer receives the entry, replay returns true',
      () async {
        final registry = JalaReplayRegistry();
        final replayer = _RecordingReplayer();
        registry.register(replayer);

        final entry = makeEntry(id: 'orig');
        expect(registry.hasReplayer, isTrue);
        expect(await registry.replay(entry), isTrue);
        expect(replayer.replayed.map((e) => e.id), ['orig']);
      },
    );

    test('last registered replayer wins', () async {
      final registry = JalaReplayRegistry();
      final first = _RecordingReplayer();
      final second = _RecordingReplayer();
      registry
        ..register(first)
        ..register(second);

      await registry.replay(makeEntry());
      expect(first.replayed, isEmpty);
      expect(second.replayed, hasLength(1));
    });

    test('unregister removes only the active replayer', () async {
      final registry = JalaReplayRegistry();
      final active = _RecordingReplayer();
      final stale = _RecordingReplayer();
      registry.register(active);

      registry.unregister(stale);
      expect(registry.hasReplayer, isTrue, reason: 'stale unregister ignored');

      registry.unregister(active);
      expect(registry.hasReplayer, isFalse);
      expect(await registry.replay(makeEntry()), isFalse);
    });

    test('binding exposes a replay registry', () {
      expect(JalaBinding.instance.replayRegistry, isA<JalaReplayRegistry>());
    });
  });
}
