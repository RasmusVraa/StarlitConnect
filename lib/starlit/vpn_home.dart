import 'dart:async';
import 'dart:math' as math;

import 'package:starlit_connect/common/num.dart';
import 'package:starlit_connect/engine/node.dart';
import 'package:starlit_connect/engine/provider.dart';
import 'package:starlit_connect/models/common.dart';
import 'package:starlit_connect/starlit/autopilot.dart';
import 'package:starlit_connect/starlit/brand.dart';
import 'package:starlit_connect/starlit/cabinet_api.dart';
import 'package:starlit_connect/starlit/client_geo.dart';
import 'package:starlit_connect/starlit/l10n.dart';
import 'package:starlit_connect/starlit/ping.dart';
import 'package:starlit_connect/starlit/prefs.dart';
import 'package:starlit_connect/starlit/routing.dart';
import 'package:starlit_connect/starlit/scroll.dart';
import 'package:starlit_connect/starlit/servers.dart';
import 'package:starlit_connect/starlit/subscription_info.dart';
import 'package:starlit_connect/starlit/theme.dart';
import 'package:starlit_connect/starlit/tun_guard.dart';
import 'package:starlit_connect/starlit/ui_icons.dart';
import 'package:starlit_connect/starlit/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StarlitVpnHome extends ConsumerStatefulWidget {
  const StarlitVpnHome({super.key});

  @override
  ConsumerState<StarlitVpnHome> createState() => _StarlitVpnHomeState();
}

class _StarlitVpnHomeState extends ConsumerState<StarlitVpnHome> {
  var _autopilot = true;
  var _bypass = false;
  var _connecting = false;
  var _updatingSub = false;
  String? _pendingCc;
  String? _connectError;
  int? _daysLeft;
  int _usedBytes = 0;
  int _totalBytes = 0;
  String _hereLabel = '…';
  final _serversScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    unawaited(_loadPrefs());
    unawaited(_refreshDays());
    unawaited(_refreshGeo());
  }

  @override
  void dispose() {
    _serversScroll.dispose();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    final a = await StarlitPrefs.autopilot();
    final b = await StarlitPrefs.bypass();
    final cachedDays = await StarlitPrefs.cabinetDaysLeft();
    if (!mounted) return;
    setState(() {
      _autopilot = a;
      _bypass = b;
      _daysLeft = cachedDays;
    });
  }

  Future<void> _refreshGeo() async {
    final geo = await StarlitClientGeoApi.load();
    if (!mounted || geo == null) return;
    setState(() => _hereLabel = geo.city.isNotEmpty ? geo.city : geo.label);
  }

  Future<void> _refreshDays() async {
    final engine = ref.read(starlitEngineProvider);
    final info = StarlitSubscriptionInfo.parse(engine.userInfo);
    final fallbackUsed = info.upload + info.download;
    try {
      final snap = await StarlitCabinetApi.load(
        subscriptionUrl: engine.subscriptionUrl,
        usedBytes: fallbackUsed,
        totalBytes: info.total,
        expireFromProfile: info.expire,
      );
      if (!mounted) return;
      final days = snap.daysLeft ?? info.daysLeft;
      setState(() {
        _daysLeft = days;
        _usedBytes = snap.usedBytes;
        _totalBytes = snap.totalBytes;
      });
      await StarlitPrefs.setCabinetDaysLeft(days);
      await StarlitPrefs.setCabinetExpireAt(snap.expireAt ?? info.expire);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (_daysLeft == null && info.daysLeft != null) {
          _daysLeft = info.daysLeft;
        }
        if (_usedBytes == 0 && fallbackUsed > 0) _usedBytes = fallbackUsed;
        if (_totalBytes == 0 && info.total > 0) _totalBytes = info.total;
      });
    }
  }

  Future<void> _toggleConnect() async {
    if (_connecting) return;
    final engine = ref.read(starlitEngineProvider);
    if (engine.connected) {
      setState(() => _connecting = true);
      try {
        await engine.disconnect();
      } finally {
        if (mounted) setState(() => _connecting = false);
      }
      return;
    }
    await _connect();
  }

  Future<void> _connect({String? preferredId, String? preferredName}) async {
    setState(() {
      _connecting = true;
      _connectError = null;
    });
    final started = DateTime.now();
    try {
      final engine = ref.read(starlitEngineProvider);
      if (StarlitPing.visible(engine).isEmpty) {
        await engine.refreshSubscription();
        await StarlitPing.waitForNodes(ref, seconds: 15);
      }
      await StarlitRouting.sync(ref);
      String? chosenName;
      if (preferredId != null) {
        await StarlitAutopilot.choose(ref, preferredId);
        chosenName = preferredName ??
            ref.read(starlitEngineProvider).selectedNode?.name;
      } else {
        chosenName = await StarlitAutopilot.ensureSelection(
          ref,
          autopilot: _autopilot,
        );
      }
      if (!mounted) return;
      if (chosenName == null) return;
      setState(() => _pendingCc = StarlitAutopilot.countryOf(chosenName));
      await ref.read(starlitEngineProvider).connect();
      final spent = DateTime.now().difference(started);
      const minimum = Duration(milliseconds: 1700);
      if (spent < minimum) await Future<void>.delayed(minimum - spent);
    } catch (e) {
      if (!mounted) return;
      final raw = e.toString().replaceFirst(RegExp(r'^Bad state:\s*'), '');
      final short = raw.split('\n').first.trim();
      setState(() {
        _connectError = short.isEmpty
            ? StarlitL10n.of(
                context,
                ru: 'Не удалось подключиться',
                en: 'Could not connect',
              )
            : short;
      });
    } finally {
      if (mounted) {
        setState(() {
          _connecting = false;
          _pendingCc = null;
        });
      }
    }
  }

  Future<void> _selectProxy(StarlitNode node) async {
    if (_autopilot) {
      setState(() => _autopilot = false);
      unawaited(StarlitPrefs.setAutopilot(false));
    }
    if (ref.read(starlitEngineProvider).connected) {
      await StarlitAutopilot.choose(ref, node.id);
      setState(() {
        _connecting = true;
        _pendingCc = StarlitServers.countryCode(node.name);
      });
      await Future<void>.delayed(const Duration(milliseconds: 1700));
      if (mounted) {
        setState(() {
          _connecting = false;
          _pendingCc = null;
        });
      }
      return;
    }
    await _connect(preferredId: node.id, preferredName: node.name);
  }

  Future<void> _refreshSubscription() async {
    final engine = ref.read(starlitEngineProvider);
    if (engine.subscriptionUrl == null || _updatingSub) return;
    setState(() => _updatingSub = true);
    try {
      await engine.refreshSubscription();
      if (!mounted) return;
      await StarlitRouting.sync(ref);
      unawaited(_refreshDays());
      if (await StarlitPrefs.autoPing()) {
        await StarlitPing.run(ref);
      }
    } finally {
      if (mounted) setState(() => _updatingSub = false);
    }
  }

  String _daysLabel(BuildContext context, int? days) =>
      StarlitSubscriptionInfo.daysLabel(
        days,
        ru: StarlitL10n.isRu(context),
      );

  @override
  Widget build(BuildContext context) {
    final engine = ref.watch(starlitEngineProvider);
    final running = engine.connected;
    final selectedNode = engine.selectedNode;
    final selected = selectedNode?.name;
    final visible = StarlitPing.visible(engine);
    final connecting = _connecting;
    final info = StarlitSubscriptionInfo.parse(engine.userInfo);
    final daysLeft = _daysLeft ?? info.daysLeft;
    final usedBytes =
        _usedBytes > 0 ? _usedBytes : (info.upload + info.download);
    final totalBytes = _totalBytes > 0 ? _totalBytes : info.total;
    final here = _hereLabel;
    final activeCc =
        _pendingCc ??
        (selected == null ? null : StarlitServers.countryCode(selected));

    return Stack(
      fit: StackFit.expand,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 36, 24, 36),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Spacer(),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 320),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.12),
                            end: Offset.zero,
                          ).animate(anim),
                          child: child,
                        ),
                      ),
                      child: Column(
                        key: ValueKey(
                          connecting
                              ? 'connecting'
                              : running
                              ? 'on'
                              : 'off',
                        ),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            connecting
                                ? StarlitL10n.of(
                                    context,
                                    ru: 'Соединение',
                                    en: 'Connecting',
                                  )
                                : running
                                ? StarlitL10n.of(
                                    context,
                                    ru: 'Подключено',
                                    en: 'Connected',
                                  )
                                : StarlitL10n.of(
                                    context,
                                    ru: 'Не подключено',
                                    en: 'Not connected',
                                  ),
                            style: starlitText(
                              size: 42,
                              weight: FontWeight.w800,
                              height: 1.05,
                              letterSpacing: -1.2,
                              display: true,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            connecting
                                ? (activeCc == null
                                      ? StarlitL10n.of(
                                          context,
                                          ru: 'линия до сервера…',
                                          en: 'reaching the server…',
                                        )
                                      : '$here → ${StarlitServers.countryTitle(activeCc)}')
                                : running
                                ? (selected == null
                                      ? StarlitL10n.of(
                                          context,
                                          ru: 'сервер выбран',
                                          en: 'server selected',
                                        )
                                      : StarlitServers.displayName(selected))
                                : StarlitL10n.of(
                                    context,
                                    ru: '$here · нажмите кнопку справа',
                                    en: '$here · tap the button on the right',
                                  ),
                            style: starlitText(
                              size: 15,
                              color: StarlitColors.muted,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _daysLabel(context, daysLeft),
                            style: starlitText(
                              size: 13,
                              weight: FontWeight.w600,
                              color: daysLeft == null
                                  ? StarlitColors.muted2
                                  : daysLeft <= 3
                                  ? const Color(0xFFFF8A7A)
                                  : StarlitColors.accent,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _TrafficBar(
                            usedBytes: usedBytes,
                            totalBytes: totalBytes,
                          ),
                          if (running && !connecting) ...[
                            const SizedBox(height: 14),
                            _LiveSpeed(
                              up: engine.upBps,
                              down: engine.downBps,
                            ),
                          ],
                          if (_connectError != null &&
                              !running &&
                              !connecting) ...[
                            const SizedBox(height: 12),
                            Text(
                              _connectError!,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: starlitText(
                                size: 12,
                                weight: FontWeight.w600,
                                color: const Color(0xFFFF8A7A),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: 380,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 20, 20, 20),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 480),
                  curve: Curves.easeOutCubic,
                  builder: (context, t, child) => Opacity(
                    opacity: t,
                    child: Transform.translate(
                      offset: Offset(18 * (1 - t), 0),
                      child: child,
                    ),
                  ),
                  child: StarlitCard(
                    padding: const EdgeInsets.fromLTRB(12, 14, 8, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _autopilot
                              ? StarlitL10n.of(
                                  context,
                                  ru: 'Автопилот',
                                  en: 'Autopilot',
                                )
                              : StarlitL10n.of(
                                  context,
                                  ru: 'Подключение',
                                  en: 'Connection',
                                ),
                          textAlign: TextAlign.center,
                          style: starlitText(
                            size: 16,
                            weight: FontWeight.w700,
                            display: true,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _autopilot
                              ? StarlitL10n.of(
                                  context,
                                  ru: 'при обрыве сменит сервер сам',
                                  en: 'switches server if the link drops',
                                )
                              : (selected == null
                                    ? StarlitL10n.of(
                                        context,
                                        ru: 'выберите сервер ниже',
                                        en: 'pick a server below',
                                      )
                                    : StarlitServers.displayName(selected)),
                          textAlign: TextAlign.center,
                          style: starlitText(
                            size: 12,
                            color: StarlitColors.muted2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: _ConnectButton(
                            running: running,
                            connecting: connecting,
                            onTap: () => unawaited(_toggleConnect()),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: Stack(
                            clipBehavior: Clip.hardEdge,
                            children: [
                              Positioned(
                                top: 44,
                                left: 0,
                                right: 0,
                                bottom: 0,
                                child: visible.isEmpty
                                    ? Center(
                                        child: Text(
                                          StarlitL10n.of(
                                            context,
                                            ru: 'Добавьте подписку — здесь появятся страны',
                                            en: 'Add a subscription — countries will show up here',
                                          ),
                                          textAlign: TextAlign.center,
                                          style: starlitText(
                                            size: 13,
                                            color: StarlitColors.muted,
                                          ),
                                        ),
                                      )
                                    : ValueListenableBuilder<bool>(
                                        valueListenable:
                                            StarlitPing.sortByPing,
                                        builder: (context, _, _) {
                                          final list = StarlitPing.ordered(
                                            visible,
                                            engine,
                                          );
                                          return ValueListenableBuilder<bool>(
                                            valueListenable: StarlitPing.busy,
                                            builder: (context, busy, _) {
                                              return StarlitScrollbar(
                                                controller: _serversScroll,
                                                contentRight: 6,
                                                child: ListView.builder(
                                                  controller: _serversScroll,
                                                  primary: false,
                                                  physics:
                                                      const BouncingScrollPhysics(
                                                    parent:
                                                        AlwaysScrollableScrollPhysics(),
                                                  ),
                                                  clipBehavior: Clip.hardEdge,
                                                  itemCount: list.length,
                                                  itemBuilder: (context, i) {
                                                    final p = list[i];
                                                    return _ServerTile(
                                                      node: p,
                                                      delay:
                                                          StarlitPing.delayOf(
                                                            engine,
                                                            p,
                                                          ),
                                                      testing: busy,
                                                      active:
                                                          p.id ==
                                                          engine.selectedId,
                                                      onTap: () => unawaited(
                                                        _selectProxy(p),
                                                      ),
                                                    );
                                                  },
                                                ),
                                              );
                                            },
                                          );
                                        },
                                      ),
                              ),
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 6,
                                height: 36,
                                child: ColoredBox(
                                  color: const Color(0xB81E1828),
                                  child: _ToolsRow(
                                    updatingSub: _updatingSub,
                                    onRefresh: () =>
                                        unawaited(_refreshSubscription()),
                                    onPing: () =>
                                        unawaited(StarlitPing.run(ref)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Column(
                            children: [
                        _MiniSwitchRow(
                          title: StarlitL10n.of(
                            context,
                            ru: 'Автопилот',
                            en: 'Autopilot',
                          ),
                          subtitle: StarlitL10n.of(
                            context,
                            ru: 'лучший сервер и смена, если упал',
                            en: 'best server and failover if it drops',
                          ),
                          value: _autopilot,
                          onChanged: (v) {
                            setState(() => _autopilot = v);
                            unawaited(StarlitPrefs.setAutopilot(v));
                            if (v) {
                              unawaited(
                                StarlitPing.run(ref).then(
                                  (_) => StarlitAutopilot.preselectBest(ref),
                                ),
                              );
                            }
                          },
                        ),
                        _MiniSwitchRow(
                          title: StarlitL10n.of(
                            context,
                            ru: 'Обход БС',
                            en: 'Whitelist bypass',
                          ),
                          subtitle: StarlitL10n.of(
                            context,
                            ru: 'когда режут белыми списками',
                            en: 'when traffic is cut by allowlists',
                          ),
                          value: _bypass,
                          onChanged: (v) {
                            setState(() => _bypass = v);
                            unawaited(StarlitPrefs.setBypass(v));
                            final lte = [
                              for (final p in visible)
                                if (StarlitServers.isLte(p.name)) p,
                            ];
                            if (v && lte.isNotEmpty) {
                              unawaited(_selectProxy(lte.first));
                            }
                          },
                        ),
                        _MiniSwitchRow(
                          title: StarlitL10n.of(
                            context,
                            ru: 'Режим TUN',
                            en: 'TUN mode',
                          ),
                          subtitle: StarlitL10n.of(
                            context,
                            ru: 'весь ПК: игры, Discord, программы',
                            en: 'whole PC: games, Discord, apps',
                          ),
                          value: engine.tun,
                          onChanged: (v) =>
                              unawaited(starlitSetTun(context, engine, v)),
                        ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ToolsRow extends StatelessWidget {
  const _ToolsRow({
    required this.updatingSub,
    required this.onRefresh,
    required this.onPing,
  });

  final bool updatingSub;
  final VoidCallback onRefresh;
  final VoidCallback onPing;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: StarlitPing.busy,
      builder: (context, pingBusy, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: StarlitPing.sortByPing,
          builder: (context, byPing, _) {
            return Row(
              children: [
                Expanded(
                  child: _ToolPill(
                    icon: 'refresh-cw',
                    label: StarlitL10n.of(context, ru: 'Обновить', en: 'Refresh'),
                    busy: updatingSub,
                    onTap: onRefresh,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _ToolPill(
                    icon: 'activity',
                    label: StarlitL10n.of(context, ru: 'Пинг', en: 'Ping'),
                    busy: pingBusy,
                    onTap: onPing,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _ToolPill(
                    icon: 'arrow-left-right',
                    label: byPing
                        ? StarlitL10n.of(context, ru: 'По пингу', en: 'By ping')
                        : StarlitL10n.of(context, ru: 'Список', en: 'List'),
                    onTap: () => StarlitPing.sortByPing.value = !byPing,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _ToolPill extends StatefulWidget {
  const _ToolPill({
    required this.icon,
    required this.label,
    required this.onTap,
    this.busy = false,
  });

  final String icon;
  final String label;
  final bool busy;
  final VoidCallback onTap;

  @override
  State<_ToolPill> createState() => _ToolPillState();
}

class _ToolPillState extends State<_ToolPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin;
  var _hover = false;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _sync();
  }

  @override
  void didUpdateWidget(covariant _ToolPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.busy != widget.busy) _sync();
  }

  void _sync() {
    if (widget.busy) {
      unawaited(_spin.repeat());
    } else {
      _spin.stop();
      _spin.value = 0;
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.busy ? null : widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          height: 34,
          alignment: Alignment.center,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            color: _hover
                ? StarlitColors.accent.withValues(alpha: 0.12)
                : const Color(0xFF14101A),
            border: Border.all(
              color: _hover || widget.busy
                  ? StarlitColors.accent.withValues(alpha: 0.5)
                  : StarlitColors.stroke,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              RotationTransition(
                turns: _spin,
                child: StarlitUi.icon(
                  widget.icon,
                  size: 13,
                  color: widget.busy
                      ? StarlitColors.accent
                      : StarlitColors.muted,
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: starlitText(
                    size: 11.5,
                    weight: FontWeight.w700,
                    height: 1,
                    color: StarlitColors.text,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConnectButton extends StatefulWidget {
  const _ConnectButton({
    required this.running,
    required this.connecting,
    required this.onTap,
  });

  final bool running;
  final bool connecting;
  final VoidCallback onTap;

  @override
  State<_ConnectButton> createState() => _ConnectButtonState();
}

class _ConnectButtonState extends State<_ConnectButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin;
  var _hover = false;
  var _down = false;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _sync();
  }

  @override
  void didUpdateWidget(covariant _ConnectButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.connecting != widget.connecting) _sync();
  }

  void _sync() {
    if (widget.connecting) {
      unawaited(_spin.repeat());
    } else {
      _spin.stop();
      _spin.value = 0;
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lit = widget.running || widget.connecting;
    final accent = StarlitColors.accent;
    final deep = StarlitColors.accentDeep;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _down
              ? 0.96
              : _hover
              ? 1.03
              : 1,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: 112,
            height: 112,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: lit
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [accent, deep],
                    )
                  : null,
              color: lit ? null : const Color(0xFF1B1624),
              border: Border.all(
                color: lit
                    ? accent.withValues(alpha: 0.9)
                    : (_hover
                          ? StarlitColors.muted
                          : StarlitColors.stroke),
                width: 1.6,
              ),
              boxShadow: [
                if (lit)
                  BoxShadow(
                    color: accent.withValues(alpha: 0.35),
                    blurRadius: 28,
                    spreadRadius: 1,
                  ),
                BoxShadow(
                  color: const Color(0x66000000),
                  blurRadius: _hover ? 18 : 12,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (widget.connecting)
                  RotationTransition(
                    turns: _spin,
                    child: CustomPaint(
                      size: const Size(112, 112),
                      painter: _ConnectSpinPainter(color: accent),
                    ),
                  ),
                Opacity(
                  opacity: lit ? 1 : 0.92,
                  child: const StarlitLogo(size: 46),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConnectSpinPainter extends CustomPainter {
  const _ConnectSpinPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 3;
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 1.35,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.85),
    );
  }

  @override
  bool shouldRepaint(covariant _ConnectSpinPainter old) => old.color != color;
}

class _ServerTile extends StatelessWidget {
  const _ServerTile({
    required this.node,
    required this.delay,
    required this.testing,
    required this.active,
    required this.onTap,
  });

  final StarlitNode node;
  final int? delay;
  final bool testing;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cc = StarlitServers.countryCode(node.name);
    final title = StarlitServers.displayName(node.name);
    final whitelist = StarlitServers.isLte(node.name);
    final ok = delay != null && delay! > 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: StarlitCard(
        highlighted: active,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: StarlitColors.field,
                border: Border.all(
                  color: whitelist
                      ? StarlitColors.warn.withValues(alpha: 0.7)
                      : StarlitColors.stroke,
                ),
              ),
              child: Text(
                StarlitServers.flagEmoji(cc),
                style: const TextStyle(fontFamily: 'Twemoji', fontSize: 14),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: starlitText(
                      size: 13,
                      weight: active ? FontWeight.w700 : FontWeight.w500,
                      height: 1.2,
                    ),
                  ),
                  if (whitelist)
                    Text(
                      'LTE · белые списки',
                      style: starlitText(
                        size: 10,
                        weight: FontWeight.w600,
                        color: StarlitColors.warn,
                        height: 1.2,
                      ),
                    ),
                ],
              ),
            ),
            if (ok)
              Text(
                '$delay мс',
                style: starlitText(
                  size: 12,
                  weight: FontWeight.w700,
                  color: delay! < 150
                      ? StarlitColors.success
                      : delay! < 400
                      ? StarlitColors.warn
                      : StarlitColors.muted,
                ),
              )
            else if (testing)
              Text(
                '···',
                style: starlitText(size: 12, color: StarlitColors.muted2),
              )
            else if (delay != null && delay! <= 0)
              Text(
                StarlitL10n.of(context, ru: 'таймаут', en: 'timeout'),
                style: starlitText(size: 11, color: StarlitColors.danger),
              ),
          ],
        ),
      ),
    );
  }
}

class _TrafficBar extends StatelessWidget {
  const _TrafficBar({required this.usedBytes, required this.totalBytes});

  final int usedBytes;
  final int totalBytes;

  @override
  Widget build(BuildContext context) {
    final hasCap = totalBytes > 0;
    final ratio = hasCap ? (usedBytes / totalBytes).clamp(0.0, 1.0) : 0.0;
    final label = hasCap
        ? '${usedBytes.traffic.show} / ${totalBytes.traffic.show}'
        : usedBytes > 0
        ? usedBytes.traffic.show
        : StarlitL10n.of(
            context,
            ru: 'трафик без лимита',
            en: 'unlimited traffic',
          );
    final fill = ratio >= 0.9
        ? const Color(0xFFFF8A7A)
        : ratio >= 0.7
        ? StarlitColors.warn
        : StarlitColors.accent;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 280),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  StarlitL10n.of(
                    context,
                    ru: 'Трафик подписки',
                    en: 'Subscription traffic',
                  ),
                  style: starlitText(
                    size: 11,
                    weight: FontWeight.w600,
                    color: StarlitColors.muted2,
                  ),
                ),
              ),
              Text(
                hasCap ? '${(ratio * 100).round()}%' : '∞',
                style: starlitText(
                  size: 11,
                  weight: FontWeight.w700,
                  color: fill,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 7,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: StarlitColors.field,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: StarlitColors.stroke),
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: hasCap ? math.max(ratio, ratio > 0 ? 0.02 : 0) : 0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: fill,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: starlitText(
              size: 12,
              weight: FontWeight.w600,
              color: StarlitColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveSpeed extends StatelessWidget {
  const _LiveSpeed({required this.up, required this.down});

  final int up;
  final int down;

  static String _fmt(int bps) {
    if (bps < 1024) return '$bps B/s';
    if (bps < 1024 * 1024) return '${(bps / 1024).toStringAsFixed(1)} KB/s';
    return '${(bps / (1024 * 1024)).toStringAsFixed(2)} MB/s';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '↓ ${_fmt(down)}',
          style: starlitText(
            size: 13,
            weight: FontWeight.w700,
            color: StarlitColors.success,
          ),
        ),
        const SizedBox(width: 16),
        Text(
          '↑ ${_fmt(up)}',
          style: starlitText(
            size: 13,
            weight: FontWeight.w700,
            color: StarlitColors.accent,
          ),
        ),
      ],
    );
  }
}

class _MiniSwitchRow extends StatelessWidget {
  const _MiniSwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: starlitText(
                    size: 13,
                    weight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
                Text(
                  subtitle,
                  style: starlitText(
                    size: 11,
                    color: StarlitColors.muted2,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          StarlitToggle(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
