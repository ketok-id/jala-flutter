import 'package:jala_core/jala_core.dart';
import 'package:test/test.dart';

void main() {
  group('JalaRedactor.redactHeaders', () {
    final redactor = JalaRedactor();

    test('redacts every default header, case-insensitively', () {
      final headers = <String, String>{
        'Authorization': 'Bearer secret',
        'PROXY-AUTHORIZATION': 'Basic abc',
        'Cookie': 'session=1',
        'set-cookie': 'session=2',
        'X-Api-Key': 'k',
        'x-AUTH-token': 't',
        'API-KEY': 'k2',
        'X-Access-Token': 'at',
        'x-csrf-token': 'csrf',
        'X-Amz-Security-Token': 'aws',
      };
      final redacted = redactor.redactHeaders(headers);

      expect(redacted, hasLength(headers.length));
      for (final entry in redacted.entries) {
        expect(
          entry.value,
          JalaRedactor.mask,
          reason: '${entry.key} must be masked',
        );
      }
    });

    test('keeps original header names and non-sensitive values', () {
      final redacted = redactor.redactHeaders({
        'Content-Type': 'application/json',
        'Authorization': 'Bearer secret',
      });
      expect(redacted['Content-Type'], 'application/json');
      expect(redacted['Authorization'], JalaRedactor.mask);
      expect(redacted.keys, [
        'Content-Type',
        'Authorization',
      ], reason: 'name casing and order preserved');
    });

    test('custom redacted header set replaces the defaults', () {
      final custom = JalaRedactor(redactedHeaders: {'X-Secret'});
      final redacted = custom.redactHeaders({
        'x-secret': 'v',
        'Authorization': 'Bearer ok-to-keep',
      });
      expect(redacted['x-secret'], JalaRedactor.mask);
      expect(redacted['Authorization'], 'Bearer ok-to-keep');
    });

    test('does not mutate the input map', () {
      final input = {'Authorization': 'Bearer secret'};
      redactor.redactHeaders(input);
      expect(input['Authorization'], 'Bearer secret');
    });

    test('default set includes enterprise auth headers', () {
      expect(
        JalaRedactor.defaultRedactedHeaders,
        containsAll(<String>[
          'authorization',
          'proxy-authorization',
          'cookie',
          'set-cookie',
          'x-api-key',
          'x-auth-token',
          'api-key',
          'x-access-token',
          'x-csrf-token',
          'x-amz-security-token',
        ]),
      );
    });
  });

  group('JalaRedactor.redactBody', () {
    test('default patterns redact JSON password values', () {
      final out = JalaRedactor().redactBody(
        '{"user":"a","password":"s3cret","ok":true}',
      );
      expect(out, contains('"user":"a"'));
      expect(out, contains('"password":"${JalaRedactor.mask}"'));
      expect(out, isNot(contains('s3cret')));
    });

    test('default patterns redact access_token and refresh_token', () {
      final out = JalaRedactor().redactBody(
        '{"access_token":"aaa","refresh_token":"bbb"}',
      );
      expect(out, isNot(contains('aaa')));
      expect(out, isNot(contains('bbb')));
      expect(out, contains(JalaRedactor.mask));
    });

    test('default patterns redact form-urlencoded secrets', () {
      final out = JalaRedactor().redactBody(
        'user=ada&password=hunter2&access_token=tok',
      );
      expect(out, contains('user=ada'));
      expect(out, contains('password=${JalaRedactor.mask}'));
      expect(out, contains('access_token=${JalaRedactor.mask}'));
      expect(out, isNot(contains('hunter2')));
    });

    test('includeDefaultBodyPatterns: false skips built-ins', () {
      final redactor = JalaRedactor(includeDefaultBodyPatterns: false);
      expect(
        redactor.redactBody('{"password":"s3cret"}'),
        '{"password":"s3cret"}',
      );
    });

    test('custom string patterns still apply', () {
      final redactor = JalaRedactor(redactedBodyPatterns: ['hunter2']);
      expect(
        redactor.redactBody('pw=hunter2&pw2=hunter2'),
        'pw=${JalaRedactor.mask}&pw2=${JalaRedactor.mask}',
      );
    });

    test('custom regexp patterns still apply', () {
      final redactor = JalaRedactor(
        includeDefaultBodyPatterns: false,
        redactedBodyPatterns: [RegExp(r'"password":\s*"[^"]*"')],
      );
      expect(
        redactor.redactBody('{"user":"a","password": "s3cret"}'),
        '{"user":"a",${JalaRedactor.mask}}',
      );
    });
  });

  group('redactUri', () {
    final JalaRedactor redactor = JalaRedactor();

    Uri redact(String url) => redactor.redactUri(Uri.parse(url));

    test('returns the URI untouched when there is no query', () {
      final Uri uri = Uri.parse('https://api.example.com/users');
      expect(redact('https://api.example.com/users'), uri);
    });

    test('masks a token value and leaves the rest of the URL intact', () {
      final Uri out = redact(
        'https://api.example.com/me?access_token=ya29.secret&page=1',
      );
      expect(out.queryParameters['access_token'], JalaRedactor.mask);
      expect(out.queryParameters['page'], '1');
      expect(out.host, 'api.example.com');
      expect(out.path, '/me');
      expect(out.toString(), isNot(contains('ya29.secret')));
    });

    test('matches names ignoring case, dashes and underscores', () {
      for (final String name in <String>[
        'access_token',
        'access-token',
        'AccessToken',
        'ACCESS_TOKEN',
      ]) {
        final Uri out = redact('https://x.dev/a?$name=s3cret');
        expect(
          out.queryParameters[name],
          JalaRedactor.mask,
          reason: '$name should be redacted',
        );
      }
    });

    test('masks presigned-URL signature parameters', () {
      final Uri out = redact(
        'https://s3.example.com/o?X-Amz-Credential=AKIA%2F20260728'
        '&X-Amz-Signature=abc123&X-Amz-Expires=900',
      );
      expect(out.queryParameters['X-Amz-Signature'], JalaRedactor.mask);
      expect(out.queryParameters['X-Amz-Credential'], JalaRedactor.mask);
      expect(out.queryParameters['X-Amz-Expires'], '900');
    });

    test('leaves non-sensitive parameters alone', () {
      final Uri out = redact(
        'https://x.dev/s?page=1&sort_by=default&client_id=public-app&code=ID',
      );
      expect(out.queryParameters['client_id'], 'public-app');
      expect(out.queryParameters['code'], 'ID');
      expect(out.queryParameters['sort_by'], 'default');
    });

    test('preserves valueless params, empty values and repeated keys', () {
      final Uri out = redact(
        'https://x.dev/s?q&token=s3cret&tag=a&tag=b&min_price&empty=',
      );
      final List<String> segments = out.query.split('&');
      expect(segments, contains('q'));
      expect(segments, contains('min_price'));
      expect(segments, contains('empty='));
      expect(out.queryParametersAll['tag'], <String>['a', 'b']);
      expect(out.queryParameters['token'], JalaRedactor.mask);
    });

    test('does not re-encode untouched parameters', () {
      final Uri out = redact(
        'https://x.dev/s?item_type%5B%5D=12&token=s3cret&z=a+b',
      );
      expect(out.query, contains('item_type%5B%5D=12'));
      expect(out.queryParameters['z'], 'a b');
    });

    test('masked value round-trips so replay can detect it', () {
      final Uri out = redact('https://x.dev/s?api_key=abc');
      // Re-parsing the rendered URL must still yield exactly `mask`, which
      // is what the replayers compare against when dropping secrets.
      expect(
        Uri.parse(out.toString()).queryParameters['api_key'],
        JalaRedactor.mask,
      );
    });

    test('is a no-op when no parameter matches (same instance)', () {
      final Uri uri = Uri.parse('https://x.dev/s?page=1');
      expect(identical(redactor.redactUri(uri), uri), isTrue);
    });

    test('stripMaskedQueryParams drops masked params, keeps the rest', () {
      final Uri masked = redact('https://x.dev/s?token=s3cret&page=1');
      final Uri stripped = JalaRedactor.stripMaskedQueryParams(masked);
      expect(stripped.queryParameters.containsKey('token'), isFalse);
      expect(stripped.queryParameters['page'], '1');
    });

    test('stripMaskedQueryParams leaves a clean URL when all params go', () {
      final Uri masked = redact('https://x.dev/s?token=s3cret');
      final Uri stripped = JalaRedactor.stripMaskedQueryParams(masked);
      expect(stripped.toString(), 'https://x.dev/s');
      expect(stripped.hasQuery, isFalse);
    });

    test('stripMaskedQueryParams is a no-op when nothing is masked', () {
      final Uri uri = Uri.parse('https://x.dev/s?page=1&q');
      expect(identical(JalaRedactor.stripMaskedQueryParams(uri), uri), isTrue);
    });

    test('honors a custom parameter set', () {
      final JalaRedactor custom = JalaRedactor(
        redactedQueryParams: const <String>{'tenant'},
      );
      final Uri out = custom.redactUri(
        Uri.parse('https://x.dev/s?tenant=acme&token=s3cret'),
      );
      expect(out.queryParameters['tenant'], JalaRedactor.mask);
      expect(
        out.queryParameters['token'],
        's3cret',
        reason: 'a custom set replaces the defaults',
      );
    });
  });
}
