part of 'pages.dart';

class RingDeviceHero extends StatelessWidget {
  const RingDeviceHero({required this.controller, super.key});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final device = controller.connectedDevice;
    if (device == null || !device.isRing) return const SizedBox.shrink();
    final family = device.sdkSource == WearableSdkSource.coolwear
        ? 'LuckRing'
        : device.sdkSource == WearableSdkSource.qring
        ? 'QRing'
        : context.l10n.smartRing;
    return Card(
      key: const Key('ring-device-hero'),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            const RingIllustration(size: 72),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(family, style: Theme.of(context).textTheme.labelLarge),
                  Text(
                    device.name,
                    style: Theme.of(context).textTheme.titleLarge,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(context.l10n.connectionState(controller.deviceState)),
                  const SizedBox(height: 8),
                  _BatteryBadge(
                    device: device,
                    battery: device.effectiveBattery,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String wearableDeviceText(AppController controller, String text) =>
    controller.devicePresentationDevice?.isRing == true
    ? text
          .replaceAll('手表', '戒指')
          .replaceAll('Watch', 'Ring')
          .replaceAll('watch', 'ring')
    : text;
