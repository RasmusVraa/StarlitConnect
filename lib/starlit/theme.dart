import 'package:flutter/widgets.dart';

/// Night palette — cool ink, teal accent (not GAC purple).
abstract final class StarlitColors {
  static const bg = Color(0xFF05070D);
  static const bgSoft = Color(0xFF0A0F18);
  static const card = Color(0xFF111822);
  static const cardHi = Color(0xFF171F2C);
  static const stroke = Color(0xFF2A3444);
  static const accent = Color(0xFF56C2D6);
  static const accentDeep = Color(0xFF2A8FA8);
  static const text = Color(0xFFF3F6FA);
  static const muted = Color(0xFF93A0B4);
  static const muted2 = Color(0xFF6A768A);
  static const success = Color(0xFF3DDC97);
  static const danger = Color(0xFFFF6B7A);
  static const mapDot = Color(0xFF334155);
  static const field = Color(0xFF0C121C);
}

abstract final class StarlitRadii {
  static const card = 18.0;
  static const pill = 14.0;
  static const tile = 14.0;
  static const icon = 26.0;
}

/// Forces clean glyphs: no Twemoji fallback, no mystery underlines.
TextStyle starlitText({
  Color color = StarlitColors.text,
  double size = 15,
  FontWeight weight = FontWeight.w500,
  double height = 1.35,
  double letterSpacing = 0,
}) {
  return TextStyle(
    inherit: false,
    color: color,
    fontSize: size,
    fontWeight: weight,
    height: height,
    letterSpacing: letterSpacing,
    decoration: TextDecoration.none,
    decorationThickness: 0,
    decorationColor: const Color(0x00000000),
    fontFamily: 'Segoe UI',
    fontFamilyFallback: const ['Arial', 'sans-serif'],
    textBaseline: TextBaseline.alphabetic,
    leadingDistribution: TextLeadingDistribution.even,
  );
}

class StarlitText extends StatelessWidget {
  const StarlitText(
    this.data, {
    super.key,
    this.color = StarlitColors.text,
    this.size = 15,
    this.weight = FontWeight.w500,
    this.height = 1.35,
    this.align,
    this.maxLines,
    this.overflow,
  });

  final String data;
  final Color color;
  final double size;
  final FontWeight weight;
  final double height;
  final TextAlign? align;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    return Text(
      data,
      textAlign: align,
      maxLines: maxLines,
      overflow: overflow,
      style: starlitText(
        color: color,
        size: size,
        weight: weight,
        height: height,
      ),
    );
  }
}
