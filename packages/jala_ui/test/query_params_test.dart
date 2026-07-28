import 'package:flutter_test/flutter_test.dart';
import 'package:jala_ui/src/util/query_params.dart';

void main() {
  List<String> pairs(Uri uri) => parseQueryParams(uri)
      .map((JalaQueryParam p) => '${p.name}=${p.value ?? '<null>'}')
      .toList();

  test('returns nothing for a URI with no query', () {
    expect(parseQueryParams(Uri.parse('https://x.dev/a/b')), isEmpty);
    expect(parseQueryParams(Uri.parse('https://x.dev/a/b?')), isEmpty);
  });

  test('decodes percent-encoded names and values', () {
    expect(
      pairs(Uri.parse('https://x.dev/s?item_type%5B%5D=12&sort=price%2Cdesc')),
      <String>['item_type[]=12', 'sort=price,desc'],
    );
  });

  test('keeps valueless parameters as rows with a null value', () {
    // The regression this section exists for: Uri.queryParametersAll maps
    // these to an empty list, so iterating it drops them entirely.
    expect(
      pairs(Uri.parse('https://x.dev/s?q&page=1&min_price&max_price')),
      <String>['q=<null>', 'page=1', 'min_price=<null>', 'max_price=<null>'],
    );
  });

  test('distinguishes a valueless parameter from an empty one', () {
    final List<JalaQueryParam> params = parseQueryParams(
      Uri.parse('https://x.dev/s?a&b='),
    );
    expect(params[0].value, isNull);
    expect(params[1].value, '');
  });

  test('preserves wire order and repeated keys', () {
    expect(
      pairs(Uri.parse('https://x.dev/s?tag=b&z=1&tag=a')),
      <String>['tag=b', 'z=1', 'tag=a'],
    );
  });

  test('decodes + as a space', () {
    expect(
      pairs(Uri.parse('https://x.dev/s?name=john+doe')),
      <String>['name=john doe'],
    );
  });

  test('keeps malformed percent-escapes verbatim instead of throwing', () {
    expect(
      pairs(Uri.parse('https://x.dev/s?bad=%zz&trunc=a%2')),
      <String>['bad=%zz', 'trunc=a%2'],
    );
  });

  test('keeps only the first = as the separator', () {
    expect(
      pairs(Uri.parse('https://x.dev/s?filter=a%3Db')),
      <String>['filter=a=b'],
    );
  });

  test('parses the full real-world search URL', () {
    final List<JalaQueryParam> params = parseQueryParams(
      Uri.parse(
        'https://api-dev.example.co.id/dev/databox/api/v2/products/search'
        '?hasActiveObjectFilters=true&page=1&limit=12&q&item_type%5B%5D=12'
        '&auction_company_id%5B%5D=2&auction_schedule_id%5B%5D=10145'
        '&cluster_id%5B%5D=9659&sort_by=default&min_price&max_price',
      ),
    );
    expect(params, hasLength(11));
    expect(params.map((JalaQueryParam p) => p.name), containsAll(<String>[
      'item_type[]',
      'auction_company_id[]',
      'auction_schedule_id[]',
      'cluster_id[]',
    ]));
    expect(
      params.where((JalaQueryParam p) => p.value == null).map(
        (JalaQueryParam p) => p.name,
      ),
      <String>['q', 'min_price', 'max_price'],
    );
  });
}
