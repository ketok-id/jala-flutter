import 'package:ketok_core/ketok_core.dart';
import 'package:test/test.dart';

import 'test_helpers.dart';

class _RecordingReplayer implements KetokReplayer {
  final List<NetworkCallEntry> replayed = <NetworkCallEntry>[];

  @override
  Future<void> replay(NetworkCallEntry entry) async {
    replayed.add(entry);
  }
}

void main() {
  tearDown(KetokBinding.resetForTesting);

  group('KetokBinding', () {
    test('is disabled and unwired before initialize', () {
      final binding = KetokBinding.instance;
      expect(binding.isInitialized, isFalse);
      expect(binding.isEnabled, isFalse);
      expect(() => binding.config, throwsStateError);
      expect(() => binding.bus, throwsStateError);
      expect(() => binding.store, throwsStateError);
    });

    test('initialize wires config, bus, and store', () {
      final binding = KetokBinding.instance
        ..initialize(config: KetokConfig(enabled: true, maxEntries: 7));

      expect(binding.isInitialized, isTrue);
      expect(binding.isEnabled, isTrue);
      expect(binding.config.maxEntries, 7);
      expect(binding.store.maxEntries, 7);
      expect(binding.bus, isA<KetokEventBus>());
    });

    test('initialize with no config yields a disabled binding', () {
      final binding = KetokBinding.instance..initialize();
      expect(binding.isInitialized, isTrue);
      expect(binding.isEnabled, isFalse);
    });

    test('initialize is idempotent — first config wins', () {
      final binding = KetokBinding.instance
        ..initialize(config: KetokConfig(enabled: true, maxEntries: 7))
        ..initialize(config: KetokConfig(enabled: false, maxEntries: 99));

      expect(binding.config.maxEntries, 7);
      expect(binding.isEnabled, isTrue);
    });

    test('events emitted on the binding bus land in the binding store',
        () async {
      final binding = KetokBinding.instance
        ..initialize(config: KetokConfig(enabled: true));

      emitRequest(binding.bus, 'a');
      emitResponse(binding.bus, 'a', statusCode: 204);
      await pump();

      expect(binding.store.byId('a')!.statusCode, 204);
    });

    test('bus drops events while config is disabled', () async {
      final binding = KetokBinding.instance
        ..initialize(config: KetokConfig(enabled: false));

      emitRequest(binding.bus, 'a');
      await pump();
      expect(binding.store.entries, isEmpty);
    });

    test('config defaults are safe', () {
      final config = KetokConfig();
      expect(config.enabled, isFalse, reason: 'safe by default in pure core');
      expect(config.maxEntries, 300);
      expect(config.maxBodyBytes, 512 * 1024);
      expect(
        config.redactor.redactHeaders({'authorization': 'x'}),
        {'authorization': KetokRedactor.mask},
        reason: 'redaction on by default',
      );
    });
  });

  group('KetokReplayRegistry', () {
    test('replay returns false when no replayer is registered', () async {
      final registry = KetokReplayRegistry();
      expect(registry.hasReplayer, isFalse);
      expect(await registry.replay(makeEntry()), isFalse);
    });

    test('registered replayer receives the entry, replay returns true',
        () async {
      final registry = KetokReplayRegistry();
      final replayer = _RecordingReplayer();
      registry.register(replayer);

      final entry = makeEntry(id: 'orig');
      expect(registry.hasReplayer, isTrue);
      expect(await registry.replay(entry), isTrue);
      expect(replayer.replayed.map((e) => e.id), ['orig']);
    });

    test('last registered replayer wins', () async {
      final registry = KetokReplayRegistry();
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
      final registry = KetokReplayRegistry();
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
      expect(KetokBinding.instance.replayRegistry, isA<KetokReplayRegistry>());
    });
  });
}
