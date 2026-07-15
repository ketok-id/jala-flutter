import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jala/jala.dart';
import 'package:jala_example/main.dart';

void main() {
  tearDown(() async {
    Jala.resetControllerForTesting();
    await JalaBinding.resetForTesting();
  });

  testWidgets('example app renders QA buttons', (WidgetTester tester) async {
    Jala.initialize(config: JalaConfig(enabled: true));
    final Dio dio = Dio();
    await tester.pumpWidget(JalaOverlay(child: JalaExampleApp(dio: dio)));
    await tester.pump();

    expect(find.text('Jala QA Rig'), findsOneWidget);
    expect(find.text('GET json'), findsOneWidget);
    expect(find.text('J'), findsOneWidget);
  });
}
