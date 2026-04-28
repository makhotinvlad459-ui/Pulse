import 'dart:math';
import 'package:flutter/material.dart';

class MatrixRain extends StatefulWidget {
  final Color color;
  final double opacity;
  final double speedFactor; // 1.0 = стандартная скорость, меньше – медленнее

  const MatrixRain({
    super.key,
    this.color = Colors.black,
    this.opacity = 0.3,
    this.speedFactor = 0.4, // по умолчанию медленнее
  });

  @override
  State<MatrixRain> createState() => _MatrixRainState();
}

class _MatrixRainState extends State<MatrixRain>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<RainDrop> _drops = [];
  final Random _random = Random();
  int _numberOfColumns = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 50),
    )..addListener(() {
        setState(() {
          _updateDrops();
        });
      });
    _controller.repeat();
  }

  void _updateDrops() {
    for (var drop in _drops) {
      drop.y += drop.speed;
      if (drop.y > 1.0) {
        drop.y = -0.1;
        drop.symbol = _random.nextInt(2).toString();
        drop.speed = (0.002 + _random.nextDouble() * 0.004) * widget.speedFactor;
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final size = MediaQuery.of(context).size;
    final newColumns = (size.width / 20).ceil();
    if (_numberOfColumns != newColumns) {
      _numberOfColumns = newColumns;
      _drops.clear();
      final stepX = size.width / _numberOfColumns;
      for (int i = 0; i < _numberOfColumns; i++) {
        _drops.add(RainDrop(
          x: i * stepX,
          y: _random.nextDouble(),
          symbol: _random.nextInt(2).toString(),
          speed: (0.002 + _random.nextDouble() * 0.004) * widget.speedFactor,
        ));
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _MatrixPainter(
        drops: _drops,
        color: widget.color,
        opacity: widget.opacity,
      ),
      size: Size.infinite,
    );
  }
}

class RainDrop {
  double x;
  double y;
  String symbol;
  double speed;
  RainDrop({
    required this.x,
    required this.y,
    required this.symbol,
    required this.speed,
  });
}

class _MatrixPainter extends CustomPainter {
  final List<RainDrop> drops;
  final Color color;
  final double opacity;

  _MatrixPainter({
    required this.drops,
    required this.color,
    required this.opacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final textStyle = TextStyle(
      color: color.withOpacity(opacity),
      fontSize: 14,
      fontWeight: FontWeight.bold,
      fontFamily: 'monospace',
    );
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (var drop in drops) {
      textPainter.text = TextSpan(text: drop.symbol, style: textStyle);
      textPainter.layout();
      textPainter.paint(canvas, Offset(drop.x, drop.y * size.height));
    }
  }

  @override
  bool shouldRepaint(covariant _MatrixPainter oldDelegate) => true;
}