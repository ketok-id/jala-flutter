import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ketok/ketok.dart';
import 'package:ketok_example/main.dart';

void main() {
  tearDown(() async {
    Ketok.resetControllerForTesting();
    await KetokBinding.resetForTesting();
  });

  testWidgets('example app renders QA buttons', (WidgetTester tester) async {
    Ketok.initialize(config: KetokConfig(enabled: true));
    final Dio dio = Dio();
    await tester.pumpWidget(KetokOverlay(child: KetokExampleApp(dio: dio)));
    await tester.pump();

    expect(find.text('Ketok QA Rig'), findsOneWidget);
    expect(find.text('GET json'), findsOneWidget);
    expect(find.text('K'), findsOneWidget);
  });
}
