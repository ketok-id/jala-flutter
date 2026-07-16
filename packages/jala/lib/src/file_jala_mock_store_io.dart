import 'dart:convert';
import 'dart:io';

import 'package:jala_core/jala_core.dart';

/// File-backed [JalaMockStore] for debug sessions (`dart:io` platforms).
class FileJalaMockStore implements JalaMockStore {
  /// Creates a store writing to `{directory}/jala_mock_rules.json`.
  FileJalaMockStore(String directory)
    : file = File('$directory${Platform.pathSeparator}jala_mock_rules.json');

  /// JSON file on disk.
  final File file;

  @override
  Future<List<JalaMockRule>> load() async {
    if (!await file.exists()) return const <JalaMockRule>[];
    try {
      final String text = await file.readAsString();
      if (text.trim().isEmpty) return const <JalaMockRule>[];
      final Object? decoded = jsonDecode(text);
      if (decoded is! List) return const <JalaMockRule>[];
      return decoded
          .whereType<Map<dynamic, dynamic>>()
          .map(
            (Map<dynamic, dynamic> raw) =>
                JalaMockRule.fromJson(Map<String, dynamic>.from(raw)),
          )
          .toList();
    } on Object {
      return const <JalaMockRule>[];
    }
  }

  @override
  Future<void> save(List<JalaMockRule> rules) async {
    final Directory parent = file.parent;
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }
    final String text = const JsonEncoder.withIndent('  ').convert(
      rules.map((JalaMockRule r) => r.toJson()).toList(),
    );
    await file.writeAsString(text);
  }
}
