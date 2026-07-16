import 'package:jala_core/jala_core.dart';
import 'package:test/test.dart';

import 'test_helpers.dart';

void main() {
  bool match(String query, NetworkCallEntry entry) =>
      JalaFilter.parse(query).matches(entry);

  group('method term', () {
    final get = makeEntry(method: 'GET');
    final post = makeEntry(method: 'POST');

    test('method:get matches only that method', () {
      expect(match('method:get', get), isTrue);
      expect(match('method:get', post), isFalse);
    });

    test('m: alias and case-insensitivity', () {
      expect(match('m:GET', get), isTrue);
      expect(match('M:get', get), isTrue);
    });

    test('comma list matches any listed method', () {
      expect(match('m:get,post', get), isTrue);
      expect(match('m:get,post', post), isTrue);
      expect(match('m:put,delete', get), isFalse);
    });
  });

  group('status term', () {
    final ok = makeEntry(statusCode: 200);
    final notFound = makeEntry(statusCode: 404);
    final serverError = makeEntry(statusCode: 503);
    final pending = makeEntry(
      statusCode: null,
      status: JalaCallStatus.pending,
      duration: null,
    );
    final transportError = makeEntry(
      statusCode: null,
      status: JalaCallStatus.error,
      errorMessage: 'boom',
    );
    final cancelled = makeEntry(
      statusCode: null,
      status: JalaCallStatus.cancelled,
    );

    test('exact code with status: and s:', () {
      expect(match('status:404', notFound), isTrue);
      expect(match('s:404', notFound), isTrue);
      expect(match('s:404', ok), isFalse);
    });

    test('status class 4xx / 5xx / 2xx', () {
      expect(match('status:4xx', notFound), isTrue);
      expect(match('status:4xx', serverError), isFalse);
      expect(match('s:5xx', serverError), isTrue);
      expect(match('s:2xx', ok), isTrue);
      expect(match('s:2xx', pending), isFalse);
    });

    test('s:error matches >=400, transport errors, and cancellations', () {
      expect(match('s:error', notFound), isTrue);
      expect(match('s:error', serverError), isTrue);
      expect(match('s:error', transportError), isTrue);
      expect(match('s:error', cancelled), isTrue);
      expect(match('s:error', ok), isFalse);
      expect(match('s:error', pending), isFalse);
    });

    test('s:pending matches only in-flight calls', () {
      expect(match('s:pending', pending), isTrue);
      expect(match('s:pending', ok), isFalse);
    });
  });

  group('host term', () {
    final api = makeEntry(url: 'https://api.example.com/users');
    final cdn = makeEntry(url: 'https://cdn.example.com/img.png');
    final other = makeEntry(url: 'https://other.dev/');

    test('exact host with host: and d:', () {
      expect(match('host:api.example.com', api), isTrue);
      expect(match('d:api.example.com', api), isTrue);
      expect(match('host:api.example.com', cdn), isFalse);
    });

    test('case-insensitive host', () {
      expect(match('host:API.EXAMPLE.COM', api), isTrue);
    });

    test('* wildcard', () {
      expect(match('host:*.example.com', api), isTrue);
      expect(match('host:*.example.com', cdn), isTrue);
      expect(match('host:*.example.com', other), isFalse);
      expect(match('host:api.*', api), isTrue);
    });
  });

  group('path term', () {
    final users = makeEntry(url: 'https://x.dev/api/users/42');

    test('path substring', () {
      expect(match('path:/users', users), isTrue);
      expect(match('path:users', users), isTrue);
      expect(match('path:/orders', users), isFalse);
    });
  });

  group('type term', () {
    final json = makeEntry(
      responseHeaders: const {'content-type': 'application/json'},
      responseBody: CapturedBody.capture('{}', contentType: 'application/json'),
    );
    final html = makeEntry(
      responseHeaders: const {'Content-Type': 'text/html; charset=utf-8'},
    );

    test('matches response content-type substring', () {
      expect(match('type:json', json), isTrue);
      expect(match('t:json', json), isTrue);
      expect(match('t:json', html), isFalse);
      expect(match('t:html', html), isTrue);
    });
  });

  group('larger-than term', () {
    final small = makeEntry(responseSize: 512);
    final big = makeEntry(responseSize: 20 * 1024);
    final huge = makeEntry(responseSize: 3 * 1024 * 1024);
    final unknown = makeEntry(responseSize: null);

    test('plain number means bytes (strictly greater)', () {
      expect(match('larger-than:511', small), isTrue);
      expect(match('larger-than:512', small), isFalse);
    });

    test('k and m suffixes', () {
      expect(match('larger-than:10k', big), isTrue);
      expect(match('larger-than:10k', small), isFalse);
      expect(match('larger-than:2m', huge), isTrue);
      expect(match('larger-than:2m', big), isFalse);
    });

    test('unknown size never matches', () {
      expect(match('larger-than:1', unknown), isFalse);
    });
  });

  group('slower-than term', () {
    final fast = makeEntry(duration: const Duration(milliseconds: 100));
    final slow = makeEntry(duration: const Duration(milliseconds: 900));

    test('matches duration strictly greater than n ms', () {
      expect(match('slower-than:500', slow), isTrue);
      expect(match('slower-than:500', fast), isFalse);
      expect(match('slower-than:900', slow), isFalse);
    });
  });

  group('is term', () {
    final replay = makeEntry(replayOf: 'orig-1');
    final mocked = makeEntry(mockRuleId: 'rule-1');
    final normal = makeEntry();

    test('is:replay', () {
      expect(match('is:replay', replay), isTrue);
      expect(match('is:replay', normal), isFalse);
    });

    test('is:mocked', () {
      expect(match('is:mocked', mocked), isTrue);
      expect(match('is:mocked', normal), isFalse);
      expect(match('is:mocked', replay), isFalse);
    });
  });

  group('op term (GraphQL operationName)', () {
    final query = makeEntry(operationName: 'GetUser', operationType: 'query');
    final mutation = makeEntry(
      operationName: 'CreateUser',
      operationType: 'mutation',
    );
    final plain = makeEntry();

    test('exact operationName match', () {
      expect(match('op:GetUser', query), isTrue);
      expect(match('op:GetUser', mutation), isFalse);
    });

    test('case-insensitive', () {
      expect(match('op:getuser', query), isTrue);
    });

    test('* wildcard, same semantics as host:', () {
      expect(match('op:Get*', query), isTrue);
      expect(match('op:*User', query), isTrue);
      expect(match('op:*User', mutation), isTrue);
      expect(match('op:Delete*', query), isFalse);
    });

    test('never matches an entry without an operationName', () {
      expect(match('op:GetUser', plain), isFalse);
      expect(match('op:*', plain), isFalse);
    });
  });

  group('is:graphql term', () {
    final gql = makeEntry(operationName: 'GetUser', operationType: 'query');
    final plain = makeEntry();

    test('matches only entries with a non-null operationName', () {
      expect(match('is:graphql', gql), isTrue);
      expect(match('is:graphql', plain), isFalse);
    });
  });

  group('is:ws term against NetworkCallEntry', () {
    test('always false — a NetworkCallEntry is never a WS entry', () {
      expect(match('is:ws', makeEntry()), isFalse);
      expect(
        match('is:ws', makeEntry(operationName: 'GetUser')),
        isFalse,
        reason: 'even a GraphQL entry is not a WS entry',
      );
    });

    test('negated -is:ws matches every NetworkCallEntry', () {
      expect(match('-is:ws', makeEntry()), isTrue);
    });
  });

  group('body term', () {
    final entry = makeEntry(
      requestBody: CapturedBody.capture(
        '{"token": "abc"}',
        contentType: 'application/json',
      ),
      responseBody: CapturedBody.capture(
        '{"result": "GRANTED"}',
        contentType: 'application/json',
      ),
    );

    test('matches request body substring', () {
      expect(match('body:token', entry), isTrue);
    });

    test('matches response body substring, case-insensitive', () {
      expect(match('body:granted', entry), isTrue);
    });

    test('no match', () {
      expect(match('body:missing', entry), isFalse);
    });
  });

  group('bare word (free text)', () {
    final entry = makeEntry(
      method: 'POST',
      url: 'https://api.example.com/v1/users?role=Admin',
    );

    test('matches URL substring case-insensitively', () {
      expect(match('example', entry), isTrue);
      expect(match('ROLE=admin', entry), isTrue);
      expect(match('/v1/users', entry), isTrue);
      expect(match('missing', entry), isFalse);
    });

    test('matches the method too', () {
      expect(match('post', entry), isTrue);
    });
  });

  group('negation', () {
    final ok = makeEntry(statusCode: 200);
    final notFound = makeEntry(statusCode: 404);

    test('-status:404 excludes matches', () {
      expect(match('-status:404', notFound), isFalse);
      expect(match('-status:404', ok), isTrue);
    });

    test('-bare word', () {
      final entry = makeEntry(url: 'https://api.example.com/x');
      expect(match('-example', entry), isFalse);
      expect(match('-nothere', entry), isTrue);
    });

    test('a lone dash is treated as free text, not negation', () {
      final dashed = makeEntry(url: 'https://api.example.com/a-b');
      expect(match('-', dashed), isTrue);
    });
  });

  group('combinations (AND semantics)', () {
    final entry = makeEntry(
      method: 'POST',
      url: 'https://api.example.com/users',
      statusCode: 404,
      responseSize: 2048,
      duration: const Duration(milliseconds: 800),
    );

    test('all terms must match', () {
      expect(match('m:post s:4xx host:*.example.com', entry), isTrue);
      expect(match('m:post s:4xx path:/users slower-than:500', entry), isTrue);
      expect(match('m:post s:2xx', entry), isFalse);
      expect(match('m:get s:4xx', entry), isFalse);
    });

    test('mix of structured, negated, and free-text terms', () {
      expect(match('users -s:5xx m:post larger-than:1k', entry), isTrue);
      expect(match('users -s:4xx m:post', entry), isFalse);
    });
  });

  group('malformed terms degrade to free text', () {
    test('unknown key falls back to free-text matching', () {
      final entry = makeEntry(url: 'https://x.dev/a?weird:thing=1');
      expect(match('weird:thing', entry), isTrue);
      expect(match('unknown:value', entry), isFalse);
    });

    test('unparseable larger-than value degrades to free text', () {
      final entry = makeEntry(url: 'https://x.dev/larger-than:abc');
      expect(match('larger-than:abc', entry), isTrue);
      expect(match('larger-than:abc', makeEntry()), isFalse);
    });

    test('unparseable slower-than value degrades to free text', () {
      expect(match('slower-than:soon', makeEntry()), isFalse);
    });

    test('unknown is: value degrades to free text', () {
      expect(match('is:weird', makeEntry()), isFalse);
    });

    test('unparseable status value degrades to free text', () {
      expect(match('status:okish', makeEntry()), isFalse);
    });

    test('term with trailing colon is free text', () {
      final entry = makeEntry(url: 'https://x.dev/method:');
      expect(match('method:', entry), isTrue);
    });

    test('parse never throws', () {
      for (final q in [
        '',
        '   ',
        '-',
        ':',
        '::',
        '-:',
        'status:',
        ':value',
        'larger-than:',
        'host:*',
        '((((',
        r'\\',
      ]) {
        expect(
          () => JalaFilter.parse(q).matches(makeEntry()),
          returnsNormally,
          reason: 'query "$q" must not throw',
        );
      }
    });
  });

  group('empty query', () {
    test('matches everything', () {
      final filter = JalaFilter.parse('');
      expect(filter.isEmpty, isTrue);
      expect(filter.matches(makeEntry()), isTrue);
      expect(JalaFilter.parse('   ').matches(makeEntry()), isTrue);
    });
  });

  group('matchesWs', () {
    bool matchWs(String query, WsConnectionEntry entry) =>
        JalaFilter.parse(query).matchesWs(entry);

    final open = makeWsEntry(
      id: 'ws-1',
      url: 'wss://api.example.com/socket',
      status: WsConnectionStatus.open,
    );
    final errored = makeWsEntry(
      id: 'ws-2',
      url: 'wss://cdn.example.com/socket',
      status: WsConnectionStatus.error,
    );

    test('bare text matches a substring of the uri', () {
      expect(matchWs('api.example', open), isTrue);
      expect(matchWs('socket', open), isTrue);
      expect(matchWs('nope', open), isFalse);
    });

    test('bare text is case-insensitive', () {
      expect(matchWs('API.EXAMPLE', open), isTrue);
    });

    test('host: / d: match the connection uri host, wildcard allowed', () {
      expect(matchWs('host:api.example.com', open), isTrue);
      expect(matchWs('d:api.example.com', open), isTrue);
      expect(matchWs('host:api.example.com', errored), isFalse);
      expect(matchWs('host:*.example.com', open), isTrue);
      expect(matchWs('host:*.example.com', errored), isTrue);
      expect(matchWs('host:*.other.dev', open), isFalse);
    });

    test('is:ws always matches a WS connection', () {
      expect(matchWs('is:ws', open), isTrue);
      expect(matchWs('is:ws', errored), isTrue);
    });

    test('is:ws negated never matches a WS connection', () {
      expect(matchWs('-is:ws', open), isFalse);
    });

    test('s:error / status:error match only errored connections', () {
      expect(matchWs('s:error', errored), isTrue);
      expect(matchWs('s:error', open), isFalse);
      expect(matchWs('status:error', errored), isTrue);
    });

    test('s: also matches other connection status names', () {
      expect(matchWs('s:open', open), isTrue);
      expect(matchWs('s:connecting', open), isFalse);
      expect(
        matchWs('s:closed', makeWsEntry(status: WsConnectionStatus.closed)),
        isTrue,
      );
    });

    test(
      'network-only structured keys never match a WS connection',
      () {
        expect(matchWs('method:get', open), isFalse);
        expect(matchWs('path:/x', open), isFalse);
        expect(matchWs('type:json', open), isFalse);
        expect(matchWs('larger-than:1', open), isFalse);
        expect(matchWs('slower-than:1', open), isFalse);
        expect(matchWs('body:token', open), isFalse);
        expect(matchWs('op:GetUser', open), isFalse);
      },
    );

    test(
      'negating a network-only key matches every WS connection',
      () {
        expect(matchWs('-method:get', open), isTrue);
        expect(matchWs('-op:GetUser', open), isTrue);
      },
    );

    test('is:graphql / is:replay / is:mocked never match a WS connection', () {
      expect(matchWs('is:graphql', open), isFalse);
      expect(matchWs('is:replay', open), isFalse);
      expect(matchWs('is:mocked', open), isFalse);
    });

    test('unparseable status value degrades to free text over the term', () {
      expect(
        matchWs('status:okish', makeWsEntry(url: 'wss://x.dev/status:okish')),
        isTrue,
      );
      expect(matchWs('status:okish', open), isFalse);
    });

    test('unknown key degrades to free text over the whole term', () {
      final entry = makeWsEntry(url: 'wss://x.dev/a?weird:thing=1');
      expect(matchWs('weird:thing', entry), isTrue);
      expect(matchWs('unknown:value', entry), isFalse);
    });

    test('AND semantics across mixed terms', () {
      expect(matchWs('example is:ws host:*.example.com', open), isTrue);
      expect(matchWs('example is:ws -s:error', open), isTrue);
      expect(matchWs('example is:ws -s:error', errored), isFalse);
    });

    test('parse never throws when evaluated against matchesWs', () {
      for (final q in [
        '',
        '   ',
        '-',
        ':',
        '::',
        '-:',
        'status:',
        ':value',
        'host:*',
        '((((',
        r'\\',
      ]) {
        expect(
          () => JalaFilter.parse(q).matchesWs(open),
          returnsNormally,
          reason: 'query "$q" must not throw',
        );
      }
    });

    test('empty query matches every WS connection', () {
      expect(JalaFilter.parse('').matchesWs(open), isTrue);
    });
  });
}
