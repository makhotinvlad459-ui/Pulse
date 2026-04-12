import 'dart:math';
import 'package:flutter/material.dart';

class ECGWidget extends StatefulWidget {
  final Color color;
  final double width;
  final double height;
  const ECGWidget({
    super.key,
    this.color = Colors.white,
    this.width = double.infinity,
    this.height = 100,
  });

  @override
  State<ECGWidget> createState() => _ECGWidgetState();
}

class _ECGWidgetState extends State<ECGWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _offset = 0.0;

  // Генерация точек для одного периода ЭКГ (реалистичная кардиограмма)
  List<Offset> _generateECGPoints(double width, double height) {
    final points = <Offset>[];
    final step = width / 300; // высокое разрешение
    for (double x = 0; x <= width; x += step) {
      double y;
      double t = x / width; // нормализуем 0..1
      // Эмулируем комплекс QRST
      if (t < 0.1) {
        y = height * 0.6; // базовая линия
      } else if (t < 0.15) {
        double p = (t - 0.1) / 0.05;
        y = height * (0.6 - p * 0.2); // небольшой подъём (зубец P)
      } else if (t < 0.2) {
        y = height * 0.4;
      } else if (t < 0.25) {
        double p = (t - 0.2) / 0.05;
        y = height * (0.4 - p * 0.8); // острый пик QRS вверх
      } else if (t < 0.3) {
        double p = (t - 0.25) / 0.05;
        y = height * (-0.4 + p * 1.0); // возврат к базе
      } else if (t < 0.35) {
        double p = (t - 0.3) / 0.05;
        y = height * (0.6 + p * 0.2); // зубец S вниз
      } else if (t < 0.4) {
        double p = (t - 0.35) / 0.05;
        y = height * (0.8 - p * 0.2); // возврат
      } else if (t < 0.7) {
        y = height * 0.6; // диастола
      } else {
        // следующий комплекс
        double nt = (t - 0.7) / 0.3;
        if (nt < 0.1) {
          y = height * 0.6;
        } else if (nt < 0.15) {
          double p = (nt - 0.1) / 0.05;
          y = height * (0.6 - p * 0.2);
        } else if (nt < 0.2) {
          y = height * 0.4;
        } else if (nt < 0.25) {
          double p = (nt - 0.2) / 0.05;
          y = height * (0.4 - p * 0.8);
        } else if (nt < 0.3) {
          double p = (nt - 0.25) / 0.05;
          y = height * (-0.4 + p * 1.0);
        } else if (nt < 0.35) {
          double p = (nt - 0.3) / 0.05;
          y = height * (0.6 + p * 0.2);
        } else if (nt < 0.4) {
          double p = (nt - 0.35) / 0.05;
          y = height * (0.8 - p * 0.2);
        } else {
          y = height * 0.6;
        }
      }
      points.add(Offset(x, y));
    }
    return points;
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _controller.addListener(() {
      setState(() {
        // Бесконечный сдвиг: от 0 до width, потом сброс (но для плавности используем модуль)
        _offset = (_controller.value * widget.width) % widget.width;
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: CustomPaint(
        painter: _ECGPainter(
          points: _generateECGPoints(widget.width, widget.height),
          offset: _offset,
          color: widget.color,
        ),
      ),
    );
  }
}

class _ECGPainter extends CustomPainter {
  final List<Offset> points;
  final double offset;
  final Color color;

  _ECGPainter(
      {required this.points, required this.offset, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    // Создаём несколько слоёв свечения с размытием и разной прозрачностью
    // В методе paint() увеличьте ширину и добавьте яркое свечение
    final layers = [
      Paint()
        ..color = color.withOpacity(0.2)
        ..strokeWidth = 12
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      Paint()
        ..color = color.withOpacity(0.5)
        ..strokeWidth = 5
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke,
    ];
    // Строим расширенный список точек (2 копии для бесконечного сдвига)
    final extendedPoints = <Offset>[];
    for (int i = 0; i < 2; i++) {
      for (var p in points) {
        extendedPoints.add(Offset(p.dx + i * size.width, p.dy));
      }
    }

    final startX = offset;
    final endX = startX + size.width;
    final visiblePoints = <Offset>[];
    for (var p in extendedPoints) {
      if (p.dx >= startX && p.dx <= endX) {
        visiblePoints.add(Offset(p.dx - startX, p.dy));
      }
    }

    // Рисуем каждый слой свечения
    for (final paint in layers) {
      for (int i = 0; i < visiblePoints.length - 1; i++) {
        canvas.drawLine(visiblePoints[i], visiblePoints[i + 1], paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ECGPainter oldDelegate) {
    return oldDelegate.offset != offset || oldDelegate.color != color;
  }
}
