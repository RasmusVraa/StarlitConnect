import 'dart:async';

import 'package:starlit_connect/starlit/cabinet_api.dart';
import 'package:starlit_connect/starlit/devices_api.dart';
import 'package:starlit_connect/starlit/plural.dart';
import 'package:starlit_connect/starlit/theme.dart';
import 'package:starlit_connect/starlit/ui_icons.dart';
import 'package:starlit_connect/starlit/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

String _platformIcon(StarlitCabinetDevice d) {
  final key = (d.platform.isNotEmpty ? d.platform : d.model).toLowerCase();
  if (key.contains('tv')) return 'tv';
  if (key.contains('ipad') || key.contains('tablet')) return 'tablet';
  if (key.contains('iphone') || key.contains('ios') || key.contains('android')) {
    return 'smartphone';
  }
  if (key.contains('mac') || key.contains('darwin')) return 'laptop';
  if (key.contains('windows') || key.contains('linux')) return 'monitor';
  return 'smartphone';
}

String _slotsLabel(int n) =>
    '$n ${starlitPlural(n, 'место', 'места', 'мест')}';

class StarlitDevicesCard extends StatefulWidget {
  const StarlitDevicesCard({
    super.key,
    required this.snapshot,
    required this.hasSub,
    required this.onDelete,
    required this.onRename,
    required this.onAdd,
    required this.onSlots,
  });

  final StarlitCabinetSnapshot? snapshot;
  final bool hasSub;
  final Future<void> Function(StarlitCabinetDevice device) onDelete;
  final Future<bool> Function(StarlitCabinetDevice device, String name)
  onRename;
  final VoidCallback onAdd;
  final ValueChanged<int> onSlots;

  @override
  State<StarlitDevicesCard> createState() => _StarlitDevicesCardState();
}

class _StarlitDevicesCardState extends State<StarlitDevicesCard> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  String? _editing;
  String? _deleting;
  var _saving = false;
  StarlitSlotPreview? _ctaPreview;
  int? _ctaTarget;

  @override
  void initState() {
    super.initState();
    _syncCta();
  }

  @override
  void didUpdateWidget(covariant StarlitDevicesCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncCta();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool get _allTaken {
    final snap = widget.snapshot;
    final limit = snap?.deviceLimit ?? 0;
    return snap != null && limit > 0 && snap.connected >= limit;
  }

  void _syncCta() {
    final slots = widget.snapshot?.slots;
    final target = slots != null && slots.canIncrease && _allTaken
        ? slots.current + 1
        : null;
    if (target == _ctaTarget) return;
    _ctaTarget = target;
    _ctaPreview = null;
    if (target == null) return;
    unawaited(
      StarlitDevicesApi.slotPreview(target).then((p) {
        if (mounted && _ctaTarget == target) setState(() => _ctaPreview = p);
      }),
    );
  }

  void _startEdit(StarlitCabinetDevice d) {
    _controller.text = d.customName.isNotEmpty ? d.customName : _baseName(d);
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _controller.text.length,
    );
    setState(() => _editing = d.hwid);
    _focus.requestFocus();
  }

  String _baseName(StarlitCabinetDevice d) =>
      d.model.isNotEmpty
      ? d.model
      : (d.platform.isNotEmpty ? d.platform : d.hwid);

  Future<void> _save(StarlitCabinetDevice d) async {
    if (_saving) return;
    final typed = _controller.text.trim();
    final name = typed == _baseName(d) ? '' : typed;
    if (name == d.customName) {
      setState(() => _editing = null);
      return;
    }
    setState(() => _saving = true);
    final ok = await widget.onRename(d, name);
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (ok) _editing = null;
    });
  }

  Future<void> _delete(StarlitCabinetDevice d) async {
    setState(() => _deleting = d.hwid);
    try {
      await widget.onDelete(d);
    } finally {
      if (mounted) setState(() => _deleting = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final snap = widget.snapshot;
    final devices = snap?.devices ?? const <StarlitCabinetDevice>[];
    final limit = snap?.deviceLimit;
    final limitLabel = limit == null || limit <= 0 ? 'Безлимит' : '$limit';
    final slots = snap?.slots;
    final hasLink = (snap?.subscriptionLink ?? '').isNotEmpty;
    return StarlitCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
            child: Row(
              children: [
                StarlitUi.icon('monitor', size: 18, color: StarlitColors.accent),
                const SizedBox(width: 9),
                Text(
                  'Мои устройства',
                  style: starlitText(
                    size: 16,
                    weight: FontWeight.w800,
                    display: true,
                  ),
                ),
                const Spacer(),
                if (widget.hasSub && (snap?.devicesEnabled ?? true))
                  Text(
                    '${snap?.connected ?? devices.length} / $limitLabel',
                    style: starlitText(size: 13, color: StarlitColors.muted),
                  ),
              ],
            ),
          ),
          if (!widget.hasSub)
            _Line(
              child: Text(
                'После входа здесь появятся ваши устройства.',
                style: starlitText(size: 13, color: StarlitColors.muted),
              ),
            )
          else if (snap != null && !snap.devicesEnabled)
            _Line(
              child: Text(
                'Управление устройствами сейчас недоступно. '
                'Обновите кабинет или обратитесь в поддержку.',
                style: starlitText(size: 13, color: StarlitColors.muted),
              ),
            )
          else if (snap == null)
            const _Skeleton()
          else if (devices.isEmpty)
            const _Empty()
          else
            for (final d in devices) _row(d),
          if (widget.hasSub &&
              snap != null &&
              snap.devicesEnabled &&
              hasLink &&
              !_allTaken)
            _AddRow(onTap: widget.onAdd),
          if (widget.hasSub && snap != null && snap.devicesEnabled)
            _footer(snap, slots),
        ],
      ),
    );
  }

  Widget _row(StarlitCabinetDevice d) {
    final editing = _editing == d.hwid;
    final deleting = _deleting == d.hwid;
    final title = d.customName.isNotEmpty ? d.customName : _baseName(d);
    return _Line(
      vertical: 10,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: StarlitColors.accent.withValues(alpha: 0.12),
            ),
            child: StarlitUi.icon(
              _platformIcon(d),
              size: 20,
              color: StarlitColors.accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: editing
                ? _RenameField(
                    controller: _controller,
                    focus: _focus,
                    onSubmit: () => unawaited(_save(d)),
                    onCancel: () => setState(() => _editing = null),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        d.isLocal ? d.title : title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: starlitText(size: 15, weight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        d.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: starlitText(
                          size: 13,
                          color: StarlitColors.muted,
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(width: 8),
          if (editing) ...[
            _IconAction(
              icon: 'check',
              hover: StarlitColors.success,
              busy: _saving,
              onTap: () => unawaited(_save(d)),
            ),
            _IconAction(
              icon: 'x',
              hover: StarlitColors.text,
              onTap: () => setState(() => _editing = null),
            ),
          ] else ...[
            if (!d.isLocal)
              _IconAction(
                icon: 'pencil',
                hover: StarlitColors.accent,
                onTap: () => _startEdit(d),
              ),
            _IconAction(
              icon: 'trash-2',
              hover: StarlitColors.danger,
              busy: deleting,
              onTap: () => unawaited(_delete(d)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _footer(StarlitCabinetSnapshot snap, StarlitSlots? slots) {
    final canIncrease = slots?.canIncrease ?? false;
    if (_allTaken && canIncrease && slots != null) {
      return _FullCta(
        preview: _ctaPreview,
        expireAt: snap.expireAt,
        onTap: () => widget.onSlots(slots.current + 1),
      );
    }
    final pinned = slots?.pinned ?? false;
    final adjustable =
        slots != null &&
        !pinned &&
        !snap.isTrial &&
        (slots.canIncrease || slots.canDecrease);
    if (adjustable) {
      return _Line(
        vertical: 10,
        child: Row(
          children: [
            Text(
              'Места для устройств',
              style: starlitText(size: 13, color: StarlitColors.muted),
            ),
            const Spacer(),
            _Stepper(slots: slots, onTap: widget.onSlots),
          ],
        ),
      );
    }
    if (pinned) {
      return _Line(
        vertical: 10,
        child: Text(
          'Число устройств задаёт администратор',
          style: starlitText(size: 13, color: StarlitColors.muted),
        ),
      );
    }
    if (_allTaken) {
      return _Line(
        vertical: 10,
        child: Text(
          'Все места заняты — освободите одно',
          style: starlitText(size: 13, color: StarlitColors.muted),
        ),
      );
    }
    return const SizedBox(height: 4);
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.child, this.vertical = 12});

  final Widget child;
  final double vertical;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 2, vertical: vertical),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: StarlitColors.stroke.withValues(alpha: 0.7)),
        ),
      ),
      child: child,
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    Widget bar(double w, double h) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: StarlitColors.stroke.withValues(alpha: 0.6),
      ),
    );
    return Column(
      children: [
        for (var i = 0; i < 2; i++)
          _Line(
            vertical: 10,
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: StarlitColors.stroke.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [bar(120, 14), const SizedBox(height: 7), bar(80, 11)],
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return _Line(
      vertical: 18,
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: StarlitColors.accent.withValues(alpha: 0.12),
            ),
            child: StarlitUi.icon(
              'smartphone',
              size: 22,
              color: StarlitColors.accent,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Пока нет устройств',
            style: starlitText(size: 16, weight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Нажмите «Добавить устройство» — это займёт пару минут',
            textAlign: TextAlign.center,
            style: starlitText(size: 13, color: StarlitColors.muted),
          ),
        ],
      ),
    );
  }
}

class _AddRow extends StatelessWidget {
  const _AddRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: _Line(
          vertical: 10,
          child: Row(
            children: [
              CustomPaint(
                painter: _DashedBoxPainter(
                  StarlitColors.accent.withValues(alpha: 0.55),
                ),
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Center(
                    child: StarlitUi.icon(
                      'plus',
                      size: 18,
                      color: StarlitColors.accent,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Добавить устройство',
                style: starlitText(
                  size: 15,
                  weight: FontWeight.w700,
                  color: StarlitColors.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedBoxPainter extends CustomPainter {
  _DashedBoxPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)),
      );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = color;
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + 4), paint);
        d += 7;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBoxPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _IconAction extends StatefulWidget {
  const _IconAction({
    required this.icon,
    required this.hover,
    required this.onTap,
    this.busy = false,
  });

  final String icon;
  final Color hover;
  final VoidCallback onTap;
  final bool busy;

  @override
  State<_IconAction> createState() => _IconActionState();
}

class _IconActionState extends State<_IconAction> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = _hovered || widget.busy;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.busy ? null : widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: active
                ? widget.hover.withValues(alpha: 0.14)
                : const Color(0x00000000),
          ),
          child: widget.busy
              ? Text('…', style: starlitText(size: 15, color: widget.hover))
              : StarlitUi.icon(
                  widget.icon,
                  size: 17,
                  color: active ? widget.hover : StarlitColors.muted,
                ),
        ),
      ),
    );
  }
}

class _RenameField extends StatefulWidget {
  const _RenameField({
    required this.controller,
    required this.focus,
    required this.onSubmit,
    required this.onCancel,
  });

  final TextEditingController controller;
  final FocusNode focus;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;

  @override
  State<_RenameField> createState() => _RenameFieldState();
}

class _RenameFieldState extends State<_RenameField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_rebuild);
    widget.focus.addListener(_rebuild);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_rebuild);
    widget.focus.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final focused = widget.focus.hasFocus;
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: StarlitColors.field,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: focused ? StarlitColors.accent : StarlitColors.stroke,
        ),
      ),
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          if (widget.controller.text.isEmpty)
            Text(
              'Название устройства',
              style: starlitText(size: 14, color: StarlitColors.muted2, height: 1.2),
            ),
          Focus(
            onKeyEvent: (_, event) {
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.escape) {
                widget.onCancel();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: EditableText(
              controller: widget.controller,
              focusNode: widget.focus,
              style: starlitText(size: 14, height: 1.2),
              cursorColor: StarlitColors.accent,
              backgroundCursorColor: StarlitColors.muted2,
              inputFormatters: [LengthLimitingTextInputFormatter(64)],
              onSubmitted: (_) => widget.onSubmit(),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.slots, required this.onTap});

  final StarlitSlots slots;
  final ValueChanged<int> onTap;

  Widget _button(String icon, bool enabled, VoidCallback onTap) {
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Opacity(
          opacity: enabled ? 1 : 0.35,
          child: Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              color: StarlitColors.cardHi,
            ),
            child: StarlitUi.icon(icon, size: 15, color: StarlitColors.text),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: StarlitColors.field,
        border: Border.all(color: StarlitColors.stroke),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _button(
            'minus',
            slots.canDecrease,
            () => onTap(slots.current - 1),
          ),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => onTap(slots.current),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  _slotsLabel(slots.current),
                  style: starlitText(size: 14, weight: FontWeight.w700),
                ),
              ),
            ),
          ),
          _button('plus', slots.canIncrease, () => onTap(slots.current + 1)),
        ],
      ),
    );
  }
}

class _FullCta extends StatelessWidget {
  const _FullCta({
    required this.preview,
    required this.expireAt,
    required this.onTap,
  });

  final StarlitSlotPreview? preview;
  final DateTime? expireAt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = preview;
    final date = expireAt == null ? '' : starlitDayMonth(expireAt!);
    final subtitle = p == null
        ? 'Докупить ещё одно место'
        : 'Ещё одно место — ${_money(p.amount)} ${p.unit}'
              '${date.isEmpty ? '' : ' до $date'}';
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(top: 6),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: StarlitColors.accent.withValues(alpha: 0.45),
            ),
            gradient: LinearGradient(
              colors: [
                StarlitColors.accent.withValues(alpha: 0.16),
                StarlitColors.accent.withValues(alpha: 0.04),
              ],
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: StarlitColors.accent,
                ),
                child: StarlitUi.icon(
                  'plus',
                  size: 16,
                  color: const Color(0xFF1A1020),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Все места заняты',
                      style: starlitText(size: 14, weight: FontWeight.w700),
                    ),
                    Text(
                      subtitle,
                      style: starlitText(size: 12, color: StarlitColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _money(num value) {
  final text = value.toStringAsFixed(value == value.roundToDouble() ? 0 : 2);
  return text;
}
