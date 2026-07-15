import 'package:flutter_test/flutter_test.dart';
import 'package:jala_ui/jala_ui.dart';

void main() {
  test('cycle() rotates system -> light -> dark -> system', () {
    final JalaThemeController controller = JalaThemeController();
    expect(controller.mode, JalaThemeMode.system);

    controller.cycle();
    expect(controller.mode, JalaThemeMode.light);

    controller.cycle();
    expect(controller.mode, JalaThemeMode.dark);

    controller.cycle();
    expect(controller.mode, JalaThemeMode.system);
  });

  test('setting the same mode does not notify listeners', () {
    final JalaThemeController controller = JalaThemeController();
    var notifications = 0;
    controller.addListener(() => notifications++);

    controller.mode = JalaThemeMode.system;
    expect(notifications, 0);

    controller.mode = JalaThemeMode.dark;
    expect(notifications, 1);
  });
}
