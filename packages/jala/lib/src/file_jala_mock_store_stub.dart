import 'package:jala_core/jala_core.dart';

/// Stub for platforms without `dart:io` (e.g. web).
class FileJalaMockStore implements JalaMockStore {
  /// Creates a no-op store. [path] is ignored on this platform.
  FileJalaMockStore(String path);

  @override
  Future<List<JalaMockRule>> load() async => const <JalaMockRule>[];

  @override
  Future<void> save(List<JalaMockRule> rules) async {}
}
