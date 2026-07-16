# jala

Facade package for Jala, the in-app Flutter network inspector —
`Jala.initialize()` plus `JalaOverlay` wire up capture, storage, and the
inspector UI in two lines.

See the [repo README](../../README.md) for the full pitch (replay, filter
grammar, redaction-by-default), the comparison vs. alice/chucker_flutter/
talker, and the roadmap.

## Quick start

```yaml
dependencies:
  jala: ^0.3.0
  jala_dio: ^0.3.0   # if you use Dio
  dio: ^5.0.0
```

```dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:jala/jala.dart';
import 'package:jala_dio/jala_dio.dart';

void main() {
  Jala.initialize(); // enabled: kDebugMode by default
  final dio = Dio();
  JalaDio.attach(dio);
  runApp(JalaOverlay(child: MyApp(dio: dio)));
}
```

Tap the floating **J** bubble (or call `Jala.open()`) to inspect traffic.
`enabled` defaults to `kDebugMode`, and `JalaOverlay` returns `child`
unchanged when disabled — see the [repo README](../../README.md#production-safety)
for the full production-safety story.

See [docs/SPEC-v0.1.md](../../docs/SPEC-v0.1.md) for the full v0.1 contract.
