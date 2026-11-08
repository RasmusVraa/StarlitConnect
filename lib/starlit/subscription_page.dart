import 'dart:async';
import 'dart:math' as math;

import 'package:starlit_connect/common/common.dart';
import 'package:starlit_connect/engine/provider.dart';
import 'package:starlit_connect/models/models.dart';
import 'package:starlit_connect/starlit/cabinet_api.dart';
import 'package:starlit_connect/starlit/subscription_info.dart';
import 'package:starlit_connect/starlit/connect_device_dialog.dart';
import 'package:starlit_connect/starlit/devices_card.dart';
import 'package:starlit_connect/starlit/fortune_dialog.dart';
import 'package:starlit_connect/starlit/key_dialog.dart';
import 'package:starlit_connect/starlit/server_status_dialog.dart';
import 'package:starlit_connect/starlit/scroll.dart';
import 'package:starlit_connect/starlit/session.dart';
import 'package:starlit_connect/starlit/slots_dialog.dart';
import 'package:starlit_connect/starlit/status_api.dart';
import 'package:starlit_connect/starlit/theme.dart';
import 'package:starlit_connect/starlit/ui_icons.dart';
import 'package:starlit_connect/starlit/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Кабинет в стиле internet.starlit-moon.ru/cabinet — всё внутри приложения.
class StarlitSubscriptionPage extends ConsumerStatefulWidget {
  const StarlitSubscriptionPage({super.key});

  @override
  ConsumerState<StarlitSubscriptionPage> createState() =>
      _StarlitSubscriptionPageState();
}

class _StarlitSubscriptionPageState
    extends ConsumerState<StarlitSubscriptionPage> {
  var _online = 0;
  var _total = 0;
  var _loaded = false;
  var _busy = false;
  StarlitCabinetSnapshot? _snap;
  final _scroll = ScrollController();
  Timer? _syncTimer;

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
    _syncTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (!mounted || _busy) return;
      unawaited(_reloadCabinet());
    });
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await StarlitCabinetApi.ensureCsrf();
    await Future.wait([_loadStatus(), _reloadCabinet()]);
  }

  Future<void> _loadStatus() async {
    try {
      final nodes = await StarlitStatusApi.fetchNodes();
      if (!mounted) return;
      setState(() {
        _total = nodes.length;
        _online =
            nodes.where((n) => n.state == 'up' || n.state == 'partial').length;
        _loaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  Future<void> _reloadCabinet() async {
    final engine = ref.read(starlitEngineProvider);
    final info = StarlitSubscriptionInfo.parse(engine.userInfo);
    final used = info.upload + info.download;
    final total = info.total;
    try {
      final snap = await StarlitCabinetApi.load(
        subscriptionUrl: engine.subscriptionUrl,
        usedBytes: used,
        totalBytes: total,
        expireFromProfile: info.expire,
      );
      if (!mounted) return;
      // Пустой список устройств при живой сессии — не затираем прошлый.
      final prev = _snap;
      final merged = (snap.devices.isEmpty &&
              prev != null &&
              prev.devices.isNotEmpty)
          ? StarlitCabinetSnapshot(
              tariffName: snap.tariffName,
              daysLeft: snap.daysLeft,
              expireAt: snap.expireAt,
              devices: prev.devices,
              deviceLimit: snap.deviceLimit ?? prev.deviceLimit,
              usedBytes: snap.usedBytes,
              totalBytes: snap.totalBytes,
              connected: snap.connected >= 0 ? snap.connected : prev.connected,
              devicesEnabled: snap.devicesEnabled,
              slots: snap.slots ?? prev.slots,
              isTrial: snap.isTrial,
              subscriptionLink: snap.subscriptionLink.isNotEmpty
                  ? snap.subscriptionLink
                  : prev.subscriptionLink,
            )
          : snap;
      setState(() => _snap = merged);
    } catch (_) {
      if (!mounted) return;
      // Ошибка сети — оставляем предыдущий снимок, не обнуляем устройства.
      if (_snap != null) return;
      setState(() {
        _snap = StarlitCabinetSnapshot(
          tariffName: 'Starlit VPN',
          daysLeft: null,
          expireAt: info.expire,
          devices: const [],
          deviceLimit: null,
          usedBytes: used,
          totalBytes: total,
        );
      });
    }
  }

  Future<void> _update() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(starlitEngineProvider).refreshSubscription();
      await _reloadCabinet();
      await _loadStatus();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _replaceKey() async {
    final link = await showStarlitKeyDialog(
      context,
      source: StarlitAuthSource.manual,
    );
    if (link == null) return;
    await StarlitSession.clearSubscriptions(ref);
    await ref.read(starlitEngineProvider).importSubscription(link);
    await _reloadCabinet();
  }

  Future<void> _deleteLocal() async {
    final ok = await StarlitSession.confirm(
      context,
      title: 'Удалить подписку',
      message:
          'Подписка будет удалена только из этого приложения. '
          'В боте и кабинете она останется. VPN отключится.',
      confirmText: 'Удалить',
    );
    if (!ok) return;
    await StarlitSession.clearSubscriptions(ref);
    await _reloadCabinet();
  }

  Future<void> _deleteDevice(StarlitCabinetDevice device) async {
    if (device.isLocal) {
      await _deleteLocal();
      return;
    }
    final ok = await StarlitSession.confirm(
      context,
      title: 'Отвязать устройство',
      message: '«${device.title}» будет отвязано от подписки.',
      confirmText: 'Отвязать',
    );
    if (!ok) return;
    await StarlitCabinetApi.deleteDevice(device.hwid);
    await _reloadCabinet();
  }

  Future<void> _addDevice() async {
    final engine = ref.read(starlitEngineProvider);
    final link = _snap?.subscriptionLink.isNotEmpty == true
        ? _snap!.subscriptionLink
        : (engine.subscriptionUrl ?? '');
    if (link.isEmpty) {
      await _replaceKey();
      return;
    }
    if (!mounted) return;
    await showStarlitConnectDevice(context, subscriptionLink: link);
  }

  Future<bool> _renameDevice(StarlitCabinetDevice device, String name) async {
    final ok = await StarlitCabinetApi.renameDevice(device.hwid, name);
    if (ok) await _reloadCabinet();
    return ok;
  }

  Future<void> _openSlots(int target) async {
    final snap = _snap;
    final slots = snap?.slots;
    if (snap == null || slots == null) return;
    final changed = await showStarlitSlots(
      context,
      slots: slots,
      connected: snap.connected,
      expireAt: snap.expireAt,
      initialTarget: target,
    );
    if (changed) await _reloadCabinet();
  }

  Future<void> _showExtend() async {
    final tariffs = await StarlitCabinetApi.fetchTariffs();
    if (!mounted) return;
    await _showSheet(
      title: 'Продлить подписку',
      child: Column(
        children: [
          for (final t in tariffs.take(6)) ...[
            StarlitCard(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${t['name'] ?? 'Тариф'}',
                          style: starlitText(
                            size: 14,
                            weight: FontWeight.w700,
                          ),
                        ),
                        if ('${t['description'] ?? ''}'.isNotEmpty)
                          Text(
                            _stripHtml('${t['description']}'),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: starlitText(
                              size: 12,
                              color: StarlitColors.muted2,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 8),
          StarlitPrimaryButton(
            label: 'Оформить в Telegram-боте',
            onPressed: () => unawaited(
              launchUrl(
                Uri.parse(supportUrl),
                mode: LaunchMode.externalApplication,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showSheet({
    required String title,
    required Widget child,
  }) async {
    await Navigator.of(context).push<void>(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: const Color(0x99000000),
        pageBuilder: (ctx, _, _) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480, maxHeight: 640),
              child: StarlitCard(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: starlitText(
                              size: 18,
                              weight: FontWeight.w800,
                              display: true,
                            ),
                          ),
                        ),
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () => Navigator.of(ctx).pop(),
                            child: Text(
                              'Закрыть',
                              style: starlitText(
                                size: 13,
                                color: StarlitColors.accent,
                                weight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Flexible(
                      child: SingleChildScrollView(child: child),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  static String _stripHtml(String raw) =>
      raw.replaceAll(RegExp(r'<[^>]+>'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

  @override
  Widget build(BuildContext context) {
    final engine = ref.watch(starlitEngineProvider);
    final hasSub = engine.hasSession;
    final info = StarlitSubscriptionInfo.parse(engine.userInfo);
    final usedBytes = _snap?.usedBytes ?? (info.upload + info.download);
    final totalBytes = _snap?.totalBytes ?? info.total;
    final usage = totalBytes > 0
        ? (usedBytes / totalBytes).clamp(0.0, 1.0)
        : 0.0;
    final daysLeft = _snap?.daysLeft;
    final expire = _snap?.expireAt ?? info.expire;
    final tariff = hasSub ? (_snap?.tariffName ?? 'Starlit VPN') : 'Гостевой режим';
    final devices = _snap?.devices ?? const <StarlitCabinetDevice>[];
    final limit = _snap?.deviceLimit;
    final connected = _snap?.connected ?? devices.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 22, 0, 20),
      child: StarlitScrollbar(
        controller: _scroll,
        contentRight: 18,
        child: ListView(
          controller: _scroll,
          primary: false,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          StarlitUi.icon(
                            'credit-card',
                            size: 22,
                            color: StarlitColors.accent,
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              tariff,
                              style: starlitText(
                                size: 26,
                                weight: FontWeight.w800,
                                display: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        hasSub
                            ? (expire == null
                                  ? 'Подписка активна'
                                  : 'до ${_fmtLongDate(expire)}')
                            : 'Войдите или вставьте ключ подписки',
                        style: starlitText(
                          size: 14,
                          color: StarlitColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                _StatusPill(active: hasSub),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _RingStat(
                    progress: daysLeft == null
                        ? 0
                        : (daysLeft / math.max(daysLeft, 365)).clamp(0.0, 1.0),
                    center: daysLeft?.toString() ?? '—',
                    caption: _daysCaption(daysLeft),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _RingStat(
                    progress: usage,
                    center: totalBytes > 0
                        ? '${(usage * 100).round()}%'
                        : '∞',
                    caption: totalBytes > 0
                        ? '${usedBytes.traffic.show}/${totalBytes.traffic.show}'
                        : usedBytes.traffic.show,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _RingStat(
                    progress: limit != null && limit > 0
                        ? (connected / limit).clamp(0.0, 1.0)
                        : (hasSub ? 0.2 : 0),
                    center: '$connected',
                    caption: 'УСТРОЙСТВА',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _PinkButton(
              label: hasSub ? 'Обновить кабинет' : 'Подключить устройство',
              trailing: hasSub
                  ? (limit != null && limit > 0 ? '$connected/$limit' : '$connected/∞')
                  : null,
              onTap: () => unawaited(hasSub ? _update() : _replaceKey()),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ActionTile(
                    icon: 'monitor',
                    label: 'Добавить доп. устройство',
                    onTap: () => unawaited(_addDevice()),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionTile(
                    icon: 'receipt',
                    label: 'Продлить подписку',
                    onTap: () => unawaited(_showExtend()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _ActionTile(
                    icon: 'sparkles',
                    label: 'Колесо фортуны',
                    onTap: () => unawaited(showStarlitFortune(context)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionTile(
                    icon: 'activity',
                    label: 'Статус серверов',
                    onTap: () => unawaited(showStarlitServerStatus(context)),
                    subtitle: _loaded ? '$_online/$_total онлайн' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            StarlitDevicesCard(
              snapshot: _snap,
              hasSub: hasSub,
              onDelete: _deleteDevice,
              onRename: _renameDevice,
              onAdd: () => unawaited(_addDevice()),
              onSlots: (target) => unawaited(_openSlots(target)),
            ),
            const SizedBox(height: 12),
            StarlitCard(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        'Расход за период',
                        style: starlitText(
                          size: 14,
                          weight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        usedBytes.traffic.show,
                        style: starlitText(
                          size: 14,
                          weight: FontWeight.w800,
                          color: StarlitColors.accent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const _Hairline(),
                  const SizedBox(height: 8),
                  _LinkRow(
                    icon: 'key-round',
                    title: hasSub ? 'Сменить ключ' : 'Вставить ключ',
                    subtitle: 'subscription URL',
                    onTap: () => unawaited(_replaceKey()),
                  ),
                  const _Hairline(),
                  _LinkRow(
                    icon: 'bot',
                    title: 'Telegram-бот',
                    subtitle: '@starlitvpnbot',
                    onTap: () => unawaited(
                      launchUrl(
                        Uri.parse(supportUrl),
                        mode: LaunchMode.externalApplication,
                      ),
                    ),
                  ),
                  if (hasSub) ...[
                    const _Hairline(),
                    _LinkRow(
                      icon: 'trash-2',
                      title: 'Удалить из приложения',
                      subtitle: 'ключ в кабинете сохранится',
                      onTap: () => unawaited(_deleteLocal()),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  static String _daysCaption(int? days) {
    if (days == null) return 'дней';
    final n = days % 100;
    final n1 = n % 10;
    if (n > 10 && n < 20) return 'дней';
    if (n1 == 1) return 'день';
    if (n1 >= 2 && n1 <= 4) return 'дня';
    return 'дней';
  }

  static String _fmtLongDate(DateTime d) {
    const months = <String>[
      'января',
      'февраля',
      'марта',
      'апреля',
      'мая',
      'июня',
      'июля',
      'августа',
      'сентября',
      'октября',
      'ноября',
      'декабря',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year} г.';
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? StarlitColors.success : StarlitColors.muted2;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
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
            active ? 'Активна' : 'Нет ключа',
            style: starlitText(size: 12, weight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}

class _RingStat extends StatelessWidget {
  const _RingStat({
    required this.progress,
    required this.center,
    required this.caption,
  });

  final double progress;
  final String center;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return StarlitCard(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      child: Column(
        children: [
          SizedBox(
            width: 86,
            height: 86,
            child: CustomPaint(
              painter: _RingPainter(
                progress: progress.clamp(0.0, 1.0),
                color: StarlitColors.accent,
                track: const Color(0xFF2A2234),
              ),
              child: Center(
                child: Text(
                  center,
                  textAlign: TextAlign.center,
                  style: starlitText(
                    size: center.length > 4 ? 16 : 22,
                    weight: FontWeight.w800,
                    display: true,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            caption,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: starlitText(
              size: 11,
              weight: FontWeight.w700,
              color: StarlitColors.muted2,
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.color,
    required this.track,
  });

  final double progress;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.shortestSide / 2 - 5;
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..color = track;
    final progPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawCircle(c, r, trackPaint);
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      progPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

class _PinkButton extends StatelessWidget {
  const _PinkButton({
    required this.label,
    required this.onTap,
    this.trailing,
  });

  final String label;
  final VoidCallback onTap;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: LinearGradient(
              colors: [StarlitColors.accent, const Color(0xFFD47AB8)],
            ),
            boxShadow: [
              BoxShadow(
                color: StarlitColors.accent.withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: starlitText(
                    size: 15,
                    weight: FontWeight.w800,
                    color: const Color(0xFF1A1020),
                  ),
                ),
              ),
              if (trailing != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: const Color(0x331A1020),
                  ),
                  child: Text(
                    trailing!,
                    style: starlitText(
                      size: 12,
                      weight: FontWeight.w800,
                      color: const Color(0xFF1A1020),
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

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
  });

  final String icon;
  final String label;
  final VoidCallback onTap;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: StarlitCard(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Row(
            children: [
              StarlitUi.box(icon, size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: starlitText(
                        size: 13,
                        weight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: starlitText(
                          size: 11,
                          color: StarlitColors.muted2,
                        ),
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

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              StarlitUi.box(icon, size: 34),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: starlitText(size: 14, weight: FontWeight.w700),
                    ),
                    Text(
                      subtitle,
                      style: starlitText(
                        size: 12,
                        color: StarlitColors.muted2,
                      ),
                    ),
                  ],
                ),
              ),
              StarlitUi.icon(
                'chevron-right',
                size: 16,
                color: StarlitColors.muted2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Hairline extends StatelessWidget {
  const _Hairline();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      color: StarlitColors.stroke.withValues(alpha: 0.65),
    );
  }
}
