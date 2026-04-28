import 'package:flutter/material.dart';

class AnimatedLoader extends StatefulWidget {
  const AnimatedLoader({super.key});

  @override
  State<AnimatedLoader> createState() => _AnimatedLoaderState();
}

class _AnimatedLoaderState extends State<AnimatedLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pushAnimation;
  late Animation<double> _restAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat();

    // Фаза толкания: от 0 до 0.6
    _pushAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeInOut),
      ),
    );
    // Фаза отдыха: от 0.6 до 1.0
    _restAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.6, 1.0, curve: Curves.easeInOut),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final pushProgress = _pushAnimation.value;
        final restProgress = _restAnimation.value;

        // Смещение счёта: от 0 до 30 пикселей, потом возврат
        double moneyOffset = 0;
        bool isResting = false;
        if (pushProgress < 1.0) {
          // Толкание
          moneyOffset = pushProgress * 25;
          isResting = false;
        } else {
          // Отдых
          isResting = true;
          moneyOffset = 25 - restProgress * 5; // немного откатывается
        }

        return CustomPaint(
          size: const Size(280, 130),
          painter: _LittleManPainter(
            moneyOffset: moneyOffset,
            isResting: isResting,
            restProgress: restProgress,
          ),
        );
      },
    );
  }
}

class _LittleManPainter extends CustomPainter {
  final double moneyOffset;
  final bool isResting;
  final double restProgress;

  _LittleManPainter({
    required this.moneyOffset,
    required this.isResting,
    required this.restProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black87
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Человечек находится в левой части (x ~ 60)
    // Параметры позы
    double bodyTilt = 0;
    double legBend = 0;
    double armAngle = 0;
    double sweatOpacity = 0;

    if (!isResting) {
      // Фаза толкания: наклон вперёд, ноги согнуты
      bodyTilt = -10; // наклон влево? Нет, вперёд -> по x: смещение тела вперёд (вправо)
      legBend = 15;
      armAngle = 30;
      sweatOpacity = 0;
    } else {
      // Фаза отдыха: сидит, вытирает пот
      bodyTilt = -25;
      legBend = 30;
      armAngle = -20;
      sweatOpacity = restProgress; // капли пота появляются
    }

    // Голова (круг)
    const headCenter = Offset(60, 30);
    canvas.drawCircle(headCenter, 8, paint);

    // Тело (линия)
    final bodyTop = Offset(60, 38);
    final bodyBottom = Offset(60 + bodyTilt * 0.5, 80);
    canvas.drawLine(bodyTop, bodyBottom, paint);

    // Ноги
    final leftFoot = Offset(50 + legBend * 0.5, 100);
    final rightFoot = Offset(70 + legBend * 0.5, 100);
    canvas.drawLine(bodyBottom, leftFoot, paint);
    canvas.drawLine(bodyBottom, rightFoot, paint);

    // Руки
    final leftHand = Offset(40 + armAngle * 0.5, 60);
    final rightHand = Offset(70 + armAngle, 70);
    canvas.drawLine(bodyTop, leftHand, paint);
    canvas.drawLine(bodyTop, rightHand, paint);

    // Счёт (прямоугольник с деньгами), который толкают
    final boxRect = Rect.fromLTWH(130 + moneyOffset, 45, 45, 35);
    canvas.drawRect(boxRect, paint);
    // Текст "💰"
    final textSpan = TextSpan(text: "💰", style: const TextStyle(fontSize: 18));
    final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
    tp.layout();
    tp.paint(canvas, Offset(135 + moneyOffset, 50));

    // Капли пота (только при отдыхе)
    if (isResting) {
      final sweatPaint = Paint()..color = Colors.blue.withOpacity(0.7 * sweatOpacity);
      canvas.drawCircle(Offset(55, 22), 2, sweatPaint);
      canvas.drawCircle(Offset(50, 26), 1.5, sweatPaint);
      canvas.drawCircle(Offset(65, 20), 2.5, sweatPaint);
    }

    // Лицо: глаза и рот
    canvas.drawCircle(Offset(57, 28), 1.2, paint);
    canvas.drawCircle(Offset(63, 28), 1.2, paint);
    if (isResting) {
      // усталый рот – дуга вниз
      canvas.drawArc(Rect.fromCircle(center: Offset(60, 35), radius: 4), 0, 3.14, false, paint);
    } else {
      // напряжённый рот – прямая линия
      canvas.drawLine(Offset(57, 35), Offset(63, 35), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LittleManPainter oldDelegate) {
    return oldDelegate.moneyOffset != moneyOffset ||
        oldDelegate.isResting != isResting ||
        oldDelegate.restProgress != restProgress;
  }
}