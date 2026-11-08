import 'dart:math' as math;

import 'package:starlit_connect/starlit/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Wheel scrolling with per-frame exponential easing (not jumpy animateTo).
class StarlitSmoothScroll extends StatefulWidget {
  const StarlitSmoothScroll({
    super.key,
    required this.controller,
    required this.child,
    this.speed = 1.15,
  });

  final ScrollController controller;
  final Widget child;
  final double speed;

  @override
  State<StarlitSmoothScroll> createState() => _StarlitSmoothScrollState();
}

class _StarlitSmoothScrollState extends State<StarlitSmoothScroll>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  var _target = 0.0;
  var _hasTarget = false;
  var _lastElapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick);
    widget.controller.addListener(_syncFromUser);
  }

  @override
  void didUpdateWidget(covariant StarlitSmoothScroll oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_syncFromUser);
      widget.controller.addListener(_syncFromUser);
      _hasTarget = false;
      _ticker.stop();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    widget.controller.removeListener(_syncFromUser);
    super.dispose();
  }

  void _syncFromUser() {
    if (!widget.controller.hasClients) return;
    // Drag / scrollbar — follow the real pixels.
    if (!_ticker.isActive) {
      _target = widget.controller.offset;
      _hasTarget = true;
    }
  }

  void _onSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    if (!widget.controller.hasClients) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (resolved) {
      if (resolved is! PointerScrollEvent) return;
      final pos = widget.controller.position;
      if (!pos.hasPixels || !pos.hasContentDimensions) return;
      if (!_hasTarget) _target = pos.pixels;
      _target = (_target + resolved.scrollDelta.dy * widget.speed).clamp(
        pos.minScrollExtent,
        pos.maxScrollExtent,
      );
      _hasTarget = true;
      if (!_ticker.isActive) {
        _lastElapsed = Duration.zero;
        _ticker.start();
      }
    });
  }

  void _tick(Duration elapsed) {
    if (!widget.controller.hasClients || !_hasTarget) {
      _ticker.stop();
      return;
    }
    final dt = _lastElapsed == Duration.zero
        ? 1 / 60
        : (elapsed - _lastElapsed).inMicroseconds / 1e6;
    _lastElapsed = elapsed;
    if (dt <= 0 || dt > 0.05) return;

    final pos = widget.controller.position;
    final cur = pos.pixels;
    final target = _target.clamp(pos.minScrollExtent, pos.maxScrollExtent);
    final delta = target - cur;
    if (delta.abs() < 0.35) {
      if ((cur - target).abs() > 0.01) {
        widget.controller.jumpTo(target);
      }
      _ticker.stop();
      return;
    }
    // ~14 Hz time-constant → smooth but responsive.
    final t = 1 - math.exp(-dt * 14);
    widget.controller.jumpTo(cur + delta * t);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: _onSignal,
      child: widget.child,
    );
  }
}

/// Thin accent scrollbar pinned to the right edge.
class StarlitScrollbar extends StatelessWidget {
  const StarlitScrollbar({
    super.key,
    required this.controller,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.contentRight = 10,
  });

  final ScrollController controller;
  final Widget child;
  final EdgeInsets padding;
  final double contentRight;

  @override
  Widget build(BuildContext context) {
    return StarlitSmoothScroll(
      controller: controller,
      child: RawScrollbar(
        controller: controller,
        thumbVisibility: true,
        trackVisibility: defaultTargetPlatform == TargetPlatform.windows,
        thickness: 6,
        radius: const Radius.circular(8),
        padding: padding,
        mainAxisMargin: 4,
        crossAxisMargin: 0,
        thumbColor: StarlitColors.accent.withValues(alpha: 0.7),
        trackColor: const Color(0x22FFFFFF),
        trackBorderColor: const Color(0x00000000),
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(
            padding: MediaQuery.paddingOf(context).copyWith(right: 0),
          ),
          child: ScrollConfiguration(
            behavior: const _StarlitScrollBehavior(),
            child: Padding(
              padding: EdgeInsets.only(right: contentRight),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _StarlitScrollBehavior extends ScrollBehavior {
  const _StarlitScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
        // Mouse drag on scrollbar track still works via RawScrollbar;
        // wheel is handled by StarlitSmoothScroll.
        PointerDeviceKind.trackpad,
      };

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const ClampingScrollPhysics(
      parent: AlwaysScrollableScrollPhysics(),
    );
  }

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}
