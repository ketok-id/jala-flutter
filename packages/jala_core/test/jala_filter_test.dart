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
    final normal = makeEntry();

    test('is:replay', () {
      expect(match('is:replay', replay), isTrue);
      expect(match('is:replay', normal), isFalse);
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
}
