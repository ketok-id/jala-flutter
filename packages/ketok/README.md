# ketok

Facade package for Ketok, the in-app Flutter network inspector —
`Ketok.initialize()` plus `KetokOverlay` wire up capture, storage, and the
inspector UI in two lines.

See the [repo README](../../README.md) for the full pitch (replay, filter
grammar, redaction-by-default), the comparison vs. alice/chucker_flutter/
talker, and the roadmap.

## Quick start

```yaml
dependencies:
  ketok: ^0.1.0
  ketok_dio: ^0.1.0   # if you use Dio
  dio: ^5.0.0
```

```dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:ketok/ketok.dart';
import 'package:ketok_dio/ketok_dio.dart';

void main() {
  Ketok.initialize(); // enabled: kDebugMode by default
  final dio = Dio();
  KetokDio.attach(dio);
  runApp(KetokOverlay(child: MyApp(dio: dio)));
}
```

Tap the floating **K** bubble (or call `Ketok.open()`) to inspect traffic.
`enabled` defaults to `kDebugMode`, and `KetokOverlay` returns `child`
unchanged when disabled — see the [repo README](../../README.md#production-safety)
for the full production-safety story.

See [docs/SPEC-v0.1.md](../../docs/SPEC-v0.1.md) for the full v0.1 contract.
