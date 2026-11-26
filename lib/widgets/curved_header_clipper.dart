import 'package:flutter/material.dart';

class HeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    // Start at top-left, line down to left edge (y = height - 40)
    path.lineTo(0, size.height - 40);

    // Smooth bezier curve:
    // Dips slightly at center-left (y ~ height)
    // Swoops gracefully UP to right edge (y ~ height - 120)
    final controlPoint1 = Offset(size.width * 0.32, size.height + 2);
    final controlPoint2 = Offset(size.width * 0.65, size.height - 50);
    final endPoint = Offset(size.width, size.height - 120);

    path.cubicTo(
      controlPoint1.dx,
      controlPoint1.dy,
      controlPoint2.dx,
      controlPoint2.dy,
      endPoint.dx,
      endPoint.dy,
    );

    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
