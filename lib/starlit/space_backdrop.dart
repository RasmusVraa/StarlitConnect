import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// Animated starfield + rare comets for the whole Starlit shell.
class StarlitSpaceBackdrop extends StatefulWidget {
  const StarlitSpaceBackdrop({super.key});

  @override
  State<StarlitSpaceBackdrop> createState() => _StarlitSpaceBackdropState();
}

class _StarlitSpaceBackdropState extends State<StarlitSpaceBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _space;

  @override
  void initState() {
    super.initState();
    _space = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 48),
    )..repeat();
  }

  @override
  void dispose() {
    _space.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _space,
      builder: (context, _) => CustomPaint(
        painter: _SpacePainter(
          spaceT: _space.value * 48,
          breath: 0.5 + 0.5 * math.sin(_space.value * math.pi * 2),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _Star {
  const _Star({
    required this.x,
    required this.y,
    required this.size,
    required this.phase,
    required this.speed,
    required this.color,
    required this.base,
  });

  final double x;
  final double y;
  final double size;
  final double phase;
  final double speed;
  final Color color;
  final double base;
}

final List<_Star> _kStars = () {
  final rng = math.Random(42);
  const palette = <Color>[
    Color(0xFFF5F3FF),
    Color(0xFFDCE7FF),
    Color(0xFFFFF1D6),
    Color(0xFFE4D4FF),
    Color(0xFFC8F0FF),
    Color(0xFFFFD6E8),
  ];
  return [
    for (var i = 0; i < 220; i++)
      _Star(
        x: rng.nextDouble(),
        y: rng.nextDouble(),
        size: 0.45 + rng.nextDouble() * (i % 11 == 0 ? 2.4 : 1.35),
        phase: rng.nextDouble() * math.pi * 2,
        speed: 0.55 + rng.nextDouble() * 1.8,
        color: palette[rng.nextInt(palette.length)],
        base: 0.28 + rng.nextDouble() * 0.55,
      ),
  ];
}();

class _SpacePainter extends CustomPainter {
  const _SpacePainter({required this.spaceT, required this.breath});

  final double spaceT;
  final double breath;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(size.width * 0.15, 0),
          Offset(size.width * 0.85, size.height),
          const [
            Color(0xFF070510),
            Color(0xFF0C0818),
            Color(0xFF05040C),
            Color(0xFF0A0614),
          ],
          const [0, 0.35, 0.7, 1],
        ),
    );

    canvas.drawCircle(
      Offset(size.width * 0.22, size.height * 0.28),
      size.shortestSide * 0.42,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Color.lerp(
              const Color(0x18402A6A),
              const Color(0x224B2F7A),
              breath,
            )!,
            const Color(0x00000000),
          ],
        ).createShader(
          Rect.fromCircle(
            center: Offset(size.width * 0.22, size.height * 0.28),
            radius: size.shortestSide * 0.42,
          ),
        ),
    );
    canvas.drawCircle(
      Offset(size.width * 0.78, size.height * 0.72),
      size.shortestSide * 0.38,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Color.lerp(
              const Color(0x122A4A78),
              const Color(0x1A356090),
              1 - breath,
            )!,
            const Color(0x00000000),
          ],
        ).createShader(
          Rect.fromCircle(
            center: Offset(size.width * 0.78, size.height * 0.72),
            radius: size.shortestSide * 0.38,
          ),
        ),
    );
    canvas.drawCircle(
      Offset(size.width * 0.55, size.height * 0.12),
      size.shortestSide * 0.3,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Color.lerp(
              const Color(0x14E891C4),
              const Color(0x1AB794E8),
              breath,
            )!,
            const Color(0x00000000),
          ],
        ).createShader(
          Rect.fromCircle(
            center: Offset(size.width * 0.55, size.height * 0.12),
            radius: size.shortestSide * 0.3,
          ),
        ),
    );

    final starPaint = Paint()..style = PaintingStyle.fill;
    for (final star in _kStars) {
      final twinkle =
          0.45 +
          0.55 * (0.5 + 0.5 * math.sin(spaceT * star.speed + star.phase));
      final alpha = (star.base * twinkle).clamp(0.12, 0.95);
      final o = Offset(star.x * size.width, star.y * size.height);
      starPaint.color = star.color.withValues(alpha: alpha);
      canvas.drawCircle(o, star.size * (0.85 + 0.25 * twinkle), starPaint);
      if (star.size > 1.7 && twinkle > 0.72) {
        starPaint.color = star.color.withValues(alpha: alpha * 0.35);
        canvas.drawCircle(o, star.size * 2.1, starPaint);
      }
    }

    _paintComet(canvas, size);
  }

  void _paintComet(Canvas canvas, Size size) {
    const period = 13.0;
    const life = 1.35;
    final cycle = (spaceT / period).floor();
    final local = spaceT - cycle * period;
    if (local < 0.12 || local > life) return;

    final rng = math.Random(9000 + cycle);
    if (rng.nextDouble() < 0.42) return;

    final t = ((local - 0.12) / (life - 0.12)).clamp(0.0, 1.0);
    final ease = Curves.easeInOut.transform(t);
    final fromLeft = cycle.isEven;
    final y0 = 0.12 + rng.nextDouble() * 0.55;
    final y1 = y0 + (rng.nextDouble() - 0.5) * 0.28;
    final x0 = fromLeft ? -0.08 : 1.08;
    final x1 = fromLeft ? 1.08 : -0.08;
    final head = Offset(
      (x0 + (x1 - x0) * ease) * size.width,
      (y0 + (y1 - y0) * ease) * size.height,
    );
    final dir = Offset(x1 - x0, y1 - y0);
    final len = math.sqrt(dir.dx * dir.dx + dir.dy * dir.dy);
    if (len < 1e-6) return;
    final ux = dir.dx / len;
    final uy = dir.dy / len;
    final tailLen = size.shortestSide * (0.18 + 0.08 * rng.nextDouble());
    final tail = Offset(head.dx - ux * tailLen, head.dy - uy * tailLen);
    final fade = math.sin(math.pi * t);

    canvas.drawLine(
      head,
      tail,
      Paint()
        ..shader = ui.Gradient.linear(
          head,
          tail,
          [
            const Color(0xFFFFFFFF).withValues(alpha: 0.78 * fade),
            const Color(0xFFB8D4FF).withValues(alpha: 0.28 * fade),
            const Color(0x00FFFFFF),
          ],
          const [0, 0.35, 1],
        )
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
    canvas.drawCircle(
      head,
      2.4,
      Paint()
        ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.9 * fade)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawCircle(
      head,
      1.3,
      Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.95 * fade),
    );
  }

  @override
  bool shouldRepaint(covariant _SpacePainter oldDelegate) =>
      oldDelegate.spaceT != spaceT || oldDelegate.breath != breath;
}
