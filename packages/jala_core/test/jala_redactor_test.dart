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
}
