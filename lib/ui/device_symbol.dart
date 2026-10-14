import 'package:flutter/material.dart';
import '../domain/models.dart';
import 'app_theme.dart';
import '../l10n/global_locale_controller.dart';

class RingIllustration extends StatelessWidget {
  const RingIllustration({this.size = 64, super.key});
  final double size;
  @override
  Widget build(BuildContext context) => Semantics(
    label: context.l10n.smartRing,
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _RingPainter()),
    ),
  );
}

class _RingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-.4);
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: size.width * .66,
      height: size.height * .82,
    );
    canvas.drawOval(
      rect.shift(const Offset(4, 6)),
      Paint()
        ..color = const Color(0x55000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * .19,
    );
    canvas.drawOval(
      rect,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFE9DECB), Color(0xFF74666B), Color(0xFFDED2BB)],
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * .15,
    );
    canvas.drawOval(
      rect.deflate(size.width * .075),
      Paint()
        ..color = SaydianColors.brandRed
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawCircle(
      Offset(size.width * .19, -size.height * .23),
      3,
      Paint()..color = const Color(0xFFFF607B),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) => false;
}

class WearableDeviceSymbol extends StatelessWidget {
  const WearableDeviceSymbol({
    this.device,
    this.size = 32,
    this.color = Colors.white,
    super.key,
  });
  final DeviceInfo? device;
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) => device?.isRing == true
      ? Semantics(
          label: context.l10n.smartRing,
          child: RingIllustration(size: size),
        )
      : Icon(
          device == null || device!.sdkSource == WearableSdkSource.unknown
              ? Icons.devices_other_rounded
              : Icons.watch_rounded,
          size: size,
          color: color,
          semanticLabel: context.l10n.deviceLabel,
        );
}
