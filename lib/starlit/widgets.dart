import 'dart:math' as math;

import 'package:starlit_connect/starlit/space_backdrop.dart';
import 'package:starlit_connect/starlit/theme.dart';
import 'package:flutter/widgets.dart';

class StarlitScaffold extends StatelessWidget {
  const StarlitScaffold({super.key, required this.child, this.glow = true});

  final Widget child;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return SelectionContainer.disabled(
      child: DefaultTextStyle(
        style: starlitText(),
        child: ColoredBox(
          color: StarlitColors.bg,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const StarlitSpaceBackdrop(),
              if (glow) ...[
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(-0.9, -0.95),
                      radius: 0.85,
                      colors: [Color(0x18E891C4), Color(0x00E891C4)],
                    ),
                  ),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(1.05, 1.05),
                      radius: 0.85,
                      colors: [Color(0x14B794E8), Color(0x00B794E8)],
                    ),
                  ),
                ),
              ],
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class StarlitCard extends StatelessWidget {
  const StarlitCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.highlighted = false,
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final bool highlighted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final box = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: padding,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(StarlitRadii.card),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: highlighted
              ? const [Color(0xCC34283F), Color(0xBB221B2E), Color(0xB31A1424)]
              : const [Color(0xC22B2236), Color(0xB81E1828), Color(0xB016111F)],
        ),
        border: Border.all(
          color: highlighted
              ? StarlitColors.accent.withValues(alpha: 0.5)
              : const Color(0x44FFFFFF),
          width: highlighted ? 1.4 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0x55000000),
            blurRadius: highlighted ? 28 : 18,
            offset: const Offset(0, 10),
          ),
          if (highlighted)
            BoxShadow(
              color: StarlitColors.accent.withValues(alpha: 0.16),
              blurRadius: 24,
            ),
          const BoxShadow(
            color: Color(0x14FFFFFF),
            blurRadius: 0,
            offset: Offset(0, -0.5),
          ),
        ],
      ),
      child: child,
    );
    if (onTap == null) return box;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(onTap: onTap, child: box),
    );
  }
}

class StarlitPrimaryButton extends StatelessWidget {
  const StarlitPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      children: [
        if (icon != null) ...[icon!, const SizedBox(width: 10)],
        StarlitText(
          label,
          color: const Color(0xFF1A1020),
          size: 15,
          weight: FontWeight.w700,
        ),
      ],
    );
    return MouseRegion(
      cursor: onPressed == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onPressed,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 120),
          opacity: onPressed == null ? 0.45 : 1,
          child: Container(
            height: 50,
            width: expand ? double.infinity : null,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(StarlitRadii.pill),
              gradient: LinearGradient(
                colors: [StarlitColors.accent, StarlitColors.accentDeep],
              ),
              boxShadow: [
                BoxShadow(
                  color: StarlitColors.accent.withValues(alpha: 0.22),
                  blurRadius: 16,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: child,
          ),
        ),
      ),
    );
  }
}

class StarlitGhostButton extends StatelessWidget {
  const StarlitGhostButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          height: 50,
          width: double.infinity,
          decoration: BoxDecoration(
            color: StarlitColors.cardHi,
            borderRadius: BorderRadius.circular(StarlitRadii.pill),
            border: Border.all(color: StarlitColors.stroke),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[icon!, const SizedBox(width: 10)],
              StarlitText(
                label,
                size: 15,
                weight: FontWeight.w600,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StarlitGlowIcon extends StatelessWidget {
  const StarlitGlowIcon({super.key, required this.child, this.size = 96});

  final Widget child;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size + 48,
      height: size + 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size + 40,
            height: size + 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  StarlitColors.accent.withValues(alpha: 0.35),
                  StarlitColors.accent.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [StarlitColors.accent, StarlitColors.accentDeep],
              ),
              boxShadow: [
                BoxShadow(
                  color: StarlitColors.accent.withValues(alpha: 0.35),
                  blurRadius: 28,
                ),
              ],
            ),
            child: Center(child: child),
          ),
        ],
      ),
    );
  }
}

class StarlitPageDots extends StatelessWidget {
  const StarlitPageDots({super.key, required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: i == index ? 22 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == index ? StarlitColors.accent : StarlitColors.stroke,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
      ],
    );
  }
}

class StarlitToggle extends StatelessWidget {
  const StarlitToggle({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 48,
          height: 28,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: value
                ? LinearGradient(
                    colors: [StarlitColors.accentDeep, StarlitColors.accent],
                  )
                : const LinearGradient(
                    colors: [Color(0xFF3A3145), Color(0xFF221B2E)],
                  ),
            border: Border.all(
              color: value
                  ? StarlitColors.accent.withValues(alpha: 0.45)
                  : const Color(0x33FFFFFF),
            ),
            boxShadow: value
                ? [
                    BoxShadow(
                      color: StarlitColors.accent.withValues(alpha: 0.33),
                      blurRadius: 12,
                    ),
                  ]
                : const [
                    BoxShadow(
                      color: Color(0x44000000),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
          ),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFFFFF), Color(0xFFD8D0E0)],
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class StarlitMapBackdrop extends StatelessWidget {
  const StarlitMapBackdrop({super.key, this.connected = false});

  final bool connected;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _StarlitMapPainter(connected: connected),
      child: const SizedBox.expand(),
    );
  }
}

class _StarlitMapPainter extends CustomPainter {
  _StarlitMapPainter({required this.connected});

  final bool connected;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = connected
          ? StarlitColors.accent.withValues(alpha: 0.22)
          : StarlitColors.mapDot
      ..style = PaintingStyle.fill;

    final rng = math.Random(42);
    for (var i = 0; i < 520; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      // denser around middle latitudes for a globe-ish silhouette
      final cy = (y / size.height - 0.48).abs();
      if (cy > 0.42 && rng.nextBool()) continue;
      final r = 0.7 + rng.nextDouble() * 1.6;
      canvas.drawCircle(Offset(x, y), r, paint);
    }

    // soft equator band
    final band = Paint()
      ..shader = RadialGradient(
        colors: [
          (connected ? StarlitColors.accent : StarlitColors.accentDeep)
              .withValues(alpha: 0.16),
          const Color(0x00000000),
        ],
      ).createShader(Rect.fromCircle(center: size.center(Offset.zero), radius: size.shortestSide * 0.55));
    canvas.drawCircle(size.center(Offset.zero), size.shortestSide * 0.55, band);
  }

  @override
  bool shouldRepaint(covariant _StarlitMapPainter oldDelegate) =>
      oldDelegate.connected != connected;
}

class StarlitMoonMark extends StatelessWidget {
  const StarlitMoonMark({super.key, this.size = 64, this.muted = false});

  final double size;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: muted
            ? null
            : LinearGradient(
                colors: [StarlitColors.accent, StarlitColors.accentDeep],
              ),
        color: muted ? StarlitColors.stroke : null,
      ),
      child: CustomPaint(
        painter: _MoonPainter(color: muted ? StarlitColors.muted : const Color(0xFF041018)),
      ),
    );
  }
}

class _MoonPainter extends CustomPainter {
  _MoonPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final c = Offset(size.width * 0.48, size.height * 0.5);
    final r = size.shortestSide * 0.28;
    final path = Path()..addOval(Rect.fromCircle(center: c, radius: r));
    final cut = Path()
      ..addOval(
        Rect.fromCircle(
          center: Offset(c.dx + r * 0.42, c.dy - r * 0.08),
          radius: r * 0.82,
        ),
      );
    canvas.drawPath(
      Path.combine(PathOperation.difference, path, cut),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _MoonPainter oldDelegate) =>
      oldDelegate.color != color;
}

class StarlitSectionTitle extends StatelessWidget {
  const StarlitSectionTitle(this.title, {super.key, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StarlitText(
          title,
          size: 30,
          weight: FontWeight.w800,
          display: true,
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          StarlitText(
            subtitle!,
            size: 14,
            color: StarlitColors.muted,
            height: 1.35,
          ),
        ],
      ],
    );
  }
}
