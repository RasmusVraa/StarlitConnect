import 'dart:math' as math;

import 'package:fl_clash/starlit/theme.dart';
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
              if (glow)
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(-0.6, -0.8),
                      radius: 1.1,
                      colors: [Color(0x2856C2D6), Color(0x0005070D)],
                    ),
                  ),
                ),
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
      decoration: BoxDecoration(
        color: highlighted ? StarlitColors.cardHi : StarlitColors.card,
        borderRadius: BorderRadius.circular(StarlitRadii.card),
        border: Border.all(
          color: highlighted ? StarlitColors.accent.withValues(alpha: 0.55) : StarlitColors.stroke,
          width: highlighted ? 1.6 : 1,
        ),
        boxShadow: highlighted
            ? [
                BoxShadow(
                  color: StarlitColors.accent.withValues(alpha: 0.12),
                  blurRadius: 22,
                  spreadRadius: 1,
                ),
              ]
            : null,
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
          color: const Color(0xFF041018),
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
              gradient: const LinearGradient(
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
              gradient: const LinearGradient(
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
            color: value ? StarlitColors.accent : StarlitColors.stroke,
            boxShadow: value
                ? [
                    BoxShadow(
                      color: StarlitColors.accent.withValues(alpha: 0.35),
                      blurRadius: 10,
                    ),
                  ]
                : null,
          ),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: StarlitColors.text,
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
            : const LinearGradient(
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
