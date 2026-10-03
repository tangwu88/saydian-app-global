import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saydian_app/domain/models.dart';
import 'package:saydian_app/services/api_client.dart';
import 'package:saydian_app/services/app_controller.dart';
import 'package:saydian_app/services/local_health_store.dart';
import 'package:saydian_app/services/secure_vault.dart';
import 'package:saydian_app/services/wearable_bridge.dart';
import 'package:saydian_app/ui/device_details_refresh.dart';

class _Api extends Fake implements SaydianApi {}

class _Wearable extends Fake implements WearableBridge {
  @override
  Stream<WearableEvent> get events => const Stream.empty();
}

class _Controller extends AppController {
  _Controller()
    : super(MemorySessionVault(), _Api(), MemoryHealthStore(), _Wearable()) {
    connectedDevice = const DeviceInfo(id: 'synthetic', name: 'QA');
    selectedTab = 1;
  }
  int reads = 0;
  Completer<bool>? pending;
  @override
  Future<bool> refreshConnectedDeviceDetails({bool forceRefresh = false}) {
    expect(forceRefresh, isTrue);
    reads++;
    return pending?.future ?? Future.value(true);
  }

  void select(int value) {
    selectedTab = value;
    notifyListeners();
  }
}

void main() {
  testWidgets(
    'visible status refresh coalesces, pauses off tab and background, stops after disposal',
    (tester) async {
      final controller = _Controller();
      addTearDown(controller.dispose);
      controller.pending = Completer<bool>();
      await tester.pumpWidget(
        MaterialApp(
          home: DeviceDetailsRefresh(
            controller: controller,
            deviceTab: true,
            child: ListView(children: const [Text('QA')]),
          ),
        ),
      );
      expect(controller.reads, 1);
      await tester.pump(const Duration(seconds: 20));
      expect(controller.reads, 1);
      controller.pending!.complete(true);
      controller.pending = null;
      await tester.pump();
      await tester.pump(const Duration(seconds: 10));
      expect(controller.reads, 2);
      controller.select(0);
      await tester.pump(const Duration(seconds: 20));
      expect(controller.reads, 2);
      controller.select(1);
      await tester.pump();
      expect(controller.reads, 3);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 20));
      expect(controller.reads, 3);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(controller.reads, 4);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 20));
      expect(controller.reads, 4);
    },
  );
}
