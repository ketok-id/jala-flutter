import 'jala_mock_rule.dart';

/// Persistence backend for [JalaMockRegistry].
///
/// `jala_core` stays free of `dart:io`; the default is in-memory. The
/// Flutter facade (`package:jala`) provides a file-backed implementation.
abstract class JalaMockStore {
  /// Loads the full ordered rule list.
  Future<List<JalaMockRule>> load();

  /// Replaces the stored list with [rules].
  Future<void> save(List<JalaMockRule> rules);
}

/// Ephemeral store used when no persistence is configured.
class InMemoryJalaMockStore implements JalaMockStore {
  /// Creates an empty in-memory store.
  InMemoryJalaMockStore();

  List<JalaMockRule> _rules = <JalaMockRule>[];

  @override
  Future<List<JalaMockRule>> load() async =>
      List<JalaMockRule>.unmodifiable(_rules);

  @override
  Future<void> save(List<JalaMockRule> rules) async {
    _rules = List<JalaMockRule>.from(rules);
  }
}
