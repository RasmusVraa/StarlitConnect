import 'package:starlit_connect/starlit/theme.dart';
import 'package:flutter/widgets.dart';

/// Металлический знак Starlit (луна).
class StarlitLogo extends StatelessWidget {
  const StarlitLogo({
    super.key,
    this.size = 40,
    this.showWordmark = false,
    this.muted = false,
  });

  final double size;
  final bool showWordmark;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final mark = SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _MetallicMarkPainter(muted: muted),
      ),
    );
    if (!showWordmark) return mark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        SizedBox(width: size * 0.28),
        Text(
          'Starlit',
          style: TextStyle(
            color: muted ? StarlitColors.muted : StarlitColors.text,
            fontSize: size * 0.42,
            fontWeight: FontWeight.w800,
            fontFamily: 'Manrope',
            letterSpacing: -0.4,
          ),
        ),
      ],
    );
  }
}

class _MetallicMarkPainter extends CustomPainter {
  _MetallicMarkPainter({required this.muted});

  final bool muted;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.shortestSide / 2;

    if (!muted) {
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..color = StarlitColors.accent.withValues(alpha: 0.28)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
    }

    final disc = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.45, -0.55),
        radius: 1.05,
        colors: muted
            ? const [Color(0xFF3A3145), Color(0xFF1E1828), Color(0xFF14101A)]
            : const [
                Color(0xFFF5C6E4),
                Color(0xFFE891C4),
                Color(0xFF9B6AD4),
                Color(0xFF4A2F6E),
              ],
        stops: const [0, 0.28, 0.72, 1],
      ).createShader(Rect.fromCircle(center: c, radius: r));
    canvas.drawCircle(c, r * 0.96, disc);

    canvas.drawCircle(
      c,
      r * 0.96,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.045
        ..shader = const SweepGradient(
          colors: [
            Color(0x8CFFFFFF),
            Color(0x14FFFFFF),
            Color(0x59000000),
            Color(0x59FFFFFF),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );

    final markColor = muted ? StarlitColors.muted2 : const Color(0xFF1A1024);
    final outer = Path()
      ..addOval(
        Rect.fromCircle(
          center: Offset(c.dx - r * 0.04, c.dy),
          radius: r * 0.42,
        ),
      );
    final cut = Path()
      ..addOval(
        Rect.fromCircle(
          center: Offset(c.dx + r * 0.18, c.dy - r * 0.04),
          radius: r * 0.36,
        ),
      );
    final moon = Path.combine(PathOperation.difference, outer, cut);

    canvas.drawPath(
      moon.shift(Offset(r * 0.02, r * 0.03)),
      Paint()
        ..color = const Color(0x59000000)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.04),
    );
    canvas.drawPath(moon, Paint()..color = markColor);

    canvas.drawCircle(
      Offset(c.dx + r * 0.32, c.dy - r * 0.28),
      r * 0.055,
      Paint()
        ..color = muted
            ? StarlitColors.muted.withValues(alpha: 0.4)
            : const Color(0xD9FFFFFF),
    );

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(c.dx - r * 0.28, c.dy - r * 0.32),
        width: r * 0.55,
        height: r * 0.28,
      ),
      Paint()
        ..shader = RadialGradient(
          colors: [
            Color(muted ? 0x14FFFFFF : 0x59FFFFFF),
            const Color(0x00FFFFFF),
          ],
        ).createShader(
          Rect.fromCircle(
            center: Offset(c.dx - r * 0.28, c.dy - r * 0.32),
            radius: r * 0.4,
          ),
        ),
    );
  }

  @override
  bool shouldRepaint(covariant _MetallicMarkPainter oldDelegate) =>
      oldDelegate.muted != muted;
}

enum StarlitNavGlyph { vpn, mode, profile }

String starlitNavAsset(StarlitNavGlyph glyph) => switch (glyph) {
  StarlitNavGlyph.vpn => 'shield',
  StarlitNavGlyph.mode => 'arrow-left-right',
  StarlitNavGlyph.profile => 'settings-2',
};
