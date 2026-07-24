import 'package:jala_core/jala_core.dart';
import 'package:test/test.dart';

import 'test_helpers.dart';

void main() {
  group('JalaEntryDiff', () {
    HeaderDiff headerNamed(List<HeaderDiff> diffs, String name) =>
        diffs.firstWhere((HeaderDiff d) => d.name.toLowerCase() == name);

    test('reports a status-code change', () {
      final JalaEntryDiff diff = JalaEntryDiff.of(
        makeEntry(statusCode: 200),
        makeEntry(statusCode: 404),
      );
      expect(diff.statusChanged, isTrue);
      expect(diff.statusBefore, 200);
      expect(diff.statusAfter, 404);
    });

    test('classifies added, removed, changed and unchanged headers', () {
      final JalaEntryDiff diff = JalaEntryDiff.of(
        makeEntry(
          requestHeaders: const <String, String>{'a': '1', 'b': '2'},
        ),
        makeEntry(
          requestHeaders: const <String, String>{'a': '1', 'c': '3'},
        ),
      );
      expect(headerNamed(diff.requestHeaders, 'a').kind, JsonDiffKind.unchanged);
      expect(headerNamed(diff.requestHeaders, 'b').kind, JsonDiffKind.removed);
      expect(headerNamed(diff.requestHeaders, 'c').kind, JsonDiffKind.added);
    });

    test('matches header names case-insensitively', () {
      final JalaEntryDiff diff = JalaEntryDiff.of(
        makeEntry(requestHeaders: const <String, String>{'X-Token': '1'}),
        makeEntry(requestHeaders: const <String, String>{'x-token': '2'}),
      );
      final HeaderDiff token = headerNamed(diff.requestHeaders, 'x-token');
      expect(token.kind, JsonDiffKind.changed);
      expect(token.name, 'x-token'); // b-side casing preferred
      expect(token.before, '1');
      expect(token.after, '2');
    });

    test('diffs JSON response bodies structurally', () {
      final JalaEntryDiff diff = JalaEntryDiff.of(
        makeEntry(
          responseBody: CapturedBody.capture(
            <String, Object?>{'n': 1},
            contentType: 'application/json',
          ),
        ),
        makeEntry(
          responseBody: CapturedBody.capture(
            <String, Object?>{'n': 2},
            contentType: 'application/json',
          ),
        ),
      );
      expect(diff.responseBodyComparable, isTrue);
      expect(diff.responseBodyDiff, isNotNull);
      expect(diff.responseBodyDiff!.kind, JsonDiffKind.changed);
    });

    test('skips a structural body diff when a side is not JSON', () {
      final JalaEntryDiff diff = JalaEntryDiff.of(
        makeEntry(
          responseBody: CapturedBody.capture(
            <String, Object?>{'n': 1},
            contentType: 'application/json',
          ),
        ),
        // Second call has no captured response body.
        makeEntry(),
      );
      expect(diff.responseBodyComparable, isFalse);
      expect(diff.responseBodyDiff, isNull);
    });
  });
}
