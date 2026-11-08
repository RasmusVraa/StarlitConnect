import 'package:starlit_connect/starlit/theme.dart';
import 'package:starlit_connect/starlit/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:prism_ui/prism_ui.dart' show Theme;

/// Puts a stock FlClash tools screen on the Starlit starfield with matching
/// surface colors so lists/cards don't fall back to plain Material chrome.
class StarlitToolsHost extends StatelessWidget {
  const StarlitToolsHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final scheme = base.colorScheme.copyWith(
      surface: StarlitColors.bg,
      surfaceDim: StarlitColors.bgSoft,
      surfaceBright: StarlitColors.cardHi,
      surfaceContainerLowest: StarlitColors.bg,
      surfaceContainerLow: StarlitColors.bgSoft,
      surfaceContainer: StarlitColors.card,
      surfaceContainerHigh: StarlitColors.cardHi,
      surfaceContainerHighest: const Color(0xFF2A2234),
      onSurface: StarlitColors.text,
      onSurfaceVariant: StarlitColors.muted,
      outline: StarlitColors.stroke,
      outlineVariant: StarlitColors.stroke,
      primary: StarlitColors.accent,
      onPrimary: StarlitColors.bg,
      secondary: StarlitColors.accentDeep,
      onSecondary: StarlitColors.bg,
      error: StarlitColors.danger,
    );
    return StarlitScaffold(
      child: Theme(
        data: base.copyWith(
          scaffoldBackgroundColor: const Color(0x00000000),
          colorScheme: scheme,
        ),
        child: DefaultTextStyle(
          style: starlitText(),
          child: child,
        ),
      ),
    );
  }
}
