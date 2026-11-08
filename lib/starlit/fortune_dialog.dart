import 'dart:async';
import 'dart:math' as math;

import 'package:starlit_connect/starlit/cabinet_api.dart';
import 'package:starlit_connect/starlit/fortune_api.dart';
import 'package:starlit_connect/starlit/plural.dart';
import 'package:starlit_connect/starlit/popup.dart';
import 'package:starlit_connect/starlit/prefs.dart';
import 'package:starlit_connect/starlit/sound.dart';
import 'package:starlit_connect/starlit/theme.dart';
import 'package:starlit_connect/starlit/ui_icons.dart';
import 'package:starlit_connect/starlit/widgets.dart';
import 'package:flutter/widgets.dart';

Future<void> showStarlitFortune(BuildContext context) =>
    showStarlitPopup<void>(context, builder: (_) => const _FortuneDialog());

const _spinDuration = Duration(milliseconds: 4200);
const _spinCurve = Cubic(0.22, 0.61, 0.36, 1);
const _burstDuration = Duration(milliseconds: 1400);

const _wheelHsl = <String, List<double>>{
  'micro': [285, 88, 62],
  'xp': [46, 100, 54],
  'discount_3': [204, 95, 58],
  'days_3': [168, 78, 48],
  'discount_5': [248, 82, 65],
  'days_5': [152, 76, 46],
  'days_7': [130, 70, 46],
  'days_15': [24, 95, 58],
  'days_30': [350, 85, 58],
  'days_180': [318, 80, 58],
};

const _rimHsl = <String, List<double>>{
  'micro': [285, 72, 48],
  'xp': [42, 96, 48],
  'discount_3': [204, 88, 48],
  'days_3': [168, 72, 40],
  'discount_5': [258, 78, 58],
  'days_5': [152, 68, 40],
  'days_7': [130, 62, 40],
  'days_15': [24, 90, 50],
  'days_30': [350, 78, 52],
  'days_180': [318, 72, 55],
};

const _glyphColors = <String, Color>{
  'micro': Color(0xFFE879F9),
  'xp': Color(0xFFFCD34D),
  'discount_3': Color(0xFF7DD3FC),
  'days_3': Color(0xFF5EEAD4),
  'discount_5': Color(0xFFC4B5FD),
  'days_5': Color(0xFF6EE7B7),
  'days_7': Color(0xFFBEF264),
  'days_15': Color(0xFFFDBA74),
  'days_30': Color(0xFFFDA4AF),
  'days_180': Color(0xFFF9A8D4),
};

const _barColors = <String, Color>{
  'micro': Color(0xFFD946EF),
  'xp': Color(0xFFFBBF24),
  'discount_3': Color(0xFF0EA5E9),
  'days_3': Color(0xFF14B8A6),
  'discount_5': Color(0xFF8B5CF6),
  'days_5': Color(0xFF10B981),
  'days_7': Color(0xFF84CC16),
  'days_15': Color(0xFFF97316),
  'days_30': Color(0xFFF43F5E),
  'days_180': Color(0xFFEC4899),
};

const _reasons = <String, String>{
  'module_disabled': 'Модуль колеса выключен.',
  'no_panel': 'Панель не подключена.',
  'no_customer': 'Нет привязанного клиента VPN.',
  'no_paid': 'Нужна хотя бы одна оплаченная подписка',
  'insufficient_days':
      'Недостаточно оставшихся дней подписки для спина. Продлите подписку.',
  'daily_limit': 'Достигнут дневной лимит',
  'not_configured': 'Колесо не настроено на сервере.',
  'csrf': 'Не удалось подтвердить сессию. Обновите кабинет или войдите снова.',
  'unknown': 'Спин сейчас недоступен.',
  'http_403': 'Сессия устарела. Выйдите и войдите в кабинет снова.',
  'http_419': 'Сессия устарела. Выйдите и войдите в кабинет снова.',
};

Color _hsl(List<double> v, [double alpha = 1]) =>
    HSLColor.fromAHSL(alpha, v[0] % 360, v[1] / 100, v[2] / 100).toColor();

Color _wheelColor(StarlitSector s) => _hsl(
  _wheelHsl[s.type] ?? [(s.index * 47 + 180) % 360, 78, 56],
  0.94,
);

Color _rimColor(StarlitSector s) =>
    _hsl(_rimHsl[s.type] ?? [(s.index * 47 + 180) % 360, 65, 50]);

String _iconFor(String type) {
  if (type == 'micro') return 'sparkles';
  if (type == 'xp') return 'zap';
  if (type.startsWith('discount')) return 'badge-percent';
  if (type == 'days_15' || type == 'days_30' || type == 'days_180') {
    return 'gift';
  }
  return 'calendar-plus';
}

String _wheelShort(StarlitSector s) {
  if (s.type == 'micro' || s.type == 'xp') return 'Лояльность XP';
  if (s.type.startsWith('discount')) return '−${s.discountPercent}%';
  if (s.type.startsWith('days_')) return '+${s.days} д';
  return s.type;
}

String _prizeLabel(StarlitSector s) {
  if (s.type == 'micro' || s.type == 'xp') return 'Лояльность XP';
  if (s.type.startsWith('discount')) return 'Скидка ${s.discountPercent}%';
  if (s.type.startsWith('days_')) return '+${s.days} дней';
  return s.type;
}

String? _prizeHint(StarlitSector s) {
  if (s.type.startsWith('days_')) return 'К подписке';
  if (s.type.startsWith('discount')) return 'На следующую оплату';
  if (s.type == 'micro' || s.type == 'xp') return 'В программу лояльности';
  return null;
}

String _resultText(String type, int value) {
  if (type == 'micro') return 'Бонус лояльности: +$value XP';
  if (type == 'xp') return '+$value XP в программу лояльности';
  if (type.startsWith('discount')) {
    return 'Скидка $value% на следующую покупку';
  }
  return '+$value дн. к подписке';
}

String _relative(DateTime? at) {
  if (at == null) return '';
  final s = DateTime.now().difference(at).inSeconds.clamp(0, 1 << 30);
  if (s < 45) return 'только что';
  if (s < 3600) return '${s ~/ 60} мин назад';
  if (s < 86400) return '${s ~/ 3600} ч назад';
  return '${(s ~/ 86400).clamp(1, 99)} дн. назад';
}

class _FortuneDialog extends StatefulWidget {
  const _FortuneDialog();

  @override
  State<_FortuneDialog> createState() => _FortuneDialogState();
}

class _FortuneDialogState extends State<_FortuneDialog>
    with TickerProviderStateMixin {
  late final AnimationController _spinCtl = AnimationController(
    vsync: this,
    duration: _spinDuration,
  )..addListener(_trackHub);
  late final AnimationController _burstCtl = AnimationController(
    vsync: this,
    duration: _burstDuration,
  );
  final _prizes = ScrollController();
  Timer? _clock;
  Timer? _carousel;

  StarlitFortuneStatus? _status;
  List<StarlitFortuneWin> _wins = const [];
  var _loading = true;
  var _needsLogin = false;
  var _sound = true;
  var _pending = false;
  var _spinning = false;
  var _from = 0.0;
  var _to = 0.0;
  String? _hub;
  String? _error;
  String? _hint;
  StarlitFortuneSpin? _lastSpin;
  var _types = const <String>[];

  double get _rotation =>
      _from + (_to - _from) * _spinCurve.transform(_spinCtl.value);

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    unawaited(
      StarlitPrefs.soundEnabled().then((v) {
        if (mounted) setState(() => _sound = v);
      }),
    );
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _freeLocked) setState(() {});
    });
    _carousel = Timer.periodic(const Duration(seconds: 3), (_) => _advance());
  }

  @override
  void dispose() {
    _clock?.cancel();
    _carousel?.cancel();
    _spinCtl.dispose();
    _burstCtl.dispose();
    _prizes.dispose();
    super.dispose();
  }

  bool get _freeLocked {
    final s = _status;
    return s != null &&
        s.ready &&
        s.dailyFreeEnabled &&
        !s.dailyFreeAvailable;
  }

  Duration get _untilFree {
    final now = DateTime.now().toUtc();
    final next = DateTime.utc(now.year, now.month, now.day + 1);
    return next.difference(now);
  }

  Future<void> _load() async {
    final token = await StarlitPrefs.cabinetToken();
    if (token == null || token.isEmpty) {
      if (mounted) {
        setState(() {
          _loading = false;
          _needsLogin = true;
        });
      }
      return;
    }
    await StarlitCabinetApi.ensureCsrf();
    final status = await StarlitFortuneApi.status();
    final wins = status != null && status.ready && status.winnerFeed
        ? await StarlitFortuneApi.recentWins()
        : const <StarlitFortuneWin>[];
    if (!mounted) return;
    setState(() {
      _status = status;
      _wins = wins;
      _loading = false;
    });
  }

  Future<void> _refresh() async {
    final status = await StarlitFortuneApi.status();
    final wins = status != null && status.ready && status.winnerFeed
        ? await StarlitFortuneApi.recentWins()
        : _wins;
    if (!mounted) return;
    setState(() {
      _status = status ?? _status;
      _wins = wins;
    });
  }

  void _advance() {
    if (!_prizes.hasClients) return;
    final max = _prizes.position.maxScrollExtent;
    if (max <= 4) return;
    final step = (_prizes.position.viewportDimension * 0.45).clamp(160.0, 240.0);
    final target = _prizes.offset + 6 >= max
        ? 0.0
        : math.min(max, _prizes.offset + step);
    unawaited(
      _prizes.animateTo(
        target,
        duration: const Duration(milliseconds: 880),
        curve: Curves.easeInOutCubic,
      ),
    );
  }

  void _trackHub() {
    if (_types.isEmpty) return;
    final progress = Curves.easeOutCubic.transform(_spinCtl.value);
    final rot = _from + (_to - _from) * progress;
    final step = 360 / _types.length;
    final angle = (-rot) % 360;
    final slot = (angle / step).floor().clamp(0, _types.length - 1);
    final type = _types[slot];
    if (type != _hub && mounted) setState(() => _hub = type);
  }

  Future<void> _spin() async {
    final status = _status;
    if (status == null || _pending || _spinning) return;
    setState(() {
      _pending = true;
      _error = null;
    });
    if (_sound) StarlitSound.effect('gac_connect_kristall.wav');
    late final ({StarlitFortuneSpin? spin, String? reason}) res;
    try {
      res = await StarlitFortuneApi.spin();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _pending = false;
        _error = 'Не удалось связаться с сервером колеса.';
      });
      return;
    }
    if (!mounted) return;
    final spin = res.spin;
    if (spin == null) {
      final reason = res.reason ?? '';
      setState(() {
        _pending = false;
        _error = _reasons[reason] ??
            (reason.isEmpty || reason.startsWith('http_')
                ? (_reasons['unknown'] ?? 'Ошибка')
                : reason);
      });
      return;
    }
    final order = starlitWheelOrder(status.sectors);
    final n = math.max(order.length, 1);
    final slot = math.max(0, order.indexWhere((s) => s.index == spin.sectorIndex));
    final step = 360 / n;
    final base = _rotation;
    final align = ((-((slot + 0.5) * step) - base) % 360 + 360) % 360;
    final jitter = (math.Random().nextDouble() - 0.5) * math.min(step * 0.22, 18);
    setState(() {
      _pending = false;
      _spinning = true;
      _types = [for (final s in order) s.type];
      _from = base;
      _to = base + 5 * 360 + align + jitter;
      _lastSpin = spin;
    });
    try {
      await _spinCtl.forward(from: 0).orCancel;
    } on TickerCanceled {
      return;
    }
    if (!mounted) return;
    _from = _to;
    _spinCtl.value = 0;
    setState(() {
      _spinning = false;
      _hub = spin.type;
    });
    unawaited(_burstCtl.forward(from: 0));
    if (_sound) StarlitSound.effect('gac_connect_zvon.wav');
    unawaited(_refresh());
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    await showStarlitPopup<void>(
      context,
      builder: (_) => _PrizeDialog(spin: spin),
    );
  }

  String _subtitle(int cost) =>
      '$cost ${starlitPlural(cost, 'крутка', 'крутки', 'круток')} - '
      '$cost ${starlitPlural(cost, 'день', 'дня', 'дней')} подписки';

  String _countdown() {
    final d = _untilFree;
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '${d.inHours}ч $mм $sс';
  }

  @override
  Widget build(BuildContext context) {
    return StarlitPopupFrame(
      title: 'Колесо фортуны',
      width: 560,
      maxHeight: 800,
      child: SingleChildScrollView(child: _content()),
    );
  }

  Widget _content() {
    final status = _status;
    if (_loading) {
      return const _Notice(
        icon: 'sparkles',
        text: 'Загружаем колесо…',
        color: StarlitColors.muted,
      );
    }
    if (_needsLogin) {
      return const _Notice(
        icon: 'lock',
        text: 'Войдите в кабинет через Telegram, чтобы крутить колесо.',
        color: StarlitColors.muted,
      );
    }
    if (status == null) {
      return const _Notice(
        icon: 'triangle-alert',
        text: 'Не удалось загрузить колесо. Попробуйте позже.',
        color: StarlitColors.danger,
      );
    }
    if (!status.enabled) {
      return const _Notice(
        icon: 'sparkles',
        text: 'Колесо фортуны выключено.',
        color: StarlitColors.muted,
      );
    }
    if (!status.panelReady) {
      return const _Notice(
        icon: 'sparkles',
        text: 'Панель Remnawave не настроена — спин недоступен.',
        color: StarlitColors.muted,
      );
    }
    final order = starlitWheelOrder(status.sectors);
    final canPress = status.canSpin && !_spinning && !_pending;
    final label = _spinning || _pending
        ? 'Крутим…'
        : status.dailyFreeAvailable
        ? 'Крутить БЕСПЛАТНО'
        : 'Вращать колесо';
    final reason = status.canSpin
        ? null
        : (_reasons[status.reasonCode] ?? status.reasonCode);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _subtitle(status.spinCostDays),
                  style: starlitText(size: 13, color: StarlitColors.muted),
                ),
              ),
            ),
            const SizedBox(width: 10),
            _StatsPill(
              spins: status.paidSpinsLeft,
              days: status.remainDays,
              onTap: (key) => setState(() => _hint = _hint == key ? null : key),
            ),
            const SizedBox(width: 8),
            _SoundButton(
              muted: !_sound,
              onTap: () => setState(() => _sound = !_sound),
            ),
          ],
        ),
        if (_hint != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _hint == 'paid'
                  ? 'Осталось платных круток'
                  : 'Запас подписки в днях',
              style: starlitText(size: 12, color: StarlitColors.muted2),
            ),
          ),
        if (_freeLocked)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Бесплатная попытка ',
                  style: starlitText(size: 12, color: StarlitColors.muted),
                ),
                Text(
                  _countdown(),
                  style: starlitText(size: 12, weight: FontWeight.w700),
                ),
              ],
            ),
          ),
        if (status.winnerFeed) ...[
          const SizedBox(height: 14),
          _WinnerTicker(wins: _wins),
        ],
        const SizedBox(height: 18),
        Center(
          child: LayoutBuilder(
            builder: (context, box) {
              final size = math.min(box.maxWidth, 400.0);
              return _Wheel(
                size: size,
                order: order,
                hub: _hub,
                spinCtl: _spinCtl,
                burstCtl: _burstCtl,
                rotation: () => _rotation,
                spin: _lastSpin,
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        if (status.dailyFreeEnabled && status.dailyFreeAvailable)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              'У вас есть 1 бесплатная попытка',
              textAlign: TextAlign.center,
              style: starlitText(
                size: 12,
                weight: FontWeight.w600,
                color: StarlitColors.accent,
              ),
            ),
          ),
        Center(
          child: SizedBox(
            width: 240,
            child: StarlitPrimaryButton(
              label: label,
              onPressed: canPress ? () => unawaited(_spin()) : null,
            ),
          ),
        ),
        if (reason != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              reason,
              textAlign: TextAlign.center,
              style: starlitText(size: 13, color: StarlitColors.muted),
            ),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: starlitText(size: 13, color: StarlitColors.danger),
            ),
          ),
        const SizedBox(height: 18),
        _PrizeStrip(sectors: status.sectors, controller: _prizes),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text, required this.color});

  final String icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          StarlitUi.box(icon, size: 52, tint: color),
          const SizedBox(height: 14),
          Text(
            text,
            textAlign: TextAlign.center,
            style: starlitText(size: 14, color: color),
          ),
        ],
      ),
    );
  }
}

class _StatsPill extends StatelessWidget {
  const _StatsPill({
    required this.spins,
    required this.days,
    required this.onTap,
  });

  final int spins;
  final int days;
  final ValueChanged<String> onTap;

  Widget _cell(String key, String icon, Color color, String text) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => onTap(key),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              StarlitUi.icon(icon, size: 15, color: color),
              const SizedBox(width: 5),
              Text(text, style: starlitText(size: 13, weight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: StarlitColors.field,
        border: Border.all(color: StarlitColors.stroke),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _cell('paid', 'zap', StarlitColors.accent, '$spins'),
          Container(width: 1, height: 16, color: StarlitColors.stroke),
          _cell('sub', 'calendar-days', StarlitColors.success, '$days дн.'),
        ],
      ),
    );
  }
}

class _SoundButton extends StatelessWidget {
  const _SoundButton({required this.muted, required this.onTap});

  final bool muted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: StarlitColors.field,
            border: Border.all(color: StarlitColors.stroke),
          ),
          child: StarlitUi.icon(
            muted ? 'volume-x' : 'volume-2',
            size: 16,
            color: muted ? StarlitColors.muted2 : StarlitColors.text,
          ),
        ),
      ),
    );
  }
}

class _WinnerTicker extends StatefulWidget {
  const _WinnerTicker({required this.wins});

  final List<StarlitFortuneWin> wins;

  @override
  State<_WinnerTicker> createState() => _WinnerTickerState();
}

class _WinnerTickerState extends State<_WinnerTicker>
    with SingleTickerProviderStateMixin {
  static const _bg = Color(0xFF0A0E27);
  final _scroll = ScrollController();
  late final AnimationController _ctl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 70),
  )..addListener(_step);

  @override
  void initState() {
    super.initState();
    if (widget.wins.isNotEmpty) _ctl.repeat();
  }

  @override
  void didUpdateWidget(covariant _WinnerTicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.wins.isNotEmpty && !_ctl.isAnimating) _ctl.repeat();
  }

  @override
  void dispose() {
    _ctl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _step() {
    if (!_scroll.hasClients) return;
    final p = _scroll.position;
    final loop = (p.maxScrollExtent + p.viewportDimension) / 2;
    _scroll.jumpTo(_ctl.value * loop);
  }

  List<StarlitFortuneWin> _strip() {
    final src = widget.wins;
    if (src.isEmpty) return const [];
    var out = <StarlitFortuneWin>[];
    while (out.length < 12) {
      out = [...out, ...src];
    }
    return out;
  }

  Widget _item(StarlitFortuneWin w, bool first) {
    final glyph = _glyphColors[w.type] ?? StarlitColors.accent;
    final bold = starlitText(size: 13, weight: FontWeight.w700);
    final muted = starlitText(size: 13, color: StarlitColors.muted);
    final List<InlineSpan> spans;
    if (w.type.startsWith('days_')) {
      spans = [
        TextSpan(text: w.name, style: bold),
        TextSpan(text: ' выиграл ', style: muted),
        TextSpan(
          text: '+${w.value} дн.',
          style: starlitText(
            size: 13,
            weight: FontWeight.w700,
            color: const Color(0xFF6EE7B7),
          ),
        ),
      ];
    } else if (w.type.startsWith('discount_')) {
      spans = [
        TextSpan(text: w.name, style: bold),
        TextSpan(text: ' скидка ${w.value}%', style: bold),
      ];
    } else {
      spans = [
        TextSpan(text: w.name, style: bold),
        TextSpan(
          text: ' +${w.value} XP',
          style: starlitText(size: 13, weight: FontWeight.w700, color: glyph),
        ),
      ];
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!first)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              '●',
              style: starlitText(size: 9, color: StarlitColors.muted2),
            ),
          ),
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0x0DFFFFFF),
            border: Border.all(color: const Color(0x1AFFFFFF)),
          ),
          child: StarlitUi.icon(_iconFor(w.type), size: 13, color: glyph),
        ),
        const SizedBox(width: 7),
        Text.rich(TextSpan(children: spans)),
        Text(' · ${_relative(w.at)}', style: muted),
      ],
    );
  }

  Widget _row(List<StarlitFortuneWin> strip) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < strip.length; i++) _item(strip[i], i == 0),
      const SizedBox(width: 20),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final strip = _strip();
    return Container(
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: _bg,
        border: Border.all(color: const Color(0x14FFFFFF)),
      ),
      child: strip.isEmpty
          ? Center(
              child: Text(
                'Пока нет записей о выигрышах — крутите колесо первыми.',
                style: starlitText(size: 12, color: StarlitColors.muted),
              ),
            )
          : ClipRect(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: SingleChildScrollView(
                      controller: _scroll,
                      scrollDirection: Axis.horizontal,
                      physics: const NeverScrollableScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 9, left: 14),
                        child: Row(
                          children: [_row(strip), _row(strip)],
                        ),
                      ),
                    ),
                  ),
                  const Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: 28,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_bg, Color(0x000A0E27)],
                        ),
                      ),
                    ),
                  ),
                  const Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    width: 28,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0x000A0E27), _bg],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _Wheel extends StatelessWidget {
  const _Wheel({
    required this.size,
    required this.order,
    required this.hub,
    required this.spinCtl,
    required this.burstCtl,
    required this.rotation,
    required this.spin,
  });

  final double size;
  final List<StarlitSector> order;
  final String? hub;
  final Animation<double> spinCtl;
  final AnimationController burstCtl;
  final double Function() rotation;
  final StarlitFortuneSpin? spin;

  @override
  Widget build(BuildContext context) {
    final face = _WheelFace(size: size, order: order, hub: hub);
    return SizedBox(
      width: size,
      height: size + 6,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: 6,
            width: size,
            height: size,
            child: AnimatedBuilder(
              animation: burstCtl,
              builder: (context, child) {
                final t = burstCtl.value;
                final wobble = burstCtl.isAnimating
                    ? math.sin(t * math.pi * 3) * (1 - t) * 0.05
                    : 0.0;
                return Transform.rotate(angle: wobble, child: child);
              },
              child: Stack(
                children: [
                  AnimatedBuilder(
                    animation: spinCtl,
                    builder: (context, child) => Transform.rotate(
                      angle: rotation() * math.pi / 180,
                      child: child,
                    ),
                    child: face,
                  ),
                  if (spin != null)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: AnimatedBuilder(
                          animation: burstCtl,
                          builder: (context, _) => burstCtl.value == 0
                              ? const SizedBox.shrink()
                              : CustomPaint(
                                  painter: _BurstPainter(
                                    t: burstCtl.value,
                                    spin: spin!,
                                  ),
                                ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Positioned(
            left: size / 2 - 14,
            top: 0,
            child: const _Pointer(),
          ),
        ],
      ),
    );
  }
}

class _Pointer extends StatelessWidget {
  const _Pointer();

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: const Size(28, 22), painter: _PointerPainter());
}

class _PointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawShadow(path, const Color(0xFF000000), 3, true);
    canvas.drawPath(path, Paint()..color = StarlitColors.accent);
  }

  @override
  bool shouldRepaint(covariant _PointerPainter oldDelegate) => true;
}

class _WheelFace extends StatelessWidget {
  const _WheelFace({
    required this.size,
    required this.order,
    required this.hub,
  });

  final double size;
  final List<StarlitSector> order;
  final String? hub;

  @override
  Widget build(BuildContext context) {
    final n = order.length;
    final center = size / 2;
    final labelW = size * 0.19;
    final iconSize = size * 0.068;
    final fontSize = math.max(8.5, size * 0.024);
    final hubSize = size * 0.3;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _FacePainter(
                order,
                StarlitColors.stroke,
                const Color(0xFF020617),
              ),
            ),
          ),
          for (var i = 0; i < n; i++)
            _label(i, n, center, labelW, iconSize, fontSize),
          Positioned(
            left: center - hubSize / 2,
            top: center - hubSize / 2,
            width: hubSize,
            height: hubSize,
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: StarlitColors.card.withValues(alpha: 0.96),
                border: Border.all(color: StarlitColors.stroke),
              ),
              child: StarlitUi.icon(
                hub == null ? 'sparkles' : _iconFor(hub!),
                size: size * 0.12,
                color: hub == null ? StarlitColors.accent : const Color(0xFFFFFFFF),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(
    int slot,
    int n,
    double center,
    double w,
    double iconSize,
    double fontSize,
  ) {
    final angle = (-90 + (slot + 0.5) * 360 / n) * math.pi / 180;
    final dx = center + size * 0.37 * math.cos(angle);
    final dy = center + size * 0.37 * math.sin(angle);
    final sector = order[slot];
    final glyph =
        _glyphColors[sector.type] ?? const Color(0xFFFFFFFF);
    return Positioned(
      left: dx - w / 2,
      top: dy - size * 0.1,
      width: w,
      height: size * 0.2,
      child: Transform.rotate(
        angle: math.sin(angle) <= 0 ? angle + math.pi / 2 : angle - math.pi / 2,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            StarlitUi.icon(
              _iconFor(sector.type),
              size: iconSize,
              color: glyph,
            ),
            const SizedBox(height: 2),
            Text(
              _wheelShort(sector),
              maxLines: 2,
              overflow: TextOverflow.clip,
              textAlign: TextAlign.center,
              style: starlitText(
                size: fontSize,
                weight: FontWeight.w800,
                color: const Color(0xFFFFFFFF),
                height: 1.1,
              ).copyWith(
                shadows: const [
                  Shadow(
                    color: Color(0xEB000000),
                    blurRadius: 3,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FacePainter extends CustomPainter {
  _FacePainter(this.order, this.border, this.shadow);

  final List<StarlitSector> order;
  final Color border;
  final Color shadow;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 3;
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = const Color(0x59028CC7)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20),
    );
    final n = order.length;
    if (n == 0) {
      canvas.drawCircle(c, r, Paint()..color = StarlitColors.cardHi);
    } else {
      final step = 2 * math.pi / n;
      for (var i = 0; i < n; i++) {
        canvas.drawArc(
          rect,
          -math.pi / 2 + i * step,
          step + 0.004,
          true,
          Paint()..color = _wheelColor(order[i]),
        );
      }
      final rimWidth = r * 0.11;
      final rimRect = Rect.fromCircle(center: c, radius: r - rimWidth / 2);
      for (var i = 0; i < n; i++) {
        canvas.drawArc(
          rimRect,
          -math.pi / 2 + i * step,
          step + 0.004,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = rimWidth
            ..color = _rimColor(order[i]),
        );
      }
    }
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [const Color(0x00000000), shadow.withValues(alpha: 0.22)],
          stops: const [0.78, 1],
        ).createShader(rect),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = border,
    );
  }

  @override
  bool shouldRepaint(covariant _FacePainter oldDelegate) =>
      oldDelegate.order != order || oldDelegate.border != border;
}

class _BurstPainter extends CustomPainter {
  _BurstPainter({required this.t, required this.spin});

  final double t;
  final StarlitFortuneSpin spin;

  static const _normal = [
    Color(0xFF22D3EE),
    Color(0xFFA78BFA),
    Color(0xFFF59E0B),
    Color(0xFF34D399),
    Color(0xFFF472B6),
  ];
  static const _jackpot = [
    Color(0xFFFACC15),
    Color(0xFFF59E0B),
    Color(0xFFFB7185),
    Color(0xFFC084FC),
    Color(0xFF22D3EE),
    Color(0xFF34D399),
  ];

  String get _tier {
    final type = spin.type;
    if (type == 'days_180' || type == 'days_30' || type == 'days_15') {
      return 'jackpot';
    }
    if (type == 'discount_5' || spin.value >= 30) return 'good';
    return 'normal';
  }

  double _flash() {
    if (t < 0.2) return t / 0.2;
    if (t < 0.45) return 1 - (t - 0.2) / 0.25 * 0.16;
    return 0.84 * (1 - (t - 0.45) / 0.55);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final scale = size.shortestSide / 500;
    final flash = _flash().clamp(0.0, 1.0);
    if (flash > 0) {
      canvas.save();
      canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: r)));
      canvas.drawCircle(
        c,
        r * 1.1,
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xF7FFFFFF).withValues(alpha: 0.97 * flash),
              const Color(0x9EFACC15).withValues(alpha: 0.62 * flash),
              const Color(0x38FB923C).withValues(alpha: 0.22 * flash),
              const Color(0x00000000),
            ],
            stops: const [0, 0.34, 0.66, 1],
          ).createShader(Rect.fromCircle(center: c, radius: r * 1.1)),
      );
      canvas.restore();
    }
    final tier = _tier;
    final count = tier == 'jackpot'
        ? 82
        : tier == 'good'
        ? 58
        : 38;
    final palette = tier == 'jackpot' ? _jackpot : _normal;
    const total = 1400.0;
    final now = t * total;
    for (var a = 0; a < count; a++) {
      final frac = a / math.max(1, count - 1);
      final angle = math.pi * 2 * frac + (a % 3) * 0.18;
      final dist = (72 + a * 37 % 140) * scale;
      final delay = (a % 14) * 18.0;
      final duration = 900 + (a % 4) * 120.0;
      final p = ((now - delay) / duration).clamp(0.0, 1.0);
      if (p <= 0 || p >= 1) continue;
      final ease = Curves.easeOutCubic.transform(p);
      final opacity = p < 0.15 ? p / 0.15 : (p > 0.7 ? (1 - p) / 0.3 : 1.0);
      final pos = c +
          Offset(
            math.cos(angle) * dist * ease,
            (math.sin(angle) * dist * 0.92 + 32 * scale) * ease,
          );
      final w = (5 + a % 6) * scale.clamp(0.7, 1.4);
      final color = palette[a % palette.length].withValues(alpha: opacity);
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate((a.isEven ? 1 : -1) * (180 + a % 6 * 45) * ease * math.pi / 180);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: w, height: w * 1.36),
        Paint()..color = color,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _BurstPainter oldDelegate) =>
      oldDelegate.t != t;
}

class _PrizeStrip extends StatelessWidget {
  const _PrizeStrip({required this.sectors, required this.controller});

  final List<StarlitSector> sectors;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    final items = starlitPrizeOrder(sectors);
    if (items.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: StarlitColors.field,
        border: Border.all(color: StarlitColors.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Вы можете получить:',
            style: starlitText(size: 15, weight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            controller: controller,
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final s in items) ...[
                  _PrizeCard(sector: s),
                  const SizedBox(width: 10),
                ],
              ],
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _PrizeCard extends StatelessWidget {
  const _PrizeCard({required this.sector});

  final StarlitSector sector;

  @override
  Widget build(BuildContext context) {
    final hint = _prizeHint(sector);
    return Container(
      width: 132,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: StarlitColors.cardHi.withValues(alpha: 0.55),
        border: Border.all(color: StarlitColors.stroke),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            height: 4,
            color: _barColors[sector.type] ?? StarlitColors.accent,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
            child: Column(
              children: [
                StarlitUi.icon(
                  _iconFor(sector.type),
                  size: 34,
                  color: _glyphColors[sector.type] ?? StarlitColors.accent,
                ),
                const SizedBox(height: 8),
                Text(
                  _prizeLabel(sector),
                  textAlign: TextAlign.center,
                  style: starlitText(size: 13, weight: FontWeight.w700),
                ),
                if (hint != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    hint,
                    textAlign: TextAlign.center,
                    style: starlitText(size: 11, color: StarlitColors.muted),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PrizeDialog extends StatelessWidget {
  const _PrizeDialog({required this.spin});

  final StarlitFortuneSpin spin;

  @override
  Widget build(BuildContext context) {
    final glyph = _glyphColors[spin.type] ?? StarlitColors.accent;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: StarlitCard(
        padding: const EdgeInsets.fromLTRB(26, 26, 26, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Поздравляем!',
              textAlign: TextAlign.center,
              style: starlitText(size: 22, weight: FontWeight.w800, display: true),
            ),
            const SizedBox(height: 18),
            Center(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.8, end: 1),
                duration: const Duration(milliseconds: 550),
                curve: Curves.elasticOut,
                builder: (context, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: StarlitColors.field,
                    border: Border.all(color: glyph.withValues(alpha: 0.35)),
                    boxShadow: [
                      BoxShadow(
                        color: glyph.withValues(alpha: 0.25),
                        blurRadius: 24,
                      ),
                    ],
                  ),
                  child: StarlitUi.icon(
                    _iconFor(spin.type),
                    size: 58,
                    color: glyph,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: spin.value.toDouble()),
              duration: const Duration(milliseconds: 900),
              curve: const Cubic(0.22, 1, 0.36, 1),
              builder: (context, v, _) {
                final shown = v.round();
                final text = _resultText(spin.type, shown);
                final mark = '+$shown';
                final at = text.indexOf(mark);
                final base = starlitText(size: 14, color: StarlitColors.muted);
                if (at < 0) {
                  return Text(text, textAlign: TextAlign.center, style: base);
                }
                return Text.rich(
                  TextSpan(
                    style: base,
                    children: [
                      TextSpan(text: text.substring(0, at)),
                      TextSpan(
                        text: mark,
                        style: starlitText(
                          size: 14,
                          weight: FontWeight.w800,
                          color: StarlitColors.success,
                        ),
                      ),
                      TextSpan(text: text.substring(at + mark.length)),
                    ],
                  ),
                  textAlign: TextAlign.center,
                );
              },
            ),
            if (spin.free)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Бесплатный спин',
                  textAlign: TextAlign.center,
                  style: starlitText(
                    size: 12,
                    weight: FontWeight.w600,
                    color: StarlitColors.accent,
                  ),
                ),
              ),
            const SizedBox(height: 22),
            StarlitPrimaryButton(
              label: 'Забрать',
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
      ),
    );
  }
}
