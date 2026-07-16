import '../util/glob.dart';
import 'mock_action.dart';

/// A single rule in the mock registry: matcher + action.
///
/// Rules are evaluated in registry order; the first **enabled** match wins.
class JalaMockRule {
  /// Creates a mock rule.
  const JalaMockRule({
    required this.id,
    required this.name,
    required this.urlPattern,
    required this.action,
    this.enabled = true,
    this.method,
    this.bodyContains,
  });

  /// JSON deserialization.
  factory JalaMockRule.fromJson(Map<String, dynamic> json) {
    final Object? actionRaw = json['action'];
    if (actionRaw is! Map) {
      throw const FormatException('JalaMockRule.action must be an object');
    }
    return JalaMockRule(
      id: json['id'] as String? ??
          (throw const FormatException('JalaMockRule missing id')),
      name: json['name'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? true,
      method: json['method'] as String?,
      urlPattern: json['urlPattern'] as String? ??
          (throw const FormatException('JalaMockRule missing urlPattern')),
      bodyContains: json['bodyContains'] as String?,
      action: MockAction.fromJson(Map<String, dynamic>.from(actionRaw)),
    );
  }

  /// Stable id (usually from [JalaIdGenerator.next]).
  final String id;

  /// Human-readable label for the UI.
  final String name;

  /// When false, the rule is skipped during matching.
  final bool enabled;

  /// HTTP method to match, or null for any method. Compared case-insensitively.
  final String? method;

  /// Glob pattern matched against the full request URL (`uri.toString()`).
  final String urlPattern;

  /// Optional case-insensitive substring that must appear in the request
  /// body text for the rule to match. Null means "any body".
  final String? bodyContains;

  /// What to do when this rule matches.
  final MockAction action;

  /// Whether this rule matches the given request.
  bool matches({
    required String method,
    required Uri uri,
    String? bodyText,
  }) {
    if (!enabled) return false;
    if (this.method != null &&
        this.method!.toUpperCase() != method.toUpperCase()) {
      return false;
    }
    if (!globMatches(urlPattern, uri.toString())) return false;
    if (bodyContains != null) {
      final String needle = bodyContains!.toLowerCase();
      final String haystack = (bodyText ?? '').toLowerCase();
      if (!haystack.contains(needle)) return false;
    }
    return true;
  }

  /// Copy with selective overrides.
  JalaMockRule copyWith({
    String? id,
    String? name,
    bool? enabled,
    Object? method = _unset,
    String? urlPattern,
    Object? bodyContains = _unset,
    MockAction? action,
  }) {
    return JalaMockRule(
      id: id ?? this.id,
      name: name ?? this.name,
      enabled: enabled ?? this.enabled,
      method: identical(method, _unset) ? this.method : method as String?,
      urlPattern: urlPattern ?? this.urlPattern,
      bodyContains: identical(bodyContains, _unset)
          ? this.bodyContains
          : bodyContains as String?,
      action: action ?? this.action,
    );
  }

  /// JSON serialization for persistence.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'enabled': enabled,
    if (method != null) 'method': method,
    'urlPattern': urlPattern,
    if (bodyContains != null) 'bodyContains': bodyContains,
    'action': action.toJson(),
  };

  @override
  String toString() =>
      'JalaMockRule(id: $id, name: $name, enabled: $enabled, '
      'method: $method, urlPattern: $urlPattern)';
}

const Object _unset = Object();
