import 'package:starlit_connect/starlit/theme.dart';
import 'package:starlit_connect/starlit/widgets.dart';
import 'package:flutter/widgets.dart';

Future<T?> showStarlitPopup<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool dismissible = true,
}) {
  return Navigator.of(context, rootNavigator: true).push<T>(
    PageRouteBuilder<T>(
      opaque: false,
      barrierDismissible: dismissible,
      barrierColor: const Color(0xA6000000),
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (ctx, _, _) => ValueListenableBuilder<int>(
        valueListenable: StarlitColors.revision,
        builder: (ctx, _, _) => Center(child: builder(ctx)),
      ),
      transitionsBuilder: (_, anim, _, child) {
        final curved = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    ),
  );
}

class StarlitPopupFrame extends StatelessWidget {
  const StarlitPopupFrame({
    super.key,
    required this.title,
    required this.child,
    this.width = 460,
    this.maxHeight = 640,
    this.onClose,
  });

  final String title;
  final Widget child;
  final double width;
  final double maxHeight;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: width, maxHeight: maxHeight),
      child: StarlitCard(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: starlitText(
                      size: 19,
                      weight: FontWeight.w800,
                      display: true,
                    ),
                  ),
                ),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: onClose ?? () => Navigator.of(context).maybePop(),
                    child: Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: StarlitColors.field,
                        border: Border.all(color: StarlitColors.stroke),
                      ),
                      child: Text(
                        '✕',
                        style: starlitText(
                          size: 13,
                          color: StarlitColors.muted,
                          weight: FontWeight.w700,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Flexible(child: child),
          ],
        ),
      ),
    );
  }
}
