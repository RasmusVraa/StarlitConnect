import 'dart:async';
import 'dart:math' as math;

import 'package:starlit_connect/starlit/cabinet_api.dart';
import 'package:starlit_connect/starlit/devices_api.dart';
import 'package:starlit_connect/starlit/plural.dart';
import 'package:starlit_connect/starlit/popup.dart';
import 'package:starlit_connect/starlit/session.dart';
import 'package:starlit_connect/starlit/theme.dart';
import 'package:starlit_connect/starlit/ui_icons.dart';
import 'package:starlit_connect/starlit/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:url_launcher/url_launcher.dart';

Future<bool> showStarlitSlots(
  BuildContext context, {
  required StarlitSlots slots,
  required int connected,
  required DateTime? expireAt,
  required int initialTarget,
}) async {
  final changed = await showStarlitPopup<bool>(
    context,
    builder: (_) => _SlotsDialog(
      slots: slots,
      connected: connected,
      expireAt: expireAt,
      initialTarget: initialTarget,
    ),
  );
  return changed ?? false;
}

String _count(int n) => '$n ${starlitPlural(n, 'место', 'места', 'мест')}';

String _money(num v) => v.toStringAsFixed(v == v.roundToDouble() ? 0 : 2);

class _SlotsDialog extends StatefulWidget {
  const _SlotsDialog({
    required this.slots,
    required this.connected,
    required this.expireAt,
    required this.initialTarget,
  });

  final StarlitSlots slots;
  final int connected;
  final DateTime? expireAt;
  final int initialTarget;

  @override
  State<_SlotsDialog> createState() => _SlotsDialogState();
}

class _SlotsDialogState extends State<_SlotsDialog> {
  late int _target;
  StarlitSlotPreview? _preview;
  var _previewTarget = -1;
  var _busy = false;
  String? _error;

  StarlitSlots get _s => widget.slots;
  int get _min => _s.canDecrease ? _s.base : _s.current;
  int get _max => _s.canIncrease ? _s.max : _s.current;
  int get _delta => _target - _s.current;

  @override
  void initState() {
    super.initState();
    _target = widget.initialTarget.clamp(_min, math.max(_min, _max)).toInt();
    _loadPreview();
  }

  void _loadPreview() {
    final target = _target;
    if (_delta <= 0) {
      _preview = null;
      _previewTarget = -1;
      return;
    }
    _previewTarget = target;
    _preview = null;
    unawaited(
      StarlitDevicesApi.slotPreview(target).then((p) {
        if (mounted && _previewTarget == target) setState(() => _preview = p);
      }),
    );
  }

  void _step(int by) {
    final next = (_target + by).clamp(_min, math.max(_min, _max)).toInt();
    if (next == _target) return;
    setState(() {
      _target = next;
      _error = null;
      _loadPreview();
    });
  }

  Future<void> _pay() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final url = await StarlitDevicesApi.slotCheckoutUrl(_target);
    if (!mounted) return;
    if (url == null) {
      setState(() {
        _busy = false;
        _error = 'Оплата сейчас недоступна. Попробуйте позже.';
      });
      return;
    }
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (mounted) Navigator.of(context).pop(false);
  }

  Future<void> _decrease() async {
    final removed = -_delta;
    final ok = await StarlitSession.confirm(
      context,
      title:
          'Убрать $removed ${starlitPlural(removed, 'место', 'места', 'мест')}?',
      message:
          'Останется ${_count(_target)} для устройств. Деньги за убранное '
          'не вернутся, а вернуть места можно только новой покупкой.',
      confirmText: 'Да, убрать',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    final done = await StarlitDevicesApi.applySlots(_target);
    if (!mounted) return;
    if (done) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _busy = false;
        _error = 'Не удалось изменить число мест';
      });
    }
  }

  String? _discountLine(StarlitSlotPreview p) {
    if (!p.discounted) return null;
    final parts = <String>[
      if (p.loyaltyPct > 0) 'лояльность ${p.loyaltyPct}%',
      if (p.promoPct > 0) 'промокод ${p.promoPct}%',
    ];
    if (parts.isNotEmpty) return 'скидка: ${parts.join(' и ')}';
    return p.totalPct > 0 ? 'скидка ${p.totalPct}%' : null;
  }

  @override
  Widget build(BuildContext context) {
    final delta = _delta;
    return StarlitPopupFrame(
      title: 'Места для устройств',
      width: 440,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Одно место — одно подключённое устройство.',
              style: starlitText(size: 13, color: StarlitColors.muted),
            ),
            const SizedBox(height: 16),
            _SlotChips(
              connected: widget.connected,
              current: _s.current,
              target: _target,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _RoundStep(
                  icon: 'minus',
                  enabled: _target > _min && !_busy,
                  onTap: () => _step(-1),
                ),
                SizedBox(
                  width: 128,
                  child: Column(
                    children: [
                      Text(
                        '$_target',
                        style: starlitText(
                          size: 38,
                          weight: FontWeight.w800,
                          display: true,
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        delta == 0
                            ? 'сейчас ${_s.current}'
                            : 'было ${_s.current} → станет $_target',
                        style: starlitText(
                          size: 12,
                          color: StarlitColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                _RoundStep(
                  icon: 'plus',
                  enabled: _target < _max && !_busy,
                  onTap: () => _step(1),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'от ${_s.base} по тарифу до ${math.max(_max, _s.current)}',
              textAlign: TextAlign.center,
              style: starlitText(size: 12, color: StarlitColors.muted2),
            ),
            const SizedBox(height: 16),
            if (delta > 0) ..._buy(delta) else if (delta < 0) ..._remove(-delta)
            else
              const _FooterButton(label: 'Нажмите + или −'),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: starlitText(size: 12, color: StarlitColors.danger),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buy(int delta) {
    final p = _preview;
    final days = p?.daysLeft ?? _s.daysLeft;
    final date = widget.expireAt == null
        ? ''
        : ' до ${starlitDayMonth(widget.expireAt!)}';
    final discount = p == null ? null : _discountLine(p);
    final meta = [
      if (days != null)
        '$days ${starlitPlural(days, 'день', 'дня', 'дней')}',
      ?discount,
    ].join(' · ');
    return [
      Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: StarlitColors.field,
          border: Border.all(color: StarlitColors.stroke),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '+${_count(delta)}$date',
                    style: starlitText(size: 14, weight: FontWeight.w700),
                  ),
                  if (meta.isNotEmpty)
                    Text(
                      meta,
                      style: starlitText(size: 12, color: StarlitColors.muted),
                    ),
                ],
              ),
            ),
            if (p == null)
              Container(
                width: 64,
                height: 26,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(7),
                  color: StarlitColors.stroke,
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (p.discounted)
                    Text(
                      '${_money(p.baseAmount)} ${p.unit}',
                      style: starlitText(
                        size: 12,
                        color: StarlitColors.muted2,
                      ).copyWith(decoration: TextDecoration.lineThrough),
                    ),
                  Text(
                    '${_money(p.amount)} ${p.unit}',
                    style: starlitText(
                      size: 22,
                      weight: FontWeight.w800,
                      display: true,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(2, 10, 2, 14),
        child: Text(
          'Место действует, пока активна подписка, и продлевается вместе с ней.',
          style: starlitText(size: 12, color: StarlitColors.muted),
        ),
      ),
      StarlitPrimaryButton(
        label: p == null
            ? 'Перейти к оплате'
            : 'Перейти к оплате · ${_money(p.amount)} ${p.unit}',
        onPressed: p == null || _busy ? null : () => unawaited(_pay()),
      ),
    ];
  }

  List<Widget> _remove(int removed) {
    return [
      Container(
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: StarlitColors.warn.withValues(alpha: 0.1),
          border: Border.all(color: StarlitColors.warn.withValues(alpha: 0.4)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: StarlitUi.icon(
                'triangle-alert',
                size: 17,
                color: StarlitColors.warn,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Уберём ${_count(removed)}. Деньги за '
                '${removed == 1 ? 'него' : 'них'} не вернутся.',
                style: starlitText(size: 13, color: StarlitColors.warn),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      GestureDetector(
        onTap: _busy ? null : () => unawaited(_decrease()),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: _FooterButton(
            label: 'Убрать ${_count(removed)}',
            color: StarlitColors.danger,
            filled: true,
          ),
        ),
      ),
    ];
  }
}

class _FooterButton extends StatelessWidget {
  const _FooterButton({
    required this.label,
    this.color,
    this.filled = false,
  });

  final String label;
  final Color? color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? StarlitColors.muted2;
    return Container(
      height: 50,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(StarlitRadii.pill),
        color: filled ? tint : StarlitColors.field,
        border: Border.all(color: filled ? tint : StarlitColors.stroke),
      ),
      child: Text(
        label,
        style: starlitText(
          size: 15,
          weight: FontWeight.w700,
          color: filled ? const Color(0xFFFFFFFF) : StarlitColors.muted2,
        ),
      ),
    );
  }
}

class _RoundStep extends StatelessWidget {
  const _RoundStep({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final String icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Opacity(
          opacity: enabled ? 1 : 0.35,
          child: Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: StarlitColors.field,
              border: Border.all(color: StarlitColors.stroke),
            ),
            child: StarlitUi.icon(icon, size: 18, color: StarlitColors.text),
          ),
        ),
      ),
    );
  }
}

class _SlotChips extends StatelessWidget {
  const _SlotChips({
    required this.connected,
    required this.current,
    required this.target,
  });

  final int connected;
  final int current;
  final int target;

  @override
  Widget build(BuildContext context) {
    final total = math.max(current, target);
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 6,
      runSpacing: 6,
      children: [
        for (var u = 0; u < total; u++) _chip(u),
      ],
    );
  }

  Widget _chip(int u) {
    final removing = u >= target && u < current;
    final adding = u >= current && u < target;
    final occupied = !removing && !adding && u < connected;
    final accent = StarlitColors.accent;
    final Color border;
    final Color fill;
    if (occupied) {
      border = const Color(0x00000000);
      fill = accent.withValues(alpha: 0.16);
    } else if (adding) {
      border = accent;
      fill = accent.withValues(alpha: 0.08);
    } else if (removing) {
      border = StarlitColors.danger.withValues(alpha: 0.6);
      fill = const Color(0x00000000);
    } else {
      border = StarlitColors.stroke;
      fill = const Color(0x00000000);
    }
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: fill,
        border: Border.all(color: border),
      ),
      child: occupied
          ? StarlitUi.icon('monitor', size: 15, color: accent)
          : adding
          ? StarlitUi.icon('plus', size: 15, color: accent)
          : removing
          ? Transform.rotate(
              angle: -0.6,
              child: Container(
                width: 26,
                height: 2,
                color: StarlitColors.danger.withValues(alpha: 0.8),
              ),
            )
          : null,
    );
  }
}
