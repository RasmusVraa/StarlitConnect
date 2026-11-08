import 'dart:async';

import 'package:starlit_connect/starlit/devices_api.dart';
import 'package:starlit_connect/starlit/plural.dart';
import 'package:starlit_connect/starlit/popup.dart';
import 'package:starlit_connect/starlit/theme.dart';
import 'package:starlit_connect/starlit/ui_icons.dart';
import 'package:starlit_connect/starlit/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:qr/qr.dart';

Future<void> showStarlitConnectDevice(
  BuildContext context, {
  required String subscriptionLink,
}) => showStarlitPopup<void>(
  context,
  builder: (_) => _ConnectDialog(subscriptionLink: subscriptionLink),
);

const _shareText =
    'Доступ к VPN 🔐\nОткройте эту ссылку на устройстве, где нужен VPN, '
    'и следуйте инструкции на странице:';

class _ConnectDialog extends StatefulWidget {
  const _ConnectDialog({required this.subscriptionLink});

  final String subscriptionLink;

  @override
  State<_ConnectDialog> createState() => _ConnectDialogState();
}

class _ConnectDialogState extends State<_ConnectDialog> {
  StarlitConnectInvite? _invite;
  var _loading = true;
  var _noSubscription = false;
  var _manual = false;
  String? _copied;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await StarlitDevicesApi.connectInvite();
    if (!mounted) return;
    setState(() {
      _invite = res.invite;
      _noSubscription = res.noSubscription;
      _loading = false;
    });
  }

  Future<void> _copy(String key, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    setState(() => _copied = key);
    await Future<void>.delayed(const Duration(milliseconds: 2200));
    if (mounted && _copied == key) setState(() => _copied = null);
  }

  @override
  Widget build(BuildContext context) {
    final link = widget.subscriptionLink;
    return StarlitPopupFrame(
      title: 'Инструкция на другое устройство',
      width: 440,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_loading)
              const _InviteSkeleton()
            else if (_invite == null)
              _failed()
            else
              _invitePanel(_invite!),
            if (link.isNotEmpty) ...[
              const SizedBox(height: 16),
              _manualPanel(link),
            ],
          ],
        ),
      ),
    );
  }

  Widget _failed() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: StarlitColors.field,
        border: Border.all(color: StarlitColors.stroke),
      ),
      child: Column(
        children: [
          Text(
            _noSubscription
                ? 'Сначала оформите подписку — подключать пока нечего.'
                : 'Не удалось получить ссылку. Попробуйте ещё раз.',
            textAlign: TextAlign.center,
            style: starlitText(size: 13, color: StarlitColors.muted),
          ),
          if (!_noSubscription) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: 160,
              child: StarlitGhostButton(
                label: 'Повторить',
                onPressed: () => unawaited(_load()),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _invitePanel(StarlitConnectInvite invite) {
    final copied = _copied == 'invite';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: StarlitColors.field,
            border: Border.all(color: StarlitColors.stroke),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: StarlitColors.accent.withValues(alpha: 0.12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    StarlitUi.icon(
                      'qr-code',
                      size: 14,
                      color: StarlitColors.accent,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Обычной камерой телефона',
                      style: starlitText(
                        size: 12,
                        weight: FontWeight.w700,
                        color: StarlitColors.accent,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              StarlitQr(data: invite.url, size: 196),
              const SizedBox(height: 12),
              Text(
                'Откроется страница с инструкцией',
                textAlign: TextAlign.center,
                style: starlitText(size: 13, color: StarlitColors.muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: StarlitPrimaryButton(
                label: copied
                    ? 'Скопировано — отправьте в мессенджер'
                    : 'Скопировать приглашение',
                icon: StarlitUi.icon(
                  copied ? 'check' : 'copy',
                  size: 16,
                  color: const Color(0xFF1A1020),
                ),
                onPressed: () =>
                    unawaited(_copy('invite', '$_shareText ${invite.url}')),
              ),
            ),
            const SizedBox(width: 10),
            _IconButton(
              icon: 'share-2',
              onTap: () => unawaited(_copy('invite', '$_shareText ${invite.url}')),
            ),
          ],
        ),
        if (invite.expiresAt != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              'Ссылка действует до ${starlitDayMonthTime(invite.expiresAt!)}',
              textAlign: TextAlign.center,
              style: starlitText(size: 11, color: StarlitColors.muted2),
            ),
          ),
      ],
    );
  }

  Widget _manualPanel(String link) {
    final copied = _copied == 'link';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _manual = !_manual),
            child: Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: StarlitColors.field,
                border: Border.all(color: StarlitColors.stroke),
              ),
              child: Row(
                children: [
                  StarlitUi.icon(
                    'wrench',
                    size: 16,
                    color: StarlitColors.accent,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Настроить вручную',
                      style: starlitText(size: 14, weight: FontWeight.w600),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _manual ? 0.5 : 0,
                    duration: const Duration(milliseconds: 220),
                    child: StarlitUi.icon(
                      'chevron-down',
                      size: 16,
                      color: StarlitColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _manual
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(2, 12, 2, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          StarlitQr(data: link, size: 96, radius: 6),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'QR подписки для VPN-приложений (Happ, Incy и др.)',
                              style: starlitText(
                                size: 12,
                                color: StarlitColors.muted,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Или скопируйте ссылку и вставьте в приложение:',
                        style: starlitText(
                          size: 12,
                          color: StarlitColors.muted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 38,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              alignment: Alignment.centerLeft,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                color: StarlitColors.field,
                                border: Border.all(color: StarlitColors.stroke),
                              ),
                              child: Text(
                                link,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: starlitText(
                                  size: 12,
                                  color: StarlitColors.muted,
                                ).copyWith(fontFamily: 'Consolas'),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              onTap: () => unawaited(_copy('link', link)),
                              child: Container(
                                height: 38,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: StarlitColors.stroke,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    StarlitUi.icon(
                                      copied ? 'check' : 'copy',
                                      size: 14,
                                      color: copied
                                          ? StarlitColors.success
                                          : StarlitColors.text,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      copied ? 'Скопировано!' : 'Скопировать',
                                      style: starlitText(
                                        size: 12,
                                        weight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({required this.icon, required this.onTap});

  final String icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 50,
          height: 50,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(StarlitRadii.pill),
            color: StarlitColors.cardHi,
            border: Border.all(color: StarlitColors.stroke),
          ),
          child: StarlitUi.icon(icon, size: 17, color: StarlitColors.text),
        ),
      ),
    );
  }
}

class _InviteSkeleton extends StatelessWidget {
  const _InviteSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: StarlitColors.field,
        border: Border.all(color: StarlitColors.stroke),
      ),
      child: Text(
        'Готовим ссылку…',
        style: starlitText(size: 13, color: StarlitColors.muted),
      ),
    );
  }
}

class StarlitQr extends StatefulWidget {
  const StarlitQr({
    super.key,
    required this.data,
    required this.size,
    this.radius = 8,
  });

  final String data;
  final double size;
  final double radius;

  @override
  State<StarlitQr> createState() => _StarlitQrState();
}

class _StarlitQrState extends State<StarlitQr> {
  late QrImage _image = _encode();

  QrImage _encode() => QrImage(
    QrCode(
      payload: QrPayload.fromString(widget.data),
      errorCorrectLevel: QrErrorCorrectLevel.medium,
    ),
  );

  @override
  void didUpdateWidget(covariant StarlitQr oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) _image = _encode();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final radius = widget.radius;
    final image = _image;
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.05),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        color: const Color(0xFFFFFFFF),
      ),
      child: CustomPaint(painter: _QrPainter(image)),
    );
  }
}

class _QrPainter extends CustomPainter {
  _QrPainter(this.image);

  final QrImage image;

  @override
  void paint(Canvas canvas, Size size) {
    final n = image.moduleCount;
    final cell = size.shortestSide / n;
    final paint = Paint()..color = const Color(0xFF111111);
    for (var y = 0; y < n; y++) {
      for (var x = 0; x < n; x++) {
        if (image.isDark(y, x)) {
          canvas.drawRect(
            Rect.fromLTWH(x * cell, y * cell, cell + 0.4, cell + 0.4),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _QrPainter oldDelegate) =>
      oldDelegate.image != image;
}
