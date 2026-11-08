import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:starlit_connect/starlit/client_geo.dart';
import 'package:starlit_connect/starlit/prefs.dart';
import 'package:starlit_connect/starlit/servers.dart';
import 'package:starlit_connect/starlit/status_api.dart';
import 'package:starlit_connect/starlit/theme.dart';
import 'package:starlit_connect/starlit/world_geo.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

Offset? starlitGlobeProject(
  Size size,
  double lat,
  double lon, {
  required double lat0,
  required double lon0,
  double radiusFactor = 0.42,
}) {
  final r = size.shortestSide * radiusFactor;
  final c = Offset(size.width * 0.48, size.height * 0.50);
  final phi = lat * math.pi / 180;
  final lam = lon * math.pi / 180;
  final phi0 = lat0 * math.pi / 180;
  final lam0 = lon0 * math.pi / 180;
  final dLam = lam - lam0;
  final cosC =
      math.sin(phi0) * math.sin(phi) +
      math.cos(phi0) * math.cos(phi) * math.cos(dLam);
  if (cosC < 0.02) return null;
  final x = r * math.cos(phi) * math.sin(dLam);
  final y =
      r *
      (math.cos(phi0) * math.sin(phi) -
          math.sin(phi0) * math.cos(phi) * math.cos(dLam));
  return Offset(c.dx + x, c.dy - y);
}

/// Inverse orthographic → lat/lon under the pointer (or null off-globe).
({double lat, double lon})? starlitGlobeUnproject(
  Size size,
  Offset local, {
  required double lat0,
  required double lon0,
  double radiusFactor = 0.42,
}) {
  final r = size.shortestSide * radiusFactor;
  final c = Offset(size.width * 0.48, size.height * 0.50);
  final x = (local.dx - c.dx) / r;
  final y = (c.dy - local.dy) / r;
  final rho2 = x * x + y * y;
  if (rho2 > 0.995) return null;
  final rho = math.sqrt(rho2);
  final cAng = math.asin(rho.clamp(0.0, 1.0));
  final sinc = math.sin(cAng);
  final cosc = math.cos(cAng);
  final phi0 = lat0 * math.pi / 180;
  final lam0 = lon0 * math.pi / 180;
  final lat = math.asin(
    cosc * math.sin(phi0) + (y * sinc * math.cos(phi0) / (rho == 0 ? 1 : rho)),
  );
  final lon =
      lam0 +
      math.atan2(
        x * sinc,
        rho * math.cos(phi0) * cosc - y * math.sin(phi0) * sinc,
      );
  return (lat: lat * 180 / math.pi, lon: lon * 180 / math.pi);
}

/// 3D globe: real border map + semi-quiet land dots. Drag rotates, no pan.
class StarlitInteractiveMap extends StatefulWidget {
  const StarlitInteractiveMap({
    super.key,
    this.connected = false,
    this.connecting = false,
    this.activeCountry,
    this.availableCountries = const {},
  });

  final bool connected;
  final bool connecting;
  final String? activeCountry;
  /// ISO2 codes present in the user's subscription — drawn brighter.
  final Set<String> availableCountries;

  @override
  State<StarlitInteractiveMap> createState() => _StarlitInteractiveMapState();
}

class _StarlitInteractiveMapState extends State<StarlitInteractiveMap>
    with TickerProviderStateMixin {
  StarlitWorldGeo? _geo;
  List<StarlitPublicNode> _nodes = const [];
  _HoverInfo? _hover;
  Offset _hoverLocal = Offset.zero;

  var _lat0 = 38.0;
  var _lon0 = 48.0;
  var _dragging = false;
  var _zoom = 1.0;
  var _user = (lat: 55.75, lon: 37.62);
  String? _userCity;
  String? _userCountry;

  late final AnimationController _breath;
  late final AnimationController _arc;
  late final Ticker _viewTicker;
  Duration _lastTick = Duration.zero;

  @override
  void initState() {
    super.initState();
    _breath = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );
    _arc = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _viewTicker = createTicker(_onTick)..start();
    unawaited(_boot());
    _syncArc();
  }

  Future<void> _boot() async {
    final live = await StarlitPrefs.liveGlobe();
    final smooth = await StarlitPrefs.smoothMode();
    if (live && !smooth) {
      unawaited(_breath.repeat(reverse: true));
    } else {
      _breath.value = 0.5;
    }
    final geo = await StarlitWorldGeo.load();
    if (!mounted) return;
    setState(() => _geo = geo);
    unawaited(_loadNodes());
    unawaited(_loadClientGeo());
  }

  Future<void> _loadClientGeo() async {
    final client = await StarlitClientGeoApi.load();
    if (!mounted || client == null) return;
    setState(() {
      _user = (lat: client.lat, lon: client.lon);
      _userCity = client.city;
      _userCountry = client.countryCode;
      if (!widget.connected && !widget.connecting) {
        _lat0 = client.lat.clamp(-50.0, 65.0);
        _lon0 = client.lon;
      }
    });
  }

  Future<void> _loadNodes() async {
    try {
      final nodes = await StarlitStatusApi.fetchNodes();
      if (!mounted) return;
      setState(() => _nodes = nodes);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _nodes = [
          for (final e in const [
            ('NL', true),
            ('EE', true),
            ('DE', true),
            ('FI', false),
            ('PL', false),
            ('FR', false),
            ('JP', false),
            ('TR', false),
            ('AL', false),
            ('LT', false),
            ('LV', false),
            ('BY', false),
          ])
            StarlitPublicNode(
              id: e.$1,
              name: StarlitServers.countryTitle(e.$1),
              country: e.$1,
              whitelist: e.$2,
              state: 'up',
            ),
        ];
      });
    }
  }

  void _onTick(Duration elapsed) {
    final dt = _lastTick == Duration.zero
        ? 0.0
        : (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    if (dt <= 0 || dt > 0.05) return;

    final focus = widget.activeCountry;
    final engaged = (widget.connecting || widget.connected) && focus != null;
    final pos = !engaged
        ? null
        : StarlitServers.countryLatLon(focus) ?? _geo?.byIso2[focus]?.centroid;
    var zoomTarget = 1.0;
    if (pos != null) {
      final km = starlitDistanceKm(
        lat1: _user.lat,
        lon1: _user.lon,
        lat2: pos.lat,
        lon2: pos.lon,
      );
      zoomTarget = 1.0 + 1.35 * (1 - (km / 9000).clamp(0.0, 1.0));
    }
    var nLat = _lat0;
    var nLon = _lon0;
    if (!_dragging && pos != null) {
      final tLat = ((pos.lat + _user.lat) / 2).clamp(-50.0, 65.0);
      final tLon = _lerpLon(_user.lon, pos.lon, 0.5);
      final k = 1 - math.exp(-dt * 2.4);
      nLat = _lat0 + (tLat - _lat0) * k;
      nLon = _lerpLon(_lon0, tLon, k);
    }
    final nZoom = _zoom + (zoomTarget - _zoom) * (1 - math.exp(-dt * 2.2));
    if ((nLat - _lat0).abs() > 0.005 ||
        _lonDelta(_lon0, nLon).abs() > 0.005 ||
        (nZoom - _zoom).abs() > 0.0005) {
      setState(() {
        _lat0 = nLat;
        _lon0 = nLon;
        _zoom = nZoom;
      });
    }
  }

  @override
  void didUpdateWidget(covariant StarlitInteractiveMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final countryChanged =
        oldWidget.activeCountry != widget.activeCountry &&
        widget.activeCountry != null &&
        (widget.connecting || widget.connected);
    if (countryChanged) {
      unawaited(_arc.forward(from: 0));
      return;
    }
    if (oldWidget.connecting != widget.connecting ||
        oldWidget.connected != widget.connected ||
        oldWidget.activeCountry != widget.activeCountry) {
      _syncArc();
    }
  }

  void _syncArc() {
    final hasTarget = widget.activeCountry != null;
    if (widget.connecting && hasTarget) {
      unawaited(_arc.forward(from: 0));
      return;
    }
    if (widget.connected && hasTarget) {
      if (_arc.isAnimating) return;
      if (_arc.value < 1) {
        unawaited(_arc.forward());
      } else {
        _arc.value = 1;
      }
      return;
    }
    if (!widget.connecting && !widget.connected) {
      unawaited(_arc.reverse());
    }
  }

  @override
  void dispose() {
    _viewTicker.dispose();
    _breath.dispose();
    _arc.dispose();
    super.dispose();
  }

  Set<String> get _serverCountries => {for (final n in _nodes) n.country};

  _HoverInfo? _infoFor(String cc) {
    final geom = _geo?.byIso2[cc];
    final pos = StarlitServers.countryLatLon(cc) ?? geom?.centroid;
    if (pos == null) return null;
    final km = starlitDistanceKm(
      lat1: _user.lat,
      lon1: _user.lon,
      lat2: pos.lat,
      lon2: pos.lon,
    ).round();
    final node = _nodes.where((n) => n.country == cc).firstOrNull;
    return _HoverInfo(
      country: cc,
      title: StarlitServers.countryTitle(cc),
      fact: StarlitServers.countryFact(cc),
      km: km,
      hasServer: _serverCountries.contains(cc),
      whitelist: node?.whitelist ?? false,
      capital: StarlitServers.countryCapital(cc),
      lat: pos.lat,
      lon: pos.lon,
    );
  }

  void _onDragStart(DragStartDetails _) {
    _dragging = true;
  }

  void _onDragUpdate(DragUpdateDetails d) {
    setState(() {
      _lon0 = _wrapLon(_lon0 - d.delta.dx * 0.42);
      _lat0 = (_lat0 + d.delta.dy * 0.28).clamp(-55.0, 70.0);
      _hover = null;
    });
  }

  void _onDragEnd(DragEndDetails _) {
    _dragging = false;
  }

  void _onHover(PointerHoverEvent e, Size size) {
    if (_dragging || _geo == null) return;
    final local = e.localPosition;
    final ll = starlitGlobeUnproject(
      size,
      local,
      lat0: _lat0,
      lon0: _lon0,
      radiusFactor: 0.42 * _zoom,
    );
    if (ll == null) {
      if (_hover != null) setState(() => _hover = null);
      return;
    }
    final cc = _geo!.countryAt(ll.lat, ll.lon);
    if (cc == null) {
      if (_hover != null) setState(() => _hover = null);
      return;
    }
    final geom = _geo!.byIso2[cc];
    final pos = StarlitServers.countryLatLon(cc) ?? geom?.centroid;
    if (pos == null) return;
    final km = starlitDistanceKm(
      lat1: _user.lat,
      lon1: _user.lon,
      lat2: pos.lat,
      lon2: pos.lon,
    ).round();
    final hasServer = _serverCountries.contains(cc);
    final node = _nodes.where((n) => n.country == cc).firstOrNull;
    final info = _HoverInfo(
      country: cc,
      title: StarlitServers.countryTitle(cc),
      fact: StarlitServers.countryFact(cc),
      km: km,
      hasServer: hasServer,
      whitelist: node?.whitelist ?? false,
      capital: StarlitServers.countryCapital(cc),
      lat: pos.lat,
      lon: pos.lon,
    );
    setState(() {
      _hover = info;
      _hoverLocal = local;
    });
  }

  @override
  Widget build(BuildContext context) {
    final targetCc = widget.activeCountry ?? _hover?.country;
    final targetPos = targetCc == null
        ? null
        : (StarlitServers.countryLatLon(targetCc) ??
              _geo?.byIso2[targetCc]?.centroid);

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        if (_geo == null) {
          return const SizedBox.expand();
        }
        return MouseRegion(
          onHover: (e) => _onHover(e, size),
          onExit: (_) => setState(() => _hover = null),
          cursor: _dragging
              ? SystemMouseCursors.grabbing
              : SystemMouseCursors.grab,
          child: GestureDetector(
            onPanStart: _onDragStart,
            onPanUpdate: _onDragUpdate,
            onPanEnd: _onDragEnd,
            behavior: HitTestBehavior.opaque,
            child: AnimatedBuilder(
              animation: Listenable.merge([_breath, _arc]),
              builder: (context, _) {
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    CustomPaint(
                      size: size,
                      painter: _GlobePainter(
                        geo: _geo!,
                        lat0: _lat0,
                        lon0: _lon0,
                        connected: widget.connected,
                        connecting: widget.connecting,
                        hoverCountry: _hover?.country,
                        activeCountry: widget.activeCountry,
                        availableCountries: widget.availableCountries,
                        arcT: _arc.value,
                        breath: _breath.value,
                        targetLat: targetPos?.lat,
                        targetLon: targetPos?.lon,
                        zoom: _zoom,
                      ),
                    ),
                    if (starlitGlobeProject(
                          size,
                          _user.lat,
                          _user.lon,
                          lat0: _lat0,
                          lon0: _lon0,
                          radiusFactor: 0.42 * _zoom,
                        )
                        case final you?)
                      Positioned(
                        left: you.dx,
                        top: you.dy - 8,
                        child: FractionalTranslation(
                          translation: const Offset(-0.5, 0),
                          child: _YouMark(
                            breath: _breath.value,
                            connecting: widget.connecting,
                            label: _userCity?.isNotEmpty == true
                                ? _userCity!
                                : (_userCountry ?? 'Вы'),
                          ),
                        ),
                      ),
                    if (widget.connected && widget.activeCountry != null)
                      Builder(
                        builder: (context) {
                          final pinned = _infoFor(widget.activeCountry!);
                          if (pinned == null) return const SizedBox.shrink();
                          return Positioned(
                            right: 12,
                            bottom: 16,
                            child: _TooltipCard(info: pinned, pinned: true),
                          );
                        },
                      ),
                    if (_hover != null &&
                        _hover!.country != widget.activeCountry)
                      Positioned(
                        left: (_hoverLocal.dx + 20).clamp(
                          8.0,
                          size.width - 300,
                        ),
                        top: (_hoverLocal.dy - 10).clamp(
                          8.0,
                          size.height - 200,
                        ),
                        child: _TooltipCard(info: _hover!),
                      ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  static double _wrapLon(double lon) {
    var x = lon;
    while (x > 180) {
      x -= 360;
    }
    while (x < -180) {
      x += 360;
    }
    return x;
  }

  static double _lonDelta(double a, double b) {
    var d = b - a;
    while (d > 180) {
      d -= 360;
    }
    while (d < -180) {
      d += 360;
    }
    return d;
  }

  static double _lerpLon(double a, double b, double t) =>
      _wrapLon(a + _lonDelta(a, b) * t);

}

class _YouMark extends StatelessWidget {
  const _YouMark({
    required this.breath,
    required this.connecting,
    this.label = 'Вы',
  });
  final double breath;
  final bool connecting;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ring = connecting ? 8 + breath * 16 : 0.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 36,
          height: 12,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              if (connecting)
                Container(
                  width: 10 + ring,
                  height: 10 + ring,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF8EC5FF).withValues(
                        alpha: (1 - breath) * 0.55,
                      ),
                    ),
                  ),
                ),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFF4F6FA),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFFFFF).withValues(
                        alpha: 0.35 + breath * 0.35,
                      ),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          softWrap: false,
          maxLines: 1,
          overflow: TextOverflow.visible,
          textAlign: TextAlign.center,
          style: starlitText(
            size: 10,
            weight: FontWeight.w700,
            color: StarlitColors.text,
          ),
        ),
      ],
    );
  }
}

class _HoverInfo {
  const _HoverInfo({
    required this.country,
    required this.title,
    required this.fact,
    required this.km,
    required this.hasServer,
    required this.whitelist,
    required this.lat,
    required this.lon,
    this.capital,
  });

  final String country;
  final String title;
  final String fact;
  final int km;
  final bool hasServer;
  final bool whitelist;
  final String? capital;
  final double lat;
  final double lon;
}

class _TooltipCard extends StatelessWidget {
  const _TooltipCard({required this.info, this.pinned = false});
  final _HoverInfo info;
  final bool pinned;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().toUtc().add(_tz(info.country));
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    final lightMs = (info.km / 299.792 * 2).clamp(1, 9999).round();

    return IgnorePointer(
      child: Container(
        width: pinned ? 300 : 280,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xF21A1524), Color(0xEE0E0A14)],
          ),
          border: Border.all(
            color: pinned
                ? const Color(0x668EC5FF)
                : const Color(0x338EC5FF),
            width: pinned ? 1.4 : 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x99000000),
              blurRadius: 28,
              offset: Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  StarlitServers.flagEmoji(info.country),
                  style: const TextStyle(fontFamily: 'Twemoji', fontSize: 18),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    info.title,
                    style: starlitText(
                      weight: FontWeight.w800,
                      size: 16,
                      display: true,
                    ),
                  ),
                ),
                Text(
                  '$hh:$mm',
                  style: starlitText(
                    color: StarlitColors.muted,
                    size: 12,
                    weight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            if (info.capital != null) ...[
              const SizedBox(height: 3),
              Text(
                'Столица: ${info.capital}',
                style: starlitText(color: StarlitColors.muted2, size: 12),
              ),
            ],
            const SizedBox(height: 10),
            Text(
              _formatKm(info.km),
              style: starlitText(
                color: const Color(0xFF9EC9FF),
                size: 13,
                weight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Свет пролетел бы туда и обратно за $lightMs мс',
              style: starlitText(color: StarlitColors.muted2, size: 11),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: info.hasServer
                          ? StarlitColors.success
                          : const Color(0xFF8EC5FF),
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: info.hasServer
                            ? StarlitColors.success
                            : const Color(0xFF8EC5FF),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    info.hasServer
                        ? (info.whitelist
                              ? 'Есть сервер · белые списки / LTE'
                              : 'Есть сервер Starlit')
                        : 'Здесь наших серверов пока нет.',
                    style: starlitText(
                      color: info.hasServer
                          ? StarlitColors.success
                          : StarlitColors.muted,
                      size: 12,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              info.fact,
              style: starlitText(color: StarlitColors.muted, size: 12),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatKm(int km) {
    if (km >= 1000) {
      final v = (km / 1000).toStringAsFixed(1).replaceAll('.', ',');
      return '$v тыс. км от вас';
    }
    return '≈ $km км от вас';
  }

  static Duration _tz(String cc) => switch (cc) {
    'JP' || 'CN' => const Duration(hours: 8),
    'TR' ||
    'AL' ||
    'FI' ||
    'EE' ||
    'LT' ||
    'LV' ||
    'BY' ||
    'RU' ||
    'UA' ||
    'RS' =>
      const Duration(hours: 3),
    'DE' || 'NL' || 'FR' || 'PL' || 'IT' || 'ES' || 'SE' || 'BE' =>
      const Duration(hours: 2),
    'GB' => const Duration(hours: 1),
    _ => const Duration(hours: 3),
  };
}

class _GlobePainter extends CustomPainter {
  _GlobePainter({
    required this.geo,
    required this.lat0,
    required this.lon0,
    required this.connected,
    required this.connecting,
    required this.hoverCountry,
    required this.activeCountry,
    required this.availableCountries,
    required this.arcT,
    required this.breath,
    this.targetLat,
    this.targetLon,
    this.zoom = 1.0,
  });

  final StarlitWorldGeo geo;
  final double lat0;
  final double lon0;
  final bool connected;
  final bool connecting;
  final String? hoverCountry;
  final String? activeCountry;
  final Set<String> availableCountries;
  final double arcT;
  final double breath;
  final double? targetLat;
  final double? targetLon;
  final double zoom;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width * 0.48, size.height * 0.50);
    final r = size.shortestSide * 0.42 * zoom;

    _paintGlobeGlow(canvas, c, r);

    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFF14101C), Color(0xFF0A0810), Color(0xFF05040A)],
          stops: [0, 0.72, 1],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );

    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = Color.lerp(
          const Color(0x338EC5FF),
          const Color(0x558EC5FF),
          breath,
        )!,
    );

    // Sun terminator for real-time day → night shimmer on land dots
    final sun = _subsolar(DateTime.now().toUtc());
    // Muted warm day tint — not neon yellow
    const dayColor = Color(0xFFB8926A);
    const dayHot = Color(0xFFC9A57A);
    const nightColor = Color(0xFF6E7888);

    // 1) Land dots: soft amber in daylight → grey at night
    final dotPaint = Paint()..style = PaintingStyle.fill;
    for (final s in geo.landDots) {
      final o = starlitGlobeProject(
        size,
        s.$1,
        s.$2,
        lat0: lat0,
        lon0: lon0,
        radiusFactor: 0.42 * zoom,
      );
      if (o == null) continue;
      final day = _sunlit(s.$1, s.$2, sun.lat, sun.lon);
      final shimmer = day * (0.96 + 0.04 * breath);
      final color = Color.lerp(
        nightColor,
        Color.lerp(dayColor, dayHot, shimmer)!,
        day * 0.72,
      )!;
      final alpha = 0.22 + 0.28 * day + 0.04 * breath * day;
      dotPaint.color = color.withValues(alpha: alpha.clamp(0.18, 0.55));
      canvas.drawCircle(o, 0.85 + 0.22 * day, dotPaint);
    }

    // 2) Border map — thin faint country outlines everywhere
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0x55A8B4C8);
    for (final country in geo.countries) {
      for (final ring in country.rings) {
        final path = _projectRing(size, ring);
        if (path != null) canvas.drawPath(path, borderPaint);
      }
    }

    // 2b) Subscription countries — lighter fill + brighter rim
    if (availableCountries.isNotEmpty) {
      for (final code in availableCountries) {
        final geom = geo.byIso2[code];
        if (geom == null) continue;
        for (final ring in geom.rings) {
          final path = _projectRing(size, ring);
          if (path == null) continue;
          canvas.drawPath(
            path,
            Paint()
              ..style = PaintingStyle.fill
              ..color = Color.lerp(
                const Color(0x228EC5FF),
                const Color(0x338EC5FF),
                breath,
              )!,
          );
          canvas.drawPath(
            path,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.15
              ..strokeJoin = StrokeJoin.round
              ..color = Color.lerp(
                const Color(0x99C8DCFF),
                const Color(0xBBD8E8FF),
                breath,
              )!,
          );
        }
      }
    }

    // 3) Active country — fill with flag layout + bright rim
    if (activeCountry != null) {
      final geom = geo.byIso2[activeCountry];
      if (geom != null) {
        final flag = StarlitServers.flagColors(activeCountry);
        final layout = StarlitServers.flagLayout(activeCountry);
        final primary = Color(flag.first);
        final rim = Color(flag.length > 1 ? flag[1] : flag.first);
        // Prefer the largest landmass for emblem layouts (JP/TR/AL marks).
        final paths = <({Path path, Rect bounds, double area})>[];
        for (final ring in geom.rings) {
          final path = _projectRing(size, ring);
          if (path == null) continue;
          final bounds = path.getBounds();
          paths.add((
            path: path,
            bounds: bounds,
            area: bounds.width * bounds.height,
          ));
        }
        paths.sort((a, b) => b.area.compareTo(a.area));
        final emblem =
            layout == 'circle' ||
            layout == 'disc' ||
            layout == 'crescent' ||
            layout == 'eagle' ||
            layout == 'swiss';
        for (var i = 0; i < paths.length; i++) {
          final item = paths[i];
          canvas.save();
          canvas.clipPath(item.path);
          if (emblem && i > 0) {
            canvas.drawRect(
              item.bounds,
              Paint()..color = primary.withValues(alpha: 0.90),
            );
          } else {
            _paintFlagFill(canvas, item.bounds, flag, layout);
          }
          canvas.restore();
          canvas.drawPath(
            item.path,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3.6
              ..strokeJoin = StrokeJoin.round
              ..color = rim.withValues(alpha: 0.45)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
          );
          canvas.drawPath(
            item.path,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.7
              ..strokeJoin = StrokeJoin.round
              ..color = Color.lerp(
                const Color(0xFFFFFFFF),
                primary,
                0.25,
              )!,
          );
        }
      }
    }

    // 4) Hover (other country) — soft neon stroke
    final focus = hoverCountry;
    if (focus != null && focus != activeCountry) {
      final geom = geo.byIso2[focus];
      if (geom != null) {
        for (final ring in geom.rings) {
          final path = _projectRing(size, ring);
          if (path == null) continue;
          canvas.drawPath(
            path,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3.2
              ..strokeJoin = StrokeJoin.round
              ..color = const Color(0x668EC5FF)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
          );
          canvas.drawPath(
            path,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.35
              ..strokeJoin = StrokeJoin.round
              ..color = Color.lerp(
                const Color(0xFFE8F0FF),
                const Color(0xFFB794E8),
                breath * 0.35,
              )!,
          );
        }
      }
    }

    if (arcT > 0.01 && targetLat != null && targetLon != null) {
      _drawArc(canvas, size);
    }
  }

  /// Approximate subsolar point for current UTC (degrees).
  static ({double lat, double lon}) _subsolar(DateTime utc) {
    final start = DateTime.utc(utc.year);
    final day =
        utc.difference(start).inMilliseconds / Duration.millisecondsPerDay;
    final decl = 23.44 * math.sin((2 * math.pi / 365.2422) * (day - 81));
    final hours = utc.hour + utc.minute / 60.0 + utc.second / 3600.0;
    final lon = 15.0 * (12.0 - hours);
    return (lat: decl, lon: lon);
  }

  static void _paintFlagFill(
    Canvas canvas,
    Rect bounds,
    List<int> colors,
    String layout,
  ) {
    if (colors.isEmpty || bounds.isEmpty) return;
    Color ink(int i) =>
        Color(colors[i.clamp(0, colors.length - 1)]).withValues(alpha: 0.90);

    switch (layout) {
      case 'vertical':
        final band = bounds.width / colors.length;
        for (var i = 0; i < colors.length; i++) {
          canvas.drawRect(
            Rect.fromLTWH(bounds.left + i * band, bounds.top, band, bounds.height),
            Paint()..color = ink(i),
          );
        }
        return;
      case 'nordic':
        canvas.drawRect(bounds, Paint()..color = ink(0));
        final cross = Paint()..color = ink(1);
        final bar = math.max(3.0, bounds.shortestSide * 0.20);
        final x = bounds.left + bounds.width * 0.34;
        canvas.drawRect(
          Rect.fromLTWH(bounds.left, bounds.center.dy - bar / 2, bounds.width, bar),
          cross,
        );
        canvas.drawRect(
          Rect.fromLTWH(x - bar / 2, bounds.top, bar, bounds.height),
          cross,
        );
        if (colors.length > 2) {
          final inner = Paint()..color = ink(2);
          final thin = math.max(2.0, bar * 0.42);
          canvas.drawRect(
            Rect.fromLTWH(
              bounds.left,
              bounds.center.dy - thin / 2,
              bounds.width,
              thin,
            ),
            inner,
          );
          canvas.drawRect(
            Rect.fromLTWH(x - thin / 2, bounds.top, thin, bounds.height),
            inner,
          );
        }
        return;
      case 'circle':
        // Japan / Bangladesh: field + centred disc.
        canvas.drawRect(bounds, Paint()..color = ink(0));
        canvas.drawCircle(
          bounds.center,
          math.max(4.0, bounds.shortestSide * 0.30),
          Paint()..color = ink(1),
        );
        return;
      case 'disc':
        // Solid field + accent disc (CN / VN / …).
        canvas.drawRect(bounds, Paint()..color = ink(0));
        if (colors.length > 1) {
          canvas.drawCircle(
            Offset(
              bounds.left + bounds.width * 0.45,
              bounds.center.dy,
            ),
            math.max(3.0, bounds.shortestSide * 0.22),
            Paint()..color = ink(1),
          );
        }
        return;
      case 'crescent':
        // Turkey: red field + white crescent and five-point star.
        canvas.drawRect(bounds, Paint()..color = ink(0));
        final moon = ink(1);
        final field = ink(0);
        final cx = bounds.left + bounds.width * 0.42;
        final cy = bounds.center.dy;
        final r = math.max(5.0, bounds.shortestSide * 0.30);
        canvas.drawCircle(Offset(cx, cy), r, Paint()..color = moon);
        canvas.drawCircle(
          Offset(cx + r * 0.40, cy),
          r * 0.78,
          Paint()..color = field,
        );
        canvas.drawPath(
          _fivePointStar(
            Offset(cx + r * 0.78, cy),
            math.max(2.5, r * 0.34),
          ),
          Paint()..color = moon,
        );
        return;
      case 'eagle':
        // Albania: red field + black double-headed eagle silhouette.
        canvas.drawRect(bounds, Paint()..color = ink(0));
        canvas.drawPath(
          _albanianEagle(
            bounds.center,
            math.max(8.0, bounds.shortestSide * 0.55),
          ),
          Paint()..color = ink(1),
        );
        return;
      case 'belarus':
        // Red over green ≈ 2:1.
        final split = bounds.top + bounds.height * (2 / 3);
        canvas.drawRect(
          Rect.fromLTRB(bounds.left, bounds.top, bounds.right, split),
          Paint()..color = ink(0),
        );
        canvas.drawRect(
          Rect.fromLTRB(bounds.left, split, bounds.right, bounds.bottom),
          Paint()..color = ink(1),
        );
        return;
      case 'latvia':
        // Carmine / thin white / carmine.
        final h = bounds.height;
        final white = math.max(2.0, h * 0.20);
        final carmine = (h - white) / 2;
        canvas.drawRect(
          Rect.fromLTWH(bounds.left, bounds.top, bounds.width, carmine),
          Paint()..color = ink(0),
        );
        canvas.drawRect(
          Rect.fromLTWH(bounds.left, bounds.top + carmine, bounds.width, white),
          Paint()..color = ink(1),
        );
        canvas.drawRect(
          Rect.fromLTWH(
            bounds.left,
            bounds.top + carmine + white,
            bounds.width,
            carmine,
          ),
          Paint()..color = ink(2),
        );
        return;
      case 'swiss':
        canvas.drawRect(bounds, Paint()..color = ink(0));
        final cross = Paint()..color = ink(colors.length > 1 ? 1 : 0);
        final arm = bounds.shortestSide * 0.18;
        final long = bounds.shortestSide * 0.55;
        final c = bounds.center;
        canvas.drawRect(
          Rect.fromCenter(center: c, width: long, height: arm),
          cross,
        );
        canvas.drawRect(
          Rect.fromCenter(center: c, width: arm, height: long),
          cross,
        );
        return;
      default:
        final band = bounds.height / math.max(colors.length, 1);
        for (var i = 0; i < colors.length; i++) {
          canvas.drawRect(
            Rect.fromLTWH(bounds.left, bounds.top + i * band, bounds.width, band),
            Paint()..color = ink(i),
          );
        }
    }
  }

  static Path _fivePointStar(Offset c, double r) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final a = -math.pi / 2 + i * math.pi / 5;
      final rad = i.isEven ? r : r * 0.40;
      final p = Offset(c.dx + math.cos(a) * rad, c.dy + math.sin(a) * rad);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    return path;
  }

  /// Compact double-headed eagle readable at country-fill scale.
  static Path _albanianEagle(Offset c, double s) {
    final path = Path();
    // Left wing.
    path.moveTo(c.dx, c.dy - s * 0.02);
    path.lineTo(c.dx - s * 0.18, c.dy - s * 0.18);
    path.quadraticBezierTo(
      c.dx - s * 0.62,
      c.dy - s * 0.42,
      c.dx - s * 0.55,
      c.dy + s * 0.05,
    );
    path.quadraticBezierTo(
      c.dx - s * 0.48,
      c.dy + s * 0.32,
      c.dx - s * 0.12,
      c.dy + s * 0.18,
    );
    // Right wing (mirror).
    path.lineTo(c.dx + s * 0.12, c.dy + s * 0.18);
    path.quadraticBezierTo(
      c.dx + s * 0.48,
      c.dy + s * 0.32,
      c.dx + s * 0.55,
      c.dy + s * 0.05,
    );
    path.quadraticBezierTo(
      c.dx + s * 0.62,
      c.dy - s * 0.42,
      c.dx + s * 0.18,
      c.dy - s * 0.18,
    );
    path.close();
    // Left head.
    path.addOval(
      Rect.fromCenter(
        center: Offset(c.dx - s * 0.12, c.dy - s * 0.28),
        width: s * 0.20,
        height: s * 0.18,
      ),
    );
    // Right head.
    path.addOval(
      Rect.fromCenter(
        center: Offset(c.dx + s * 0.12, c.dy - s * 0.28),
        width: s * 0.20,
        height: s * 0.18,
      ),
    );
    // Tail.
    path.moveTo(c.dx - s * 0.08, c.dy + s * 0.16);
    path.lineTo(c.dx, c.dy + s * 0.42);
    path.lineTo(c.dx + s * 0.08, c.dy + s * 0.16);
    path.close();
    return path;
  }

  /// 0 = night, 1 = day; smooth terminator band.
  static double _sunlit(
    double lat,
    double lon,
    double subLat,
    double subLon,
  ) {
    final phi = lat * math.pi / 180;
    final delta = subLat * math.pi / 180;
    var dLon = (lon - subLon) * math.pi / 180;
    while (dLon > math.pi) {
      dLon -= 2 * math.pi;
    }
    while (dLon < -math.pi) {
      dLon += 2 * math.pi;
    }
    final cosZ =
        math.sin(phi) * math.sin(delta) +
        math.cos(phi) * math.cos(delta) * math.cos(dLon);
    // Wide soft band around terminator (~±12° of zenith cosine)
    return ((cosZ + 0.18) / 0.48).clamp(0.0, 1.0);
  }

  Path? _projectRing(Size size, List<(double, double)> ring) {
    final path = Path();
    var started = false;
    Offset? prev;
    for (final p in ring) {
      final o = starlitGlobeProject(
        size,
        p.$1,
        p.$2,
        lat0: lat0,
        lon0: lon0,
        radiusFactor: 0.42 * zoom,
      );
      if (o == null) {
        started = false;
        prev = null;
        continue;
      }
      // Skip huge jumps across the backface silhouette
      if (prev != null && (o - prev).distance > size.shortestSide * 0.22 * zoom) {
        started = false;
      }
      if (!started) {
        path.moveTo(o.dx, o.dy);
        started = true;
      } else {
        path.lineTo(o.dx, o.dy);
      }
      prev = o;
    }
    return started ? path : null;
  }

  void _drawArc(Canvas canvas, Size size) {
    const fromLat = 55.75;
    const fromLon = 37.62;
    final toLat = targetLat!;
    final toLon = targetLon!;
    const p1 = fromLat * math.pi / 180;
    const l1 = fromLon * math.pi / 180;
    final p2 = toLat * math.pi / 180;
    final l2 = toLon * math.pi / 180;
    final cosD =
        math.sin(p1) * math.sin(p2) +
        math.cos(p1) * math.cos(p2) * math.cos(l2 - l1);
    final omega = math.acos(cosD.clamp(-1.0, 1.0));
    if (omega < 1e-4) return;

    final path = Path();
    var started = false;
    Offset? first;
    Offset? last;
    const steps = 48;
    for (var i = 0; i <= steps; i++) {
      final u = i / steps;
      final a = math.sin((1 - u) * omega) / math.sin(omega);
      final b = math.sin(u * omega) / math.sin(omega);
      final x =
          a * math.cos(p1) * math.cos(l1) + b * math.cos(p2) * math.cos(l2);
      final y =
          a * math.cos(p1) * math.sin(l1) + b * math.cos(p2) * math.sin(l2);
      final z = a * math.sin(p1) + b * math.sin(p2);
      final lat = math.atan2(z, math.sqrt(x * x + y * y)) * 180 / math.pi;
      final lon = math.atan2(y, x) * 180 / math.pi;
      final lift = 1 + math.sin(math.pi * u) * 0.16 * (omega / math.pi + 0.3);
      final o = starlitGlobeProject(
        size,
        lat,
        lon,
        lat0: lat0,
        lon0: lon0,
        radiusFactor: 0.42 * zoom * lift,
      );
      if (o == null) {
        started = false;
        continue;
      }
      if (!started) {
        path.moveTo(o.dx, o.dy);
        started = true;
      } else {
        path.lineTo(o.dx, o.dy);
      }
      first ??= o;
      last = o;
    }
    if (first == null || last == null) return;
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;
    final metric = metrics.first;
    final head = arcT.clamp(0.0, 1.0);
    final partial = metric.extractPath(0, metric.length * head);
    final from = first;
    final to = last;

    canvas.drawPath(
      partial,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round
        ..color = const Color(0x338EC5FF)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawPath(
      partial,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round
        ..shader = ui.Gradient.linear(from, to, const [
          Color(0xFFE891C4),
          Color(0xFF8EC5FF),
          Color(0xFFFFFFFF),
        ]),
    );

    for (final lag in <double>[0, 0.08, 0.15]) {
      final u = head - lag;
      if (u <= 0) continue;
      final tan = metric.getTangentForOffset(metric.length * u);
      if (tan == null) continue;
      final fade = (1 - lag / 0.2).clamp(0.25, 1.0);
      canvas.drawCircle(
        tan.position,
        2.6 * fade,
        Paint()
          ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.55 * fade)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }
  }

  void _paintGlobeGlow(Canvas canvas, Offset c, double r) {
    final accent = connected || connecting
        ? StarlitColors.accent
        : const Color(0xFF7AA2D8);
    final pulse = 0.75 + 0.25 * breath;

    canvas.drawCircle(
      c,
      r * 1.72,
      Paint()
        ..shader = RadialGradient(
          colors: [
            accent.withValues(alpha: 0.16 * pulse),
            accent.withValues(alpha: 0.05 * pulse),
            const Color(0x00000000),
          ],
          stops: const [0, 0.45, 1],
        ).createShader(Rect.fromCircle(center: c, radius: r * 1.72)),
    );
    canvas.drawCircle(
      c,
      r * 1.28,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Color.lerp(
              const Color(0x2A8EC5FF),
              accent.withValues(alpha: 0.28),
              connected || connecting ? 0.55 : 0.2,
            )!,
            const Color(0x00000000),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: r * 1.28)),
    );
    canvas.drawCircle(
      c,
      r * 1.06,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = accent.withValues(alpha: 0.12 + 0.08 * breath)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
  }

  @override
  bool shouldRepaint(covariant _GlobePainter oldDelegate) =>
      oldDelegate.zoom != zoom ||
      oldDelegate.lat0 != lat0 ||
      oldDelegate.lon0 != lon0 ||
      oldDelegate.connected != connected ||
      oldDelegate.connecting != connecting ||
      oldDelegate.hoverCountry != hoverCountry ||
      oldDelegate.activeCountry != activeCountry ||
      oldDelegate.availableCountries != availableCountries ||
      oldDelegate.arcT != arcT ||
      oldDelegate.breath != breath ||
      oldDelegate.targetLat != targetLat ||
      oldDelegate.targetLon != targetLon ||
      oldDelegate.geo != geo;
}
