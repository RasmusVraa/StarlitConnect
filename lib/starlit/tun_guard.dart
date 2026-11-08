import 'package:starlit_connect/engine/engine.dart';
import 'package:starlit_connect/starlit/l10n.dart';
import 'package:starlit_connect/starlit/popup.dart';
import 'package:starlit_connect/starlit/theme.dart';
import 'package:starlit_connect/starlit/widgets.dart';
import 'package:starlit_connect/starlit/zapret.dart';
import 'package:flutter/widgets.dart';

/// Enable/disable TUN with Zapret warning and admin-error popup.
Future<void> starlitSetTun(
  BuildContext context,
  StarlitEngine engine,
  bool on,
) async {
  if (on && await StarlitZapret.isRunning()) {
    if (!context.mounted) return;
    final proceed = await showStarlitPopup<bool>(
      context,
      builder: (ctx) => StarlitPopupFrame(
        title: StarlitL10n.of(
          ctx,
          ru: 'Zapret и TUN',
          en: 'Zapret and TUN',
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              StarlitL10n.of(
                ctx,
                ru:
                    'На компьютере запущен Zapret (Flowseal). Режим TUN вместе с Zapret может работать нестабильно: обрывы, «белый экран» сайтов, конфликт маршрутов.',
                en:
                    'Zapret (Flowseal) is running on this PC. TUN mode together with Zapret can be unstable: drops, blank pages, route conflicts.',
              ),
              style: starlitText(
                size: 14,
                color: StarlitColors.muted,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              StarlitL10n.of(
                ctx,
                ru:
                    'С Zapret лучше оставить режим прокси (без TUN) — системный прокси и Zapret обычно уживаются спокойнее.',
                en:
                    'With Zapret, prefer proxy mode (without TUN) — system proxy and Zapret usually coexist more calmly.',
              ),
              style: starlitText(
                size: 14,
                weight: FontWeight.w600,
                color: StarlitColors.warn,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 18),
            StarlitPrimaryButton(
              label: StarlitL10n.of(
                ctx,
                ru: 'Оставить прокси',
                en: 'Keep proxy',
              ),
              onPressed: () => Navigator.of(ctx).pop(false),
            ),
            const SizedBox(height: 10),
            StarlitGhostButton(
              label: StarlitL10n.of(
                ctx,
                ru: 'Включить TUN всё равно',
                en: 'Enable TUN anyway',
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
          ],
        ),
      ),
    );
    if (proceed != true) return;
  }
  try {
    await engine.setTun(on);
  } catch (e) {
    if (!context.mounted) return;
    final msg = e.toString().replaceFirst(RegExp(r'^Bad state:\s*'), '');
    await showStarlitPopup<void>(
      context,
      builder: (_) => StarlitPopupFrame(
        title: StarlitL10n.of(context, ru: 'TUN', en: 'TUN'),
        child: Text(
          msg.isEmpty
              ? StarlitL10n.of(
                  context,
                  ru:
                      'Не удалось включить TUN. Запустите приложение от имени администратора.',
                  en:
                      'Could not enable TUN. Run the app as administrator.',
                )
              : msg,
          style: starlitText(size: 14, color: StarlitColors.muted),
        ),
      ),
    );
  }
}
