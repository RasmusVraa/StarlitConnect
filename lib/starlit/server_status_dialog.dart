import 'dart:async';

import 'package:starlit_connect/starlit/popup.dart';
import 'package:starlit_connect/starlit/servers.dart';
import 'package:starlit_connect/starlit/status_api.dart';
import 'package:starlit_connect/starlit/theme.dart';
import 'package:starlit_connect/starlit/ui_icons.dart';
import 'package:flutter/widgets.dart';

Future<void> showStarlitServerStatus(BuildContext context) =>
    showStarlitPopup<void>(context, builder: (_) => const _StatusDialog());

const _up = Color(0xFF34D399);
const _partial = Color(0xFFFBBF24);
const _down = Color(0xFFFB7185);

String _stateOf(double? v) => v == null
    ? ''
    : v >= 0.99
    ? 'up'
    : v > 0
    ? 'partial'
    : 'down';

Color _stateColor(String state) => switch (state) {
  'up' => _up,
  'partial' => _partial,
  'down' => _down,
  _ => StarlitColors.muted2,
};

String _stateLabel(String state) => switch (state) {
  'up' => 'Работает',
  'partial' => 'Частично',
  _ => 'Недоступен',
};

String _ping(int ms) => '$ms мс';

String _protocol(bool? ok, int? ms) {
  if (ok == null && ms == null) return '—';
  if (ok == false) return 'Нет';
  return ms != null ? _ping(ms) : 'Доступен';
}

List<StarlitProbeHit> _russiaHits(StarlitProbe? probe) => [
  for (final h in probe?.hits ?? const <StarlitProbeHit>[])
    if (h.country == 'RU' && !h.isWhitelist) h,
];

List<StarlitProbeHit> _whitelistHits(StarlitProbe? probe) =>
    [
      for (final h in probe?.hits ?? const <StarlitProbeHit>[])
        if (h.isWhitelist && h.city.isEmpty) h,
    ]..sort((a, b) => a.network.compareTo(b.network));

int _minutesSince(DateTime? at) {
  if (at == null) return 0;
  return DateTime.now().difference(at).inMinutes.clamp(0, 1 << 30);
}

class _StatusDialog extends StatefulWidget {
  const _StatusDialog();

  @override
  State<_StatusDialog> createState() => _StatusDialogState();
}

class _StatusDialogState extends State<_StatusDialog> {
  StarlitPublicStatus? _status;
  var _failed = false;
  String? _open;
  Timer? _refresh;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    _refresh = Timer.periodic(const Duration(seconds: 30), (_) => _load());
  }

  @override
  void dispose() {
    _refresh?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final status = await StarlitStatusApi.fetchStatus();
      if (mounted) {
        setState(() {
          _status = status;
          _failed = false;
        });
      }
    } catch (_) {
      if (mounted && _status == null) setState(() => _failed = true);
    }
  }

  DateTime? _latestProbe(List<StarlitPublicNode> nodes) {
    DateTime? best;
    for (final n in nodes) {
      final at = n.probe?.measuredAt;
      if (at != null && (best == null || at.isAfter(best))) best = at;
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    return StarlitPopupFrame(
      title: 'Серверы',
      width: 780,
      maxHeight: 760,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Проверяем доступность серверов из мира и из России. '
              'Если что-то не подключается, сначала загляните сюда.',
              style: starlitText(size: 13, color: StarlitColors.muted),
            ),
            const SizedBox(height: 12),
            if (status == null)
              _Placeholder(
                text: _failed
                    ? 'Не удалось загрузить статус серверов'
                    : 'Загружаем статус…',
              )
            else
              ..._body(status),
          ],
        ),
      ),
    );
  }

  List<Widget> _body(StarlitPublicStatus status) {
    final nodes = status.nodes;
    final down = nodes.where((n) => n.state == 'down').length;
    final idle = !status.available || nodes.isEmpty;
    final overall = idle
        ? 'idle'
        : down == 0
        ? 'up'
        : 'partial';
    final minutes = _minutesSince(_latestProbe(nodes) ?? status.updatedAt);
    return [
      Row(
        children: [
          _Pill(
            color: switch (overall) {
              'up' => _up,
              'partial' => _partial,
              _ => StarlitColors.muted2,
            },
            label: switch (overall) {
              'up' => 'Все локации на связи',
              'partial' => 'Часть локаций недоступна',
              _ => 'Локации ещё не добавлены',
            },
          ),
          const Spacer(),
          if (status.available)
            Text(
              minutes < 1
                  ? 'Обновлено только что'
                  : 'Обновлено $minutes мин назад',
              style: starlitText(size: 12, color: StarlitColors.muted2),
            ),
        ],
      ),
      const SizedBox(height: 14),
      if (nodes.isEmpty)
        const _Placeholder(
          text: 'Локаций пока нет. Загляните позже.',
        )
      else
        LayoutBuilder(
          builder: (context, box) {
            final columns = box.maxWidth >= 560 ? 2 : 1;
            const gap = 12.0;
            final width = (box.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (var i = 0; i < nodes.length; i++)
                  SizedBox(
                    width: width,
                    child: _NodeCard(
                      node: nodes[i],
                      bypassProbes: status.bypassProbes,
                      open: _open == _keyOf(nodes[i], i),
                      onToggle: () => setState(() {
                        final key = _keyOf(nodes[i], i);
                        _open = _open == key ? null : key;
                      }),
                    ),
                  ),
              ],
            );
          },
        ),
    ];
  }

  String _keyOf(StarlitPublicNode n, int i) =>
      n.id.isNotEmpty ? n.id : '${n.country}-${n.name}-$i';
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 16),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: StarlitColors.field,
        border: Border.all(color: StarlitColors.stroke),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: starlitText(size: 13, color: StarlitColors.muted),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.15),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: starlitText(size: 12, weight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}

class _NodeCard extends StatelessWidget {
  const _NodeCard({
    required this.node,
    required this.bypassProbes,
    required this.open,
    required this.onToggle,
  });

  final StarlitPublicNode node;
  final bool bypassProbes;
  final bool open;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final probe = node.probe;
    final note = node.note?.trim() ?? '';
    final history = probe?.history ?? const <double?>[];
    final numeric = history.whereType<double>().toList();
    final avg = numeric.isEmpty
        ? null
        : (numeric.reduce((a, b) => a + b) / numeric.length * 1000).round() /
              10;
    final hits = node.whitelist ? _whitelistHits(probe) : _russiaHits(probe);
    final tint = _stateColor(node.state);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: StarlitColors.card,
        border: Border.all(
          color: node.state == 'down'
              ? _down.withValues(alpha: 0.45)
              : StarlitColors.stroke,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Text(
                          StarlitServers.flagEmoji(node.country),
                          style: const TextStyle(
                            fontFamily: 'Twemoji',
                            fontSize: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      node.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: starlitText(
                                        size: 16,
                                        weight: FontWeight.w800,
                                        display: true,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _Pill(
                                    color: tint,
                                    label: _stateLabel(node.state),
                                  ),
                                ],
                              ),
                              if (note.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 3),
                                  child: Text(
                                    note,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: starlitText(
                                      size: 13,
                                      color: StarlitColors.muted,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        AnimatedRotation(
                          turns: open ? 0.5 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: StarlitUi.icon(
                            'chevron-down',
                            size: 16,
                            color: StarlitColors.muted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _InfoBox(
                            label: 'Из мира',
                            child: _worldInfo(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _InfoBox(
                            label: node.whitelist ? 'Белые списки' : 'Из России',
                            child: _russiaInfo(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Последние 30 дней',
                          style: starlitText(
                            size: 11,
                            color: StarlitColors.muted2,
                          ),
                        ),
                        Text(
                          avg == null
                              ? 'Замеров ещё нет'
                              : '${_percent(avg)}% за ${numeric.length} дн.',
                          style: starlitText(
                            size: 11,
                            color: StarlitColors.muted2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 20,
                      child: Row(
                        children: [
                          for (var i = 0; i < 30; i++) ...[
                            if (i > 0) const SizedBox(width: 1.5),
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(2),
                                  color: i < history.length &&
                                          _stateOf(history[i]).isNotEmpty
                                      ? _stateColor(_stateOf(history[i]))
                                      : StarlitColors.muted2.withValues(
                                          alpha: 0.25,
                                        ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (open)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: StarlitColors.stroke.withValues(alpha: 0.8),
                  ),
                ),
              ),
              child: hits.isEmpty
                  ? Text(
                      'Список зондов появится после ближайшей проверки.',
                      style: starlitText(size: 13, color: StarlitColors.muted),
                    )
                  : Column(
                      children: [
                        for (final h in hits) _hitRow(h),
                      ],
                    ),
            ),
        ],
      ),
    );
  }

  String _percent(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);

  Widget _hitRow(StarlitProbeHit h) {
    final wl = node.whitelist;
    final title = wl ? (h.network.isEmpty ? '—' : h.network) : (h.city.isEmpty ? '—' : h.city);
    final sub = wl
        ? 'ICMP ${_protocol(h.icmpOk, h.icmpMs)} · TCP ${_protocol(h.tcpOk, h.tcpMs)}'
        : (h.network.isEmpty ? '—' : h.network);
    final result = h.ok
        ? (h.pingMs != null ? _ping(h.pingMs!) : (wl ? 'Доступен' : 'Пинг'))
        : 'Недоступен';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: starlitText(size: 13, weight: FontWeight.w600),
                ),
                Text(
                  sub,
                  style: starlitText(size: 12, color: StarlitColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: h.ok ? _up : _down,
                  ),
                ),
                const SizedBox(width: 6),
                Text(result, style: starlitText(size: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _status(bool ok, String label, {String? sub}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ok ? _up : _down,
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: starlitText(size: 14, weight: FontWeight.w600),
              ),
            ),
          ],
        ),
        if (sub != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              sub,
              style: starlitText(size: 12, color: StarlitColors.muted),
            ),
          ),
      ],
    );
  }

  Widget _muted(String text) => Text(
    text,
    style: starlitText(size: 14, weight: FontWeight.w600, color: StarlitColors.muted),
  );

  Widget _worldInfo() {
    final probe = node.probe;
    if (node.noProbe) return _muted('—');
    if (probe == null || probe.worldTotal == 0) return _muted('Ещё считаем');
    return _status(
      probe.worldOk > 0,
      probe.worldOk > 0 ? 'Работает' : 'Недоступен',
    );
  }

  Widget _russiaInfo() {
    final probe = node.probe;
    final skipped = node.noProbe || (node.whitelist && !bypassProbes);
    if (skipped) return _muted('—');
    final wl = _whitelistHits(probe);
    final total = node.whitelist ? wl.length : (probe?.russiaTotal ?? 0);
    final ok = node.whitelist
        ? wl.where((h) => h.ok).length
        : (probe?.russiaOk ?? 0);
    if (probe == null || total == 0) return _muted('Ещё считаем');
    final pings = [
      for (final h in wl)
        if (h.pingMs != null) h.pingMs!,
    ];
    final avgPing = pings.isEmpty
        ? null
        : (pings.reduce((a, b) => a + b) / pings.length).round();
    final sub = node.whitelist
        ? '$ok из $total операторов'
              '${avgPing != null ? ' · ${_ping(avgPing)}' : ''}'
        : '$ok из $total провайдеров';
    return _status(ok > 0, ok > 0 ? 'Доступен' : 'Недоступен', sub: sub);
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: StarlitColors.field,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: starlitText(
              size: 10.5,
              weight: FontWeight.w700,
              color: StarlitColors.muted2,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 5),
          child,
        ],
      ),
    );
  }
}
