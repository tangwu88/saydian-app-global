import 'package:flutter/material.dart';

class SaydianBrandLockup extends StatelessWidget {
  const SaydianBrandLockup({super.key, this.width = 190});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'SAYDIAN Health',
      excludeSemantics: true,
      child: SizedBox(
        width: width,
        child: Row(
          children: [
            SaydianBrandMark(size: width * .28),
            SizedBox(width: width * .06),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'SAYDIAN',
                      style: TextStyle(
                        fontSize: width * .16,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF17191C),
                        letterSpacing: -.5,
                      ),
                    ),
                  ),
                  Text(
                    'Health',
                    style: TextStyle(
                      fontSize: width * .09,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF5D646B),
                    ),
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

class SaydianBrandMark extends StatelessWidget {
  const SaydianBrandMark({super.key, this.size = 44});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/branding/saidian-brand-mark.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      semanticLabel: 'SAYDIAN Health',
    );
  }
}
