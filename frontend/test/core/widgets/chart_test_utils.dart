import 'package:flutter/painting.dart';

/// Whether [box] covers any point of [points] or any stretch of the line
/// joining them, sampled every pixel or so.
bool touchesLine(Rect box, List<Offset> points) {
  for (var i = 0; i < points.length; i++) {
    if (box.contains(points[i])) return true;
    if (i == 0) continue;
    final a = points[i - 1];
    final b = points[i];
    final steps = (b - a).distance.ceil();
    for (var s = 0; s <= steps; s++) {
      if (box.contains(Offset.lerp(a, b, s / steps)!)) return true;
    }
  }
  return false;
}
