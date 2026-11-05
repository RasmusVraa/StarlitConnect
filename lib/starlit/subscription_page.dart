import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/starlit/theme.dart';
import 'package:fl_clash/starlit/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

class StarlitSubscriptionPage extends ConsumerWidget {
  const StarlitSubscriptionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(profilesProvider);
    final hasSub = profiles.any((p) => p.url.isNotEmpty);

    return StarlitScaffold(
      glow: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 32, 32, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const StarlitSectionTitle(
              'Подписка',
              subtitle: 'Срок, тариф и оплата — в кабинете Starlit.',
            ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      StarlitMoonMark(size: 88, muted: !hasSub),
                      const SizedBox(height: 22),
                      Text(
                        hasSub
                            ? 'Подписка подключена в приложении'
                            : 'Войдите, чтобы продлевать подписку прямо отсюда',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: StarlitColors.muted,
                          fontSize: 15,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 28),
                      StarlitPrimaryButton(
                        label: hasSub
                            ? 'Открыть кабинет'
                            : 'Открыть Telegram-бот',
                        onPressed: () => unawaited(
                          launchUrl(
                            Uri.parse(hasSub ? cabinetUrl : supportUrl),
                            mode: LaunchMode.externalApplication,
                          ),
                        ),
                      ),
                      if (hasSub) ...[
                        const SizedBox(height: 12),
                        StarlitGhostButton(
                          label: 'Обновить подписку',
                          onPressed: () => unawaited(
                            ref
                                .read(profilesActionProvider.notifier)
                                .autoUpdateProfiles(),
                          ),
                        ),
                      ],
                    ],
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
