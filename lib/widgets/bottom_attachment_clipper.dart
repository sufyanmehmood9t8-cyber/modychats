import 'package:flutter/material.dart';

class BottomAttachmentClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    // Start at top-left edge (0, 35)
    path.moveTo(0, 35);

    // Smooth wave curve across the top edge
    final controlPoint1 = Offset(size.width * 0.35, -10);
    final controlPoint2 = Offset(size.width * 0.65, 45);
    final endPoint = Offset(size.width, 10);

    path.cubicTo(
      controlPoint1.dx,
      controlPoint1.dy,
      controlPoint2.dx,
      controlPoint2.dy,
      endPoint.dx,
      endPoint.dy,
    );

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
