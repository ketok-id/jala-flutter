import 'package:flutter_test/flutter_test.dart';
import 'package:ketok_ui/ketok_ui.dart';

void main() {
  test('cycle() rotates system -> light -> dark -> system', () {
    final KetokThemeController controller = KetokThemeController();
    expect(controller.mode, KetokThemeMode.system);

    controller.cycle();
    expect(controller.mode, KetokThemeMode.light);

    controller.cycle();
    expect(controller.mode, KetokThemeMode.dark);

    controller.cycle();
    expect(controller.mode, KetokThemeMode.system);
  });

  test('setting the same mode does not notify listeners', () {
    final KetokThemeController controller = KetokThemeController();
    var notifications = 0;
    controller.addListener(() => notifications++);

    controller.mode = KetokThemeMode.system;
    expect(notifications, 0);

    controller.mode = KetokThemeMode.dark;
    expect(notifications, 1);
  });
}
