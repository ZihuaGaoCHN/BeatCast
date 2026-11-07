import 'package:beatcast/app.dart';
import 'package:beatcast/core/models/broadcast_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

void main() {
  Future<void> pumpWatch(WidgetTester tester, FakeGateway gateway) async {
    tester.view.physicalSize = const Size(384, 384);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.platformDispatcher.localeTestValue = const Locale('en');
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);

    await tester.pumpWidget(BeatCastApp(gateway: gateway));
    await tester.pumpAndSettle();
  }

  testWidgets('starts and stops a broadcast from the watch face', (tester) async {
    final gateway = FakeGateway();
    await pumpWatch(tester, gateway);

    expect(find.text('Start broadcast'), findsOneWidget);
    await tester.tap(find.text('Start broadcast'));
    await tester.pumpAndSettle();

    expect(gateway.startCalls, 1);
    expect(find.text('Stop broadcast'), findsOneWidget);

    await tester.tap(find.text('Stop broadcast'));
    await tester.pumpAndSettle();

    expect(gateway.stopCalls, 1);
    expect(find.text('Start broadcast'), findsOneWidget);
  });

  testWidgets('opens settings and updates auto-stop', (tester) async {
    final gateway = FakeGateway();
    await pumpWatch(tester, gateway);

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Stop when idle'), findsOneWidget);
    await tester.tap(find.text('Stop when idle'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('30 min'), 80);
    await tester.tap(find.text('30 min'));
    await tester.pumpAndSettle();

    expect(gateway.settingsUpdates, 1);
    expect(gateway.boot.settings.autoStopMinutes, 30);
  });

  testWidgets('permission flow unlocks broadcasting', (tester) async {
    final gateway = FakeGateway(
      bootstrap: const Bootstrap(
        permissions: PermissionState(
          sensorGranted: false,
          backgroundSensorGranted: false,
          bluetoothGranted: false,
          notificationsGranted: false,
        ),
        bluetoothEnabled: true,
        advertisingSupported: true,
      ),
    );
    await pumpWatch(tester, gateway);

    expect(find.text('Set up & start'), findsOneWidget);
    await tester.tap(find.text('Set up & start'));
    await tester.pumpAndSettle();

    expect(gateway.coreRequests, 1);
    expect(gateway.backgroundRequests, 1);
    expect(gateway.startCalls, 1);
    expect(find.text('Stop broadcast'), findsOneWidget);
  });

  testWidgets('fits a 227dp round watch', (tester) async {
    tester.view.physicalSize = const Size(454, 454);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.platformDispatcher.localeTestValue = const Locale('en');
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);

    final gateway = FakeGateway();
    await tester.pumpWidget(BeatCastApp(gateway: gateway));
    await tester.pumpAndSettle();

    expect(find.text('Start broadcast'), findsOneWidget);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Stop when idle'), findsOneWidget);

    await tester.tap(find.text('Stop when idle'));
    await tester.pumpAndSettle();
    expect(find.text('30 min'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
