import 'package:jala_core/jala_core.dart';
import 'package:test/test.dart';

void main() {
  group('globMatches', () {
    test('exact match without wildcards', () {
      expect(globMatches('https://a.com/x', 'https://a.com/x'), isTrue);
      expect(globMatches('https://a.com/x', 'https://a.com/y'), isFalse);
    });

    test('trailing *', () {
      expect(
        globMatches('https://api.example.com/*', 'https://api.example.com/users'),
        isTrue,
      );
      expect(
        globMatches('https://api.example.com/*', 'https://other.example.com/users'),
        isFalse,
      );
    });

    test('leading *', () {
      expect(globMatches('*/users', 'https://api.example.com/users'), isTrue);
      expect(globMatches('*/users', 'https://api.example.com/posts'), isFalse);
    });

    test('middle *', () {
      expect(
        globMatches('https://*.example.com/v1/*', 'https://api.example.com/v1/x'),
        isTrue,
      );
    });

    test('empty * segment matches empty', () {
      expect(globMatches('ab*', 'ab'), isTrue);
      expect(globMatches('*ab', 'ab'), isTrue);
      expect(globMatches('*', 'anything'), isTrue);
    });

    test('literal dots and special regex chars are escaped', () {
      expect(globMatches('a.com', 'aXcom'), isFalse);
      expect(globMatches('a.com', 'a.com'), isTrue);
    });
  });

  group('globMatchesIgnoreCase', () {
    test('ignores case', () {
      expect(globMatchesIgnoreCase('HOST.COM', 'host.com'), isTrue);
    });
  });
}
