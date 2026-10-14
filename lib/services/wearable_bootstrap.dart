import 'package:flutter/foundation.dart';
import 'coolwear_wearable_bridge.dart';
import 'qring_wearable_bridge.dart';
import 'wearable_bridge.dart';
import 'wearable_routing.dart';
import 'urion_wearable_bridge.dart';
import 'yucheng_wearable_bridge.dart';

WearableBridge createProductionWearableBridge({
  WearableBridge? veepoo,
  WearableBridge? yucheng,
  WearableBridge? urion,
  WearableBridge? coolwear,
  WearableBridge? qring,
}) => RoutedWearableBridge(
  veepoo: veepoo ?? MethodChannelWearableBridge(),
  yucheng: yucheng ?? YuchengWearableBridge(),
  urion: urion ?? UrionWearableBridge(),
  coolwear:
      coolwear ??
      (!kIsWeb &&
              (defaultTargetPlatform == TargetPlatform.android ||
                  defaultTargetPlatform == TargetPlatform.iOS)
          ? CoolWearWearableBridge()
          : null),
  qring:
      qring ??
      (!kIsWeb &&
              (defaultTargetPlatform == TargetPlatform.android ||
                  defaultTargetPlatform == TargetPlatform.iOS)
          ? QRingWearableBridge()
          : null),
  restoreOnlyBoundDevice: true,
);
