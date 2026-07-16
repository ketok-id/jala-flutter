/// Glob matching shared by mock URL patterns (and available for filter hosts).
///
/// Semantics: `*` matches any sequence of characters (including empty).
/// The pattern is otherwise matched literally after [RegExp.escape] of each
/// non-wildcard segment, and is anchored to the full string (`^…$`).
bool globMatches(String pattern, String value) {
  if (!pattern.contains('*')) {
    return pattern == value;
  }
  final String regexSource =
      '^${pattern.split('*').map(RegExp.escape).join('.*')}\$';
  return RegExp(regexSource).hasMatch(value);
}

/// Case-insensitive [globMatches] (used when matching host-style patterns).
bool globMatchesIgnoreCase(String pattern, String value) {
  return globMatches(pattern.toLowerCase(), value.toLowerCase());
}
