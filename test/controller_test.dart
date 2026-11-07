import 'package:beatcast/core/models/broadcast_models.dart';
import 'package:beatcast/core/state/broadcast_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('start requests permissions and starts the broadcast', () async {
    final gateway = FakeGateway(
      bootstrap: const Bootstrap(
        permissions: PermissionState(
          sensorGranted: false,
          backgroundSensorGranted: false,
          bluetoothGranted: false,
          notificationsGranted: false,
        ),
        bluetoothEnabled: true,
      ),
    );
    final controller = BroadcastController(gateway);
    await controller.initialize();

    final started = await controller.start();

    expect(started, isTrue);
    expect(gateway.coreRequests, 1);
    expect(gateway.backgroundRequests, 1);
    expect(gateway.startCalls, 1);
    expect(controller.isRunning, isTrue);
    expect(controller.errorCode, isNull);
    controller.dispose();
  });

  test('blocks start when Bluetooth is disabled', () async {
    final gateway = FakeGateway(
      bootstrap: const Bootstrap(
        permissions: PermissionState(
          sensorGranted: true,
          backgroundSensorGranted: true,
          bluetoothGranted: true,
          notificationsGranted: true,
        ),
        bluetoothEnabled: false,
      ),
    );
    final controller = BroadcastController(gateway);
    await controller.initialize();

    final started = await controller.start();

    expect(started, isFalse);
    expect(controller.errorCode, 'bluetooth_off');
    expect(gateway.startCalls, 0);
    controller.dispose();
  });

  test('records the background permission when it is not grantable', () async {
    final gateway = FakeGateway(
      bootstrap: const Bootstrap(
        permissions: PermissionState(
          sensorGranted: true,
          backgroundSensorGranted: false,
          bluetoothGranted: true,
          notificationsGranted: true,
        ),
        bluetoothEnabled: true,
      ),
    );
    gateway.grantBackground = false;
    final controller = BroadcastController(gateway);
    await controller.initialize();

    final started = await controller.start();

    expect(started, isFalse);
    expect(controller.errorCode, 'background_permission');
    controller.dispose();
  });

  test('settings update is applied optimistically and persisted', () async {
    final gateway = FakeGateway();
    final controller = BroadcastController(gateway);
    await controller.initialize();

    await controller.updateSettings(
      controller.settings.copyWith(
        advertisingMode: AdvertisingMode.lowPower,
        autoStopMinutes: 30,
      ),
    );

    expect(controller.settings.advertisingMode, AdvertisingMode.lowPower);
    expect(controller.settings.autoStopMinutes, 30);
    expect(gateway.settingsUpdates, 1);
    controller.dispose();
  });

  testWidgets('first launch automatically requests missing permissions',
      (tester) async {
    final gateway = FakeGateway(
      bootstrap: const Bootstrap(
        permissions: PermissionState(),
        bluetoothEnabled: true,
        firstPermissionRun: true,
      ),
    );
    final controller = BroadcastController(gateway);
    await controller.initialize();
    await tester.pump();
    await tester.pumpAndSettle();

    expect(gateway.coreRequests, 1);
    expect(gateway.permissionsPromptedCalls, 1);
    controller.dispose();
  });
}
