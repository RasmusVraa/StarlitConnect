import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/starlit/key_dialog.dart';
import 'package:fl_clash/starlit/theme.dart';
import 'package:fl_clash/starlit/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

class StarlitAuthPage extends ConsumerStatefulWidget {
  const StarlitAuthPage({super.key, required this.onReady});

  final VoidCallback onReady;

  @override
  ConsumerState<StarlitAuthPage> createState() => _StarlitAuthPageState();
}

class _StarlitAuthPageState extends ConsumerState<StarlitAuthPage> {
  var _busy = false;
  String? _error;

  Future<void> _authTelegram() async {
    await launchUrl(
      Uri.parse(supportUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!mounted) return;
    await _collectLink(StarlitAuthSource.telegram);
  }

  Future<void> _authCabinet() async {
    await launchUrl(
      Uri.parse(cabinetUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!mounted) return;
    await _collectLink(StarlitAuthSource.cabinet);
  }

  Future<void> _authManual() async {
    await _collectLink(StarlitAuthSource.manual);
  }

  Future<void> _collectLink(StarlitAuthSource source) async {
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      final link = await showStarlitKeyDialog(context, source: source);
      if (link == null || !mounted) return;
      await ref.read(profilesActionProvider.notifier).addProfileFromLink(link);
      if (!mounted) return;
      if (ref.read(profilesProvider).isNotEmpty) {
        widget.onReady();
      } else {
        setState(() => _error = 'Не удалось добавить подписку');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = userFacingErrorMessage(e, currentAppLocalizations));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StarlitScaffold(
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  const StarlitMoonMark(size: 68),
                  const SizedBox(height: 20),
                  const StarlitText(
                    appName,
                    size: 28,
                    weight: FontWeight.w800,
                    align: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  const StarlitText(
                    'Авторизуйтесь через бота или кабинет —\nзатем вставьте ссылку подписки.',
                    size: 14,
                    color: StarlitColors.muted,
                    align: TextAlign.center,
                    height: 1.45,
                  ),
                  const Spacer(),
                  StarlitPrimaryButton(
                    label: 'Войти через Telegram',
                    onPressed: _busy
                        ? null
                        : () => unawaited(_authTelegram()),
                    icon: const _TgIcon(),
                  ),
                  const SizedBox(height: 12),
                  StarlitGhostButton(
                    label: 'Войти через кабинет / почту',
                    onPressed: _busy
                        ? null
                        : () => unawaited(_authCabinet()),
                    icon: const _MailIcon(),
                  ),
                  const SizedBox(height: 22),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: _busy ? null : () => unawaited(_authManual()),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _KeyIcon(),
                          SizedBox(width: 8),
                          StarlitText(
                            'Вставить ключ подписки',
                            size: 14,
                            weight: FontWeight.w600,
                            color: StarlitColors.accent,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    StarlitText(
                      _error!,
                      size: 13,
                      color: StarlitColors.danger,
                      align: TextAlign.center,
                    ),
                  ],
                  const Spacer(flex: 2),
                  const StarlitText(
                    'Нет подписки? Оформите в кабинете или у @starlitvpnbot',
                    size: 12,
                    color: StarlitColors.muted2,
                    align: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TgIcon extends StatelessWidget {
  const _TgIcon();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: const Size(18, 18), painter: _PlanePainter());
  }
}

class _MailIcon extends StatelessWidget {
  const _MailIcon();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: const Size(18, 18), painter: _AtPainter());
  }
}

class _KeyIcon extends StatelessWidget {
  const _KeyIcon();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: const Size(16, 16), painter: _KeyPainter());
  }
}

class _PlanePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFF041018)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(size.width * 0.1, size.height * 0.55)
      ..lineTo(size.width * 0.9, size.height * 0.2)
      ..lineTo(size.width * 0.45, size.height * 0.85)
      ..lineTo(size.width * 0.4, size.height * 0.55)
      ..close();
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AtPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = StarlitColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    canvas.drawCircle(
      Offset(size.width * 0.45, size.height * 0.5),
      size.width * 0.22,
      p,
    );
    canvas.drawArc(
      Rect.fromCircle(
        center: Offset(size.width * 0.5, size.height * 0.5),
        radius: size.width * 0.38,
      ),
      -0.8,
      4.8,
      false,
      p,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _KeyPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = StarlitColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(
      Offset(size.width * 0.32, size.height * 0.5),
      size.width * 0.22,
      p,
    );
    canvas.drawLine(
      Offset(size.width * 0.54, size.height * 0.5),
      Offset(size.width * 0.92, size.height * 0.5),
      p,
    );
    canvas.drawLine(
      Offset(size.width * 0.78, size.height * 0.5),
      Offset(size.width * 0.78, size.height * 0.72),
      p,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
