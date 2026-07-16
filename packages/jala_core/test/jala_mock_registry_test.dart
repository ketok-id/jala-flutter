import 'package:jala_core/jala_core.dart';
import 'package:test/test.dart';

JalaMockRule rule({
  String id = 'r1',
  String name = 'rule',
  bool enabled = true,
  String? method,
  String urlPattern = 'https://api.example.com/*',
  String? bodyContains,
  MockAction? action,
}) {
  return JalaMockRule(
    id: id,
    name: name,
    enabled: enabled,
    method: method,
    urlPattern: urlPattern,
    bodyContains: bodyContains,
    action: action ??
        const MockResponse(statusCode: 200, body: '{"ok":true}'),
  );
}

void main() {
  group('JalaMockRule.matches', () {
    test('method null matches any method', () {
      final JalaMockRule r = rule(method: null);
      expect(
        r.matches(method: 'GET', uri: Uri.parse('https://api.example.com/a')),
        isTrue,
      );
      expect(
        r.matches(method: 'POST', uri: Uri.parse('https://api.example.com/a')),
        isTrue,
      );
    });

    test('method is case-insensitive', () {
      final JalaMockRule r = rule(method: 'post');
      expect(
        r.matches(method: 'POST', uri: Uri.parse('https://api.example.com/a')),
        isTrue,
      );
      expect(
        r.matches(method: 'GET', uri: Uri.parse('https://api.example.com/a')),
        isFalse,
      );
    });

    test('disabled never matches', () {
      final JalaMockRule r = rule(enabled: false);
      expect(
        r.matches(method: 'GET', uri: Uri.parse('https://api.example.com/a')),
        isFalse,
      );
    });

    test('bodyContains is case-insensitive', () {
      final JalaMockRule r = rule(bodyContains: 'Secret');
      expect(
        r.matches(
          method: 'POST',
          uri: Uri.parse('https://api.example.com/a'),
          bodyText: '{"token":"secret-value"}',
        ),
        isTrue,
      );
      expect(
        r.matches(
          method: 'POST',
          uri: Uri.parse('https://api.example.com/a'),
          bodyText: '{}',
        ),
        isFalse,
      );
    });
  });

  group('MockAction JSON', () {
    test('MockResponse round-trips', () {
      const MockResponse original = MockResponse(
        statusCode: 201,
        headers: <String, String>{'content-type': 'application/json'},
        body: '{"id":1}',
        delay: Duration(milliseconds: 50),
      );
      final MockAction restored = MockAction.fromJson(original.toJson());
      expect(restored, isA<MockResponse>());
      final MockResponse r = restored as MockResponse;
      expect(r.statusCode, 201);
      expect(r.headers['content-type'], 'application/json');
      expect(r.body, '{"id":1}');
      expect(r.delay, const Duration(milliseconds: 50));
    });

    test('MockFailure and MockDelay round-trip', () {
      const MockFailure failure = MockFailure(
        kind: MockFailureKind.timeout,
        delay: Duration(seconds: 1),
      );
      final MockAction f = MockAction.fromJson(failure.toJson());
      expect((f as MockFailure).kind, MockFailureKind.timeout);

      const MockDelay delay = MockDelay(delay: Duration(milliseconds: 25));
      final MockAction d = MockAction.fromJson(delay.toJson());
      expect((d as MockDelay).delay, const Duration(milliseconds: 25));
    });

    test('JalaMockRule JSON round-trips', () {
      final JalaMockRule original = rule(
        id: 'abc',
        name: 'users',
        method: 'GET',
        bodyContains: 'x',
      );
      final JalaMockRule restored = JalaMockRule.fromJson(original.toJson());
      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.method, original.method);
      expect(restored.bodyContains, original.bodyContains);
      expect(restored.urlPattern, original.urlPattern);
      expect(restored.action, isA<MockResponse>());
    });
  });

  group('JalaMockRegistry', () {
    test('first enabled match wins', () {
      final JalaMockRegistry registry = JalaMockRegistry();
      registry.add(
        rule(
          id: 'first',
          urlPattern: 'https://api.example.com/*',
          action: const MockResponse(statusCode: 200, body: 'a'),
        ),
      );
      registry.add(
        rule(
          id: 'second',
          urlPattern: 'https://api.example.com/*',
          action: const MockResponse(statusCode: 201, body: 'b'),
        ),
      );
      final JalaMockRule? m = registry.match(
        method: 'GET',
        uri: Uri.parse('https://api.example.com/x'),
      );
      expect(m?.id, 'first');
    });

    test('skips disabled rules', () {
      final JalaMockRegistry registry = JalaMockRegistry();
      registry.add(rule(id: 'off', enabled: false));
      registry.add(rule(id: 'on'));
      expect(
        registry
            .match(
              method: 'GET',
              uri: Uri.parse('https://api.example.com/x'),
            )
            ?.id,
        'on',
      );
    });

    test('watch emits on mutations', () async {
      final JalaMockRegistry registry = JalaMockRegistry();
      final List<int> lengths = <int>[];
      final subscription = registry.watch.listen(
        (List<JalaMockRule> rules) => lengths.add(rules.length),
      );
      await Future<void>.delayed(Duration.zero);
      registry.add(rule(id: 'a'));
      await Future<void>.delayed(Duration.zero);
      registry.remove('a');
      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();
      expect(lengths, containsAllInOrder(<int>[0, 1, 0]));
    });

    test('hydrate loads from store', () async {
      final InMemoryJalaMockStore store = InMemoryJalaMockStore();
      await store.save(<JalaMockRule>[rule(id: 'persisted')]);
      final JalaMockRegistry registry = JalaMockRegistry(store: store);
      expect(registry.rules, isEmpty);
      await registry.hydrate();
      expect(registry.rules.single.id, 'persisted');
    });

    test('mutations persist to store', () async {
      final InMemoryJalaMockStore store = InMemoryJalaMockStore();
      final JalaMockRegistry registry = JalaMockRegistry(store: store);
      registry.add(rule(id: 'saved'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final List<JalaMockRule> loaded = await store.load();
      expect(loaded.single.id, 'saved');
    });

    test('setEnabled and enabledCount', () {
      final JalaMockRegistry registry = JalaMockRegistry();
      registry.add(rule(id: 'a'));
      registry.add(rule(id: 'b'));
      expect(registry.enabledCount, 2);
      registry.setEnabled('a', false);
      expect(registry.enabledCount, 1);
      expect(registry.rules.firstWhere((r) => r.id == 'a').enabled, isFalse);
    });
  });

  group('store mockRuleId correlation', () {
    test('request event with mockRuleId lands on entry', () async {
      JalaBinding.instance.initialize(config: JalaConfig(enabled: true));
      addTearDown(JalaBinding.resetForTesting);

      JalaBinding.instance.bus.emit(
        NetworkRequestEvent(
          callId: 'c1',
          timestamp: DateTime.now(),
          method: 'GET',
          uri: Uri.parse('https://api.example.com/x'),
          headers: const <String, String>{},
          body: CapturedBody.none,
          client: 'test',
          mockRuleId: 'rule-9',
        ),
      );
      await Future<void>.delayed(Duration.zero);

      final NetworkCallEntry entry = JalaBinding.instance.store.entries.single;
      expect(entry.mockRuleId, 'rule-9');
    });
  });
}
