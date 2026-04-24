import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'matrix_rain.dart';
import 'graphite_background.dart';

class AdaptiveBackground extends StatelessWidget {
  final Widget child;
  const AdaptiveBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // Для веба – сразу красивый фон, не используем Platform
    if (kIsWeb) {
      return GraphiteBackground(
        child: Stack(
          children: [
            const MatrixRain(opacity: 0.2),
            child,
          ],
        ),
      );
    }
    // Для нативного Android – простой цвет
    if (Platform.isAndroid) {
      return Container(color: const Color(0xFFF2F2F2), child: child);
    }
    // Для нативной iOS – красивый фон (как веб)
    return GraphiteBackground(
      child: Stack(
        children: [
          const MatrixRain(opacity: 0.2),
          child,
        ],
      ),
    );
  }
}