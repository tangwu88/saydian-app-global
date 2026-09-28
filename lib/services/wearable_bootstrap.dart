import 'wearable_bridge.dart';
import 'wearable_routing.dart';
import 'urion_wearable_bridge.dart';
import 'yucheng_wearable_bridge.dart';

WearableBridge createProductionWearableBridge({
  WearableBridge? veepoo,
  WearableBridge? yucheng,
  WearableBridge? urion,
}) => RoutedWearableBridge(
  veepoo: veepoo ?? MethodChannelWearableBridge(),
  yucheng: yucheng ?? YuchengWearableBridge(),
  urion: urion ?? UrionWearableBridge(),
  restoreOnlyBoundDevice: true,
);
