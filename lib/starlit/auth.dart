import 'dart:async';

import 'package:dio/dio.dart';
import 'package:starlit_connect/common/common.dart';
import 'package:starlit_connect/engine/provider.dart';
import 'package:starlit_connect/starlit/brand.dart';
import 'package:starlit_connect/starlit/key_dialog.dart';
import 'package:starlit_connect/starlit/theme.dart';
import 'package:starlit_connect/starlit/webauth.dart';
import 'package:starlit_connect/starlit/widgets.dart';
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
  var _waiting = false;
  String? _error;
  CancelToken? _cancel;

  @override
  void dispose() {
    _cancel?.cancel('dispose');
    super.dispose();
  }

  void _cancelWait() {
    _cancel?.cancel('user');
    _cancel = null;
    if (!mounted) return;
    setState(() {
      _busy = false;
      _waiting = false;
      _error = null;
    });
  }

  Future<void> _authTelegram() async {
    await _authViaChannel(openTelegram: true);
  }

  Future<void> _authCabinet() async {
    await _authViaChannel(openTelegram: false);
  }

  Future<void> _authViaChannel({required bool openTelegram}) async {
    _cancel?.cancel('restart');
    final cancel = CancelToken();
    _cancel = cancel;
    setState(() {
      _error = null;
      _busy = true;
      _waiting = true;
    });
    try {
      final session = await StarlitWebAuth.request(cancelToken: cancel);
      final url = openTelegram
          ? session.resolvedTelegramUrl
          : session.resolvedWebUrl;
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!mounted || cancel.isCancelled) return;
      final result = await StarlitWebAuth.pollUntilReady(
        session.token,
        cancelToken: cancel,
      );
      if (!mounted || cancel.isCancelled) return;
      final link = result.subscriptionLink;
      if (link == null || link.isEmpty) {
        setState(
          () => _error =
              'Вход выполнен, но ссылки подписки нет. Оформите тариф в боте или кабинете.',
        );
        return;
      }
      await ref.read(starlitEngineProvider).importSubscription(link);
      if (!mounted) return;
      if (ref.read(starlitEngineProvider).hasSession) {
        widget.onReady();
      } else {
        setState(() => _error = 'Не удалось добавить подписку');
      }
    } on DioException catch (e) {
      if (CancelToken.isCancel(e) || !mounted) return;
      setState(
        () => _error = userFacingErrorMessage(e, currentAppLocalizations),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      if (msg.contains('Авторизация отменена')) return;
      setState(
        () => _error = userFacingErrorMessage(e, currentAppLocalizations),
      );
    } finally {
      if (_cancel == cancel) _cancel = null;
      if (mounted) {
        setState(() {
          _busy = false;
          _waiting = false;
        });
      }
    }
  }

  Future<void> _authManual() async {
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      final link = await showStarlitKeyDialog(
        context,
        source: StarlitAuthSource.manual,
      );
      if (link == null || !mounted) return;
      await ref.read(starlitEngineProvider).importSubscription(link);
      if (!mounted) return;
      if (ref.read(starlitEngineProvider).hasSession) {
        widget.onReady();
      } else {
        setState(() => _error = 'Не удалось добавить подписку');
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = userFacingErrorMessage(e, currentAppLocalizations),
        );
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
                  const StarlitLogo(size: 72),
                  const SizedBox(height: 20),
                  const StarlitText(
                    appName,
                    size: 28,
                    weight: FontWeight.w800,
                    align: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  StarlitText(
                    _waiting
                        ? 'Ожидаем подтверждение…\nЗавершите вход в Telegram или на сайте.'
                        : 'Telegram — команда /start в боте.\nСайт — вход в кабинете.\nСвоя ссылка подписки — отдельно.',
                    size: 14,
                    color: StarlitColors.muted,
                    align: TextAlign.center,
                    height: 1.45,
                  ),
                  const Spacer(),
                  if (_waiting) ...[
                    StarlitGhostButton(
                      label: 'Отменить ожидание',
                      onPressed: _cancelWait,
                    ),
                  ] else ...[
                    StarlitPrimaryButton(
                      label: 'Войти через Telegram',
                      onPressed: _busy
                          ? null
                          : () => unawaited(_authTelegram()),
                      icon: const _TgIcon(),
                    ),
                    const SizedBox(height: 12),
                    StarlitGhostButton(
                      label: 'Войти через сайт',
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
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const _KeyIcon(),
                            const SizedBox(width: 8),
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
                  ],
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
