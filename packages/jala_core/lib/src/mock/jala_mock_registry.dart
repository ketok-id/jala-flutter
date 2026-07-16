import 'dart:async';

import 'jala_mock_rule.dart';
import 'jala_mock_store.dart';

/// Ordered mock rules for the process: first enabled match wins.
///
/// Mutations emit on [watch] and are persisted through the attached
/// [JalaMockStore]. Saves are serialized so rapid toggles cannot race.
class JalaMockRegistry {
  /// Creates a registry backed by [store] (defaults to in-memory).
  JalaMockRegistry({JalaMockStore? store})
    : _store = store ?? InMemoryJalaMockStore();

  JalaMockStore _store;
  final List<JalaMockRule> _rules = <JalaMockRule>[];
  final StreamController<List<JalaMockRule>> _controller =
      StreamController<List<JalaMockRule>>.broadcast();
  Future<void> _saveChain = Future<void>.value();

  /// Snapshot of rules in evaluation order (unmodifiable).
  List<JalaMockRule> get rules => List<JalaMockRule>.unmodifiable(_rules);

  /// Number of currently enabled rules (for UI badges).
  int get enabledCount => _rules.where((JalaMockRule r) => r.enabled).length;

  /// Emits the current rule list to new subscribers, then every mutation.
  Stream<List<JalaMockRule>> get watch async* {
    yield rules;
    yield* _controller.stream;
  }

  /// Replaces the persistence backend and reloads rules from it.
  Future<void> attachStore(JalaMockStore store) async {
    _store = store;
    await hydrate();
  }

  /// Loads rules from the current store, replacing the in-memory list.
  Future<void> hydrate() async {
    final List<JalaMockRule> loaded = await _store.load();
    _rules
      ..clear()
      ..addAll(loaded);
    _emit();
  }

  /// First enabled rule matching the request, or null.
  JalaMockRule? match({
    required String method,
    required Uri uri,
    String? bodyText,
  }) {
    for (final JalaMockRule rule in _rules) {
      if (rule.matches(method: method, uri: uri, bodyText: bodyText)) {
        return rule;
      }
    }
    return null;
  }

  /// Appends [rule] (or replaces an existing rule with the same id).
  void add(JalaMockRule rule) {
    final int index = _rules.indexWhere((JalaMockRule r) => r.id == rule.id);
    if (index >= 0) {
      _rules[index] = rule;
    } else {
      _rules.add(rule);
    }
    _emit();
    _schedulePersist();
  }

  /// Replaces the rule with the same [JalaMockRule.id], or no-ops if missing.
  void update(JalaMockRule rule) {
    final int index = _rules.indexWhere((JalaMockRule r) => r.id == rule.id);
    if (index < 0) return;
    _rules[index] = rule;
    _emit();
    _schedulePersist();
  }

  /// Removes the rule with [id], if present.
  void remove(String id) {
    final int before = _rules.length;
    _rules.removeWhere((JalaMockRule r) => r.id == id);
    if (_rules.length == before) return;
    _emit();
    _schedulePersist();
  }

  /// Toggles [enabled] for the rule with [id].
  void setEnabled(String id, bool enabled) {
    final int index = _rules.indexWhere((JalaMockRule r) => r.id == id);
    if (index < 0) return;
    final JalaMockRule current = _rules[index];
    if (current.enabled == enabled) return;
    _rules[index] = current.copyWith(enabled: enabled);
    _emit();
    _schedulePersist();
  }

  /// Replaces the entire list (used by import / tests).
  void replaceAll(List<JalaMockRule> rules) {
    _rules
      ..clear()
      ..addAll(rules);
    _emit();
    _schedulePersist();
  }

  /// Clears all rules.
  void clear() {
    if (_rules.isEmpty) return;
    _rules.clear();
    _emit();
    _schedulePersist();
  }

  /// Releases the broadcast stream. Idempotent.
  Future<void> dispose() async {
    try {
      await _saveChain.timeout(const Duration(seconds: 2));
    } on Object {
      // Don't block test teardown / binding reset on a stuck save.
    }
    if (!_controller.isClosed) {
      await _controller.close();
    }
  }

  void _emit() {
    if (!_controller.isClosed) {
      _controller.add(rules);
    }
  }

  void _schedulePersist() {
    _saveChain = _saveChain
        .then((_) => _store.save(List<JalaMockRule>.from(_rules)))
        .catchError((Object _) {
          // Persistence failures must never break the inspector.
        });
  }
}
