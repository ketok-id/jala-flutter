import 'package:jala_core/jala_core.dart';
import 'package:test/test.dart';

void main() {
  group('JalaJsonDiff', () {
    JsonDiffNode? childNamed(JsonDiffNode node, String key) {
      for (final JsonDiffNode child in node.children) {
        if (child.key == key) return child;
      }
      return null;
    }

    test('identical values produce an all-unchanged tree', () {
      final JsonDiffNode root = JalaJsonDiff.diff(
        <String, Object?>{
          'id': 1,
          'nested': <String, Object?>{'flag': true},
        },
        <String, Object?>{
          'id': 1,
          'nested': <String, Object?>{'flag': true},
        },
      );
      expect(root.kind, JsonDiffKind.unchanged);
      expect(root.hasChanges, isFalse);
      expect(childNamed(root, 'id')!.kind, JsonDiffKind.unchanged);
      expect(childNamed(root, 'nested')!.kind, JsonDiffKind.unchanged);
    });

    test('an added key is marked added and bubbles a changed root', () {
      final JsonDiffNode root = JalaJsonDiff.diff(
        <String, Object?>{'a': 1},
        <String, Object?>{'a': 1, 'b': 2},
      );
      expect(root.kind, JsonDiffKind.changed);
      expect(childNamed(root, 'a')!.kind, JsonDiffKind.unchanged);
      final JsonDiffNode added = childNamed(root, 'b')!;
      expect(added.kind, JsonDiffKind.added);
      expect(added.after, 2);
      expect(added.before, isNull);
    });

    test('a removed key is marked removed with its before value', () {
      final JsonDiffNode root = JalaJsonDiff.diff(
        <String, Object?>{'a': 1, 'b': 2},
        <String, Object?>{'a': 1},
      );
      final JsonDiffNode removed = childNamed(root, 'b')!;
      expect(removed.kind, JsonDiffKind.removed);
      expect(removed.before, 2);
      expect(removed.after, isNull);
    });

    test('a changed primitive carries both before and after', () {
      final JsonDiffNode root = JalaJsonDiff.diff(
        <String, Object?>{'a': 1},
        <String, Object?>{'a': 2},
      );
      final JsonDiffNode changed = childNamed(root, 'a')!;
      expect(changed.kind, JsonDiffKind.changed);
      expect(changed.before, 1);
      expect(changed.after, 2);
    });

    test('nested changes recurse and mark every ancestor changed', () {
      final JsonDiffNode root = JalaJsonDiff.diff(
        <String, Object?>{
          'user': <String, Object?>{'name': 'x'},
        },
        <String, Object?>{
          'user': <String, Object?>{'name': 'y'},
        },
      );
      expect(root.kind, JsonDiffKind.changed);
      final JsonDiffNode user = childNamed(root, 'user')!;
      expect(user.kind, JsonDiffKind.changed);
      expect(childNamed(user, 'name')!.kind, JsonDiffKind.changed);
    });

    test('a present explicit null is distinct from an absent key', () {
      final JsonDiffNode root = JalaJsonDiff.diff(
        <String, Object?>{'a': null},
        <String, Object?>{'a': null},
      );
      expect(childNamed(root, 'a')!.kind, JsonDiffKind.unchanged);

      final JsonDiffNode nulled = JalaJsonDiff.diff(
        <String, Object?>{'a': 1},
        <String, Object?>{'a': null},
      );
      expect(childNamed(nulled, 'a')!.kind, JsonDiffKind.changed);
    });

    test('lists diff positionally; a longer list marks the extra index added',
        () {
      final JsonDiffNode root = JalaJsonDiff.diff(
        <Object?>[1, 2],
        <Object?>[1, 2, 3],
      );
      expect(root.kind, JsonDiffKind.changed);
      expect(childNamed(root, '[0]')!.kind, JsonDiffKind.unchanged);
      expect(childNamed(root, '[1]')!.kind, JsonDiffKind.unchanged);
      final JsonDiffNode extra = childNamed(root, '[2]')!;
      expect(extra.kind, JsonDiffKind.added);
      expect(extra.after, 3);
    });

    test('a shorter list marks the dropped index removed', () {
      final JsonDiffNode root = JalaJsonDiff.diff(
        <Object?>[1, 2, 3],
        <Object?>[1, 2],
      );
      expect(childNamed(root, '[2]')!.kind, JsonDiffKind.removed);
      expect(childNamed(root, '[2]')!.before, 3);
    });

    test('a type change is a single changed leaf, not a recursion', () {
      final JsonDiffNode root = JalaJsonDiff.diff(
        <String, Object?>{'a': 1},
        <String, Object?>{
          'a': <Object?>[1],
        },
      );
      final JsonDiffNode changed = childNamed(root, 'a')!;
      expect(changed.kind, JsonDiffKind.changed);
      expect(changed.children, isEmpty);
      expect(changed.before, 1);
      expect(changed.after, <Object?>[1]);
    });
  });
}
