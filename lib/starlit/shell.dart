import 'dart:async';
import 'dart:math' as math;

import 'package:starlit_connect/engine/provider.dart';
import 'package:starlit_connect/state.dart';
import 'package:starlit_connect/starlit/autopilot.dart';
import 'package:starlit_connect/starlit/brand.dart';
import 'package:starlit_connect/starlit/l10n.dart';
import 'package:starlit_connect/starlit/map_view.dart';
import 'package:starlit_connect/starlit/mode_page.dart';
import 'package:starlit_connect/starlit/ping.dart';
import 'package:starlit_connect/starlit/prefs.dart';
import 'package:starlit_connect/starlit/settings_page.dart';
import 'package:starlit_connect/starlit/routing.dart';
import 'package:starlit_connect/starlit/servers.dart';
import 'package:starlit_connect/starlit/sound.dart';
import 'package:starlit_connect/starlit/theme.dart';
import 'package:starlit_connect/starlit/ui_icons.dart';
import 'package:starlit_connect/starlit/vpn_home.dart';
import 'package:starlit_connect/starlit/whats_new.dart';
import 'package:starlit_connect/starlit/widgets.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum StarlitTab { vpn, mode, settings }

class StarlitShell extends ConsumerStatefulWidget {
  const StarlitShell({super.key});

  @override
  ConsumerState<StarlitShell> createState() => _StarlitShellState();
}

class _StarlitShellState extends ConsumerState<StarlitShell> {
  var _tab = StarlitTab.vpn;
  var _showWhatsNew = false;
  Timer? _autopilotTimer;
  var _wasConnected = false;

  @override
  void initState() {
    super.initState();
    unawaited(_maybeWhatsNew());
    unawaited(_boot());
    ref.listenManual(starlitEngineProvider, (prev, next) {
      final connected = next.connected;
      if (_wasConnected == connected) return;
      _wasConnected = connected;
      unawaited(
        connected ? StarlitSound.connected() : StarlitSound.disconnected(),
      );
      _autopilotTimer?.cancel();
      _autopilotTimer = connected
          ? Timer.periodic(
              const Duration(seconds: 12),
              (_) => unawaited(StarlitAutopilot.watch(ref)),
            )
          : null;
      if (connected) unawaited(StarlitAutopilot.watch(ref));
    });
  }

  @override
  void dispose() {
    _autopilotTimer?.cancel();
    super.dispose();
  }

  Future<void> _boot() async {
    try {
      final engine = ref.read(starlitEngineProvider);
      try {
        if (engine.subscriptionUrl != null) {
          await engine.refreshSubscription();
        }
      } catch (_) {}
      if (!await StarlitPing.waitForNodes(ref) || !mounted) return;
      await StarlitRouting.sync(ref);
      if (!mounted) return;
      if (!await StarlitPrefs.autoPing() || !mounted) return;
      await StarlitPing.run(ref);
      if (!mounted) return;
      await StarlitAutopilot.preselectBest(ref);
    } catch (_) {}
  }

  Future<void> _maybeWhatsNew() async {
    final version = globalState.packageInfo.version;
    final seen = await StarlitPrefs.whatsNewSeen(version);
    if (!seen && mounted) {
      setState(() => _showWhatsNew = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: StarlitColors.revision,
      builder: (context, revision, _) =>
          KeyedSubtree(key: ValueKey(revision), child: _body()),
    );
  }

  Widget _body() {
    final engine = ref.watch(starlitEngineProvider);
    final selected = engine.selectedNode;
    final activeCc = selected == null
        ? null
        : StarlitServers.countryCode(selected.name);
    final countries = <String>{
      for (final n in engine.visibleNodes)
        if (StarlitServers.countryCode(n.name) case final cc?) cc,
    };
    final onVpn = _tab == StarlitTab.vpn;

    return StarlitScaffold(
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !onVpn,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 280),
                opacity: onVpn ? 1 : 0.42,
                child: Padding(
                  padding: EdgeInsets.only(
                    right: onVpn ? 380 : 120,
                    left: onVpn ? 0 : 40,
                  ),
                  child: StarlitInteractiveMap(
                    connected: engine.connected,
                    connecting: false,
                    activeCountry: engine.connected ? activeCc : null,
                    availableCountries: countries,
                  ),
                ),
              ),
            ),
          ),
          if (!onVpn)
            const Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Color(0x99060A14),
                        Color(0x66060A14),
                        Color(0x44060A14),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.only(left: 108),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, anim) {
                  return FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.02, 0.01),
                        end: Offset.zero,
                      ).animate(anim),
                      child: child,
                    ),
                  );
                },
                child: KeyedSubtree(
                  key: ValueKey(_tab),
                  child: switch (_tab) {
                    StarlitTab.vpn => const StarlitVpnHome(),
                    StarlitTab.mode => const StarlitModePage(),
                    StarlitTab.settings => const StarlitSettingsPage(),
                  },
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 128,
            child: _OrbitNav(
              tab: _tab,
              onSelect: (t) => setState(() => _tab = t),
            ),
          ),
          if (_showWhatsNew)
            StarlitWhatsNew(
              version: globalState.packageInfo.version,
              onClose: () async {
                await StarlitPrefs.setWhatsNewSeen(
                  globalState.packageInfo.version,
                );
                if (mounted) setState(() => _showWhatsNew = false);
              },
            ),
        ],
      ),
    );
  }
}

/// Left-side orbital rail: satellites are nav buttons.
class _OrbitNav extends ConsumerStatefulWidget {
  const _OrbitNav({required this.tab, required this.onSelect});

  final StarlitTab tab;
  final ValueChanged<StarlitTab> onSelect;

  @override
  ConsumerState<_OrbitNav> createState() => _OrbitNavState();
}

class _OrbitNavState extends ConsumerState<_OrbitNav>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  var _t = 0.0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      final next = elapsed.inMilliseconds / 1000.0;
      if ((next - _t).abs() > 1 / 60) {
        setState(() => _t = next);
      }
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connected = ref.watch(
      starlitEngineProvider.select((e) => e.connected),
    );
    final version = globalState.packageInfo.version;
    final items = <({StarlitTab? tab, String label, String asset, bool logo})>[
      (tab: null, label: '', asset: '', logo: true),
      (
        tab: StarlitTab.vpn,
        label: 'VPN',
        asset: starlitNavAsset(StarlitNavGlyph.vpn),
        logo: false,
      ),
      (
        tab: StarlitTab.mode,
        label: StarlitL10n.of(context, ru: 'Режим', en: 'Mode'),
        asset: starlitNavAsset(StarlitNavGlyph.mode),
        logo: false,
      ),
      (
        tab: StarlitTab.settings,
        label: StarlitL10n.of(context, ru: 'Настройки', en: 'Settings'),
        asset: starlitNavAsset(StarlitNavGlyph.profile),
        logo: false,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        // Ellipse sitting so its left rim runs through the rail.
        final cx = size.width * 1.55;
        final cy = size.height * 0.48;
        final rx = size.width * 1.22;
        final ry = size.height * 0.38;
        // Angles along the left arc (π … ~1.15π … ~0.85π from top to bottom).
        // Left arc, top → bottom (negative sin = above center).
        const angles = <double>[
          4.05, // logo
          3.65, // VPN
          3.25, // Mode
          2.82, // Settings
        ];

        Offset point(double angle, {double drift = 0}) {
          final a = angle + drift;
          return Offset(cx + rx * math.cos(a), cy + ry * math.sin(a));
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _OrbitArcPainter(
                  center: Offset(cx, cy),
                  rx: rx,
                  ry: ry,
                  accent: StarlitColors.accent,
                  lit: connected,
                  phase: _t,
                ),
              ),
            ),
            for (final (i, item) in items.indexed)
              Builder(
                builder: (context) {
                  final drift = math.sin(_t * 0.7 + i * 1.1) * 0.018;
                  final p = point(angles[i], drift: drift);
                  final selected =
                      item.tab != null && item.tab == widget.tab;
                  final satSize = item.logo ? 54.0 : 48.0;
                  return Positioned(
                    left: p.dx - satSize / 2,
                    top: p.dy - satSize / 2 - (item.logo ? 0 : 8),
                    child: _Satellite(
                      size: satSize,
                      selected: selected,
                      logo: item.logo,
                      label: item.label,
                      asset: item.asset,
                      onTap: item.tab == null
                          ? null
                          : () => widget.onSelect(item.tab!),
                    ),
                  );
                },
              ),
            Positioned(
              left: 18,
              bottom: 18,
              child: _StatusChip(connected: connected, version: version),
            ),
          ],
        );
      },
    );
  }
}

class _OrbitArcPainter extends CustomPainter {
  const _OrbitArcPainter({
    required this.center,
    required this.rx,
    required this.ry,
    required this.accent,
    required this.lit,
    required this.phase,
  });

  final Offset center;
  final double rx;
  final double ry;
  final Color accent;
  final bool lit;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCenter(
      center: center,
      width: rx * 2,
      height: ry * 2,
    );
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..color = accent.withValues(alpha: lit ? 0.12 : 0.06)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = accent.withValues(alpha: lit ? 0.55 : 0.28);
    final soft = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0x33FFFFFF);

    // Left arc only (≈ 140°).
    const start = 2.35;
    const sweep = 1.7;
    canvas.drawArc(rect, start, sweep, false, glow);
    canvas.drawArc(rect, start, sweep, false, ring);
    canvas.drawArc(
      Rect.fromCenter(center: center, width: rx * 1.08 * 2, height: ry * 1.08 * 2),
      start + 0.08,
      sweep - 0.16,
      false,
      soft,
    );

    // Travelling spark on the orbit.
    final sparkA = start + ((phase * 0.35) % sweep);
    final spark = Offset(
      center.dx + rx * math.cos(sparkA),
      center.dy + ry * math.sin(sparkA),
    );
    canvas.drawCircle(
      spark,
      2.4,
      Paint()
        ..color = accent.withValues(alpha: 0.9)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(spark, 1.4, Paint()..color = const Color(0xFFFFFFFF));
  }

  @override
  bool shouldRepaint(covariant _OrbitArcPainter oldDelegate) =>
      oldDelegate.phase != phase ||
      oldDelegate.lit != lit ||
      oldDelegate.accent != accent ||
      oldDelegate.center != center ||
      oldDelegate.rx != rx ||
      oldDelegate.ry != ry;
}

class _Satellite extends StatefulWidget {
  const _Satellite({
    required this.size,
    required this.selected,
    required this.logo,
    required this.label,
    required this.asset,
    required this.onTap,
  });

  final double size;
  final bool selected;
  final bool logo;
  final String label;
  final String asset;
  final VoidCallback? onTap;

  @override
  State<_Satellite> createState() => _SatelliteState();
}

class _SatelliteState extends State<_Satellite> {
  var _hover = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final body = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: widget.size,
          height: widget.size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: widget.logo
                  ? const [Color(0xFFE891C4), Color(0xFF8B6BC9)]
                  : selected
                      ? [
                          StarlitColors.accent.withValues(alpha: 0.95),
                          StarlitColors.accentDeep.withValues(alpha: 0.9),
                        ]
                      : [
                          const Color(0xEE2A2236),
                          const Color(0xEE16111F),
                        ],
            ),
            border: Border.all(
              color: selected || _hover || widget.logo
                  ? StarlitColors.accent.withValues(alpha: 0.75)
                  : const Color(0x44FFFFFF),
              width: selected ? 1.6 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: (selected || widget.logo
                        ? StarlitColors.accent
                        : const Color(0xFF000000))
                    .withValues(alpha: selected || widget.logo ? 0.45 : 0.35),
                blurRadius: selected || _hover ? 18 : 12,
                offset: const Offset(0, 4),
              ),
              if (selected || widget.logo)
                BoxShadow(
                  color: StarlitColors.accent.withValues(alpha: 0.25),
                  blurRadius: 22,
                ),
            ],
          ),
          child: widget.logo
              ? const StarlitLogo(size: 40)
              : StarlitUi.icon(
                  widget.asset,
                  size: 20,
                  color: selected
                      ? const Color(0xFF1A1020)
                      : StarlitColors.text,
                ),
        ),
        if (!widget.logo) ...[
          const SizedBox(height: 6),
          Text(
            widget.label,
            style: starlitText(
              size: 10,
              weight: selected ? FontWeight.w800 : FontWeight.w600,
              color: selected ? StarlitColors.accent : StarlitColors.muted2,
            ),
          ),
        ],
      ],
    );

    if (widget.onTap == null) return body;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: body,
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.connected, required this.version});

  final bool connected;
  final String version;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xAA16111F),
        border: Border.all(
          color: connected
              ? StarlitColors.success.withValues(alpha: 0.4)
              : const Color(0x33FFFFFF),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: connected
                      ? StarlitColors.success
                      : StarlitColors.muted2,
                  boxShadow: connected
                      ? [
                          BoxShadow(
                            color: StarlitColors.success.withValues(alpha: 0.55),
                            blurRadius: 8,
                          ),
                        ]
                      : null,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                connected
                    ? StarlitL10n.of(context, ru: 'онлайн', en: 'on')
                    : StarlitL10n.of(context, ru: 'офлайн', en: 'off'),
                style: starlitText(
                  size: 10,
                  weight: FontWeight.w700,
                  color: connected
                      ? StarlitColors.success
                      : StarlitColors.muted2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'v$version',
            style: starlitText(
              size: 9,
              weight: FontWeight.w600,
              color: StarlitColors.muted2.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}
