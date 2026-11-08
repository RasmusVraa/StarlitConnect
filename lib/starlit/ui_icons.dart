import 'package:starlit_connect/starlit/theme.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Lucide-иконки из assets/images/ui.
abstract final class StarlitUi {
  static Widget icon(
    String name, {
    double size = 18,
    Color? color,
  }) {
    return SvgPicture.asset(
      'assets/images/ui/$name.svg',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color ?? StarlitColors.accent, BlendMode.srcIn),
    );
  }

  static Widget box(
    String name, {
    double size = 40,
    Color? tint,
  }) {
    final color = tint ?? StarlitColors.accent;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: color.withValues(alpha: 0.14),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: icon(name, size: size * 0.42, color: color),
    );
  }
}
