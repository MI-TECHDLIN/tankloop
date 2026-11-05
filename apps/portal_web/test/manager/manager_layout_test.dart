import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tankloop_portal/manager_controller.dart';
import 'package:tankloop_portal/manager_shell.dart';
import 'manager_test_support.dart';

void main() {
  for (final size in [const Size(320, 740), const Size(1440, 1000)]) {
    for (var index = 0; index < managerScreenNames.length; index++) {
      testWidgets(
        '${managerScreenNames[index]} list and detail fit ${size.width.toInt()}px at 130% text',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final repository = TestManagerRepository();
          final controller = ManagerController(
            repository,
            clock: () => managerNow,
          );
          await controller.refresh();
          await tester.pumpWidget(
            managerTestApp(
              ManagerShell(
                controller: controller,
                selected: index,
                onSelected: (_) {},
              ),
              controller: controller,
              scroll: false,
              textScale: 1.3,
            ),
          );
          await tester.pumpAndSettle();
          expect(managerContent(index, controller.workspace!), findsWidgets);
          expect(tester.takeException(), isNull);
          if ([1, 3, 4, 7].contains(index)) {
            await managerTap(
              tester,
              managerContent(index, controller.workspace!),
            );
            expect(find.text('Back to list'), findsOneWidget);
            expect(tester.takeException(), isNull);
            await managerTap(tester, find.text('Back to list'));
            expect(managerContent(index, controller.workspace!), findsWidgets);
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
