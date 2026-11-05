import 'package:flutter/widgets.dart';

/// Night-sky palette for StarlitConnect — cyan/blue, not GAC lavender.
abstract final class StarlitColors {
  static const bg = Color(0xFF060912);
  static const bgSoft = Color(0xFF0B1220);
  static const card = Color(0xFF121A2A);
  static const cardHi = Color(0xFF182235);
  static const stroke = Color(0xFF2A3850);
  static const accent = Color(0xFF5AD0E6);
  static const accentDeep = Color(0xFF2F8FB8);
  static const glow = Color(0x4039C4E0);
  static const text = Color(0xFFF4F7FB);
  static const muted = Color(0xFF8E9BB0);
  static const muted2 = Color(0xFF6B778C);
  static const success = Color(0xFF3DDC97);
  static const danger = Color(0xFFFF6B7A);
  static const mapDot = Color(0xFF3A4D6B);
}

abstract final class StarlitRadii {
  static const card = 22.0;
  static const pill = 999.0;
  static const tile = 16.0;
  static const icon = 28.0;
}
