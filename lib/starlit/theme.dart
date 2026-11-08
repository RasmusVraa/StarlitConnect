import 'package:flutter/widgets.dart';

/// Палитра ближе к GAC Connect (тёмный космос + сиреневый акцент).
abstract final class StarlitColors {
  static const bg = Color(0xFF0C0A12);
  static const bgSoft = Color(0xFF14101A);
  static const card = Color(0xB81A1522);
  static const cardHi = Color(0xB8241C2E);
  static const stroke = Color(0xFF342A3E);
  static Color _accent = const Color(0xFFE891C4);
  static Color _accentDeep = const Color(0xFFB794E8);
  static Color get accent => _accent;
  static Color get accentDeep => _accentDeep;
  static Color get glow => _accent.withValues(alpha: 0.4);
  static const accentTeal = Color(0xFF14B8A6);
  static const text = Color(0xFFF5F2F7);
  static const muted = Color(0xFFA89AB0);
  static const muted2 = Color(0xFF7A6E86);
  static const success = Color(0xFF3DDC97);
  static const danger = Color(0xFFE85D6A);
  static const mapDot = Color(0xFF7A889E);
  static const field = Color(0xE012101A);
  static const warn = Color(0xFFF0A35A);

  static final revision = ValueNotifier<int>(0);

  static void applyAccent(Color accent, Color deep) {
    _accent = accent;
    _accentDeep = deep;
    revision.value++;
  }
}

typedef StarlitAccent = ({String id, String label, Color color, Color deep});

const starlitAccents = <StarlitAccent>[
  (
    id: 'pink',
    label: 'Розовый',
    color: Color(0xFFE891C4),
    deep: Color(0xFFB794E8),
  ),
  (
    id: 'violet',
    label: 'Фиолетовый',
    color: Color(0xFF9B7BFF),
    deep: Color(0xFF6C4DE0),
  ),
  (
    id: 'blue',
    label: 'Синий',
    color: Color(0xFF5B9BFF),
    deep: Color(0xFF3868D8),
  ),
  (
    id: 'teal',
    label: 'Бирюзовый',
    color: Color(0xFF2EC4B6),
    deep: Color(0xFF1B8C9E),
  ),
  (
    id: 'amber',
    label: 'Янтарный',
    color: Color(0xFFF0B35A),
    deep: Color(0xFFD9803A),
  ),
];

StarlitAccent starlitAccentById(String id) =>
    starlitAccents.firstWhere((a) => a.id == id, orElse: () => starlitAccents.first);

abstract final class StarlitRadii {
  static const card = 20.0;
  static const pill = 16.0;
  static const tile = 14.0;
  static const icon = 26.0;
}

TextStyle starlitText({
  Color color = StarlitColors.text,
  double size = 15,
  FontWeight weight = FontWeight.w500,
  double height = 1.35,
  double letterSpacing = 0,
  bool display = false,
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
    fontFamily: display ? 'Manrope' : 'Inter',
    fontFamilyFallback: const ['Segoe UI', 'Arial', 'sans-serif'],
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
    this.display = false,
  });

  final String data;
  final Color color;
  final double size;
  final FontWeight weight;
  final double height;
  final TextAlign? align;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool display;

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
        display: display,
      ),
    );
  }
}
