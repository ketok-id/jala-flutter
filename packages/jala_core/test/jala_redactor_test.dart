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
      };
      final redacted = redactor.redactHeaders(headers);

      expect(redacted, hasLength(headers.length));
      for (final entry in redacted.entries) {
        expect(entry.value, JalaRedactor.mask,
            reason: '${entry.key} must be masked');
      }
    });

    test('keeps original header names and non-sensitive values', () {
      final redacted = redactor.redactHeaders({
        'Content-Type': 'application/json',
        'Authorization': 'Bearer secret',
      });
      expect(redacted['Content-Type'], 'application/json');
      expect(redacted['Authorization'], JalaRedactor.mask);
      expect(redacted.keys, ['Content-Type', 'Authorization'],
          reason: 'name casing and order preserved');
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

    test('default set contains the seven spec headers', () {
      expect(JalaRedactor.defaultRedactedHeaders, {
        'authorization',
        'proxy-authorization',
        'cookie',
        'set-cookie',
        'x-api-key',
        'x-auth-token',
        'api-key',
      });
    });
  });

  group('JalaRedactor.redactBody', () {
    test('no patterns leaves body unchanged', () {
      expect(JalaRedactor().redactBody('secret'), 'secret');
    });

    test('string patterns are replaced with the mask', () {
      final redactor = JalaRedactor(redactedBodyPatterns: ['hunter2']);
      expect(
        redactor.redactBody('pw=hunter2&pw2=hunter2'),
        'pw=${JalaRedactor.mask}&pw2=${JalaRedactor.mask}',
      );
    });

    test('regexp patterns are replaced with the mask', () {
      final redactor = JalaRedactor(
        redactedBodyPatterns: [RegExp(r'"password":\s*"[^"]*"')],
      );
      expect(
        redactor.redactBody('{"user":"a","password": "s3cret"}'),
        '{"user":"a",${JalaRedactor.mask}}',
      );
    });

    test('multiple patterns are all applied', () {
      final redactor = JalaRedactor(
        redactedBodyPatterns: ['aaa', RegExp('b+')],
      );
      expect(
        redactor.redactBody('aaa and bbb'),
        '${JalaRedactor.mask} and ${JalaRedactor.mask}',
      );
    });
  });
}
