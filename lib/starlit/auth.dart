import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/starlit/theme.dart';
import 'package:fl_clash/starlit/widgets.dart';
import 'package:flutter/services.dart';
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
  final _keyController = TextEditingController();
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _openTelegram() async {
    await launchUrl(
      Uri.parse(supportUrl),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _openCabinet() async {
    await launchUrl(
      Uri.parse(cabinetUrl),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _pasteKeyFlow() async {
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final raw = (data?.text ?? _keyController.text).trim();
      if (raw.isEmpty) {
        setState(() => _error = 'Вставьте ссылку подписки из кабинета');
        return;
      }
      if (!raw.isStarlitSubscriptionUrl) {
        setState(
          () => _error = 'Нужна ссылка с $subscriptionHost',
        );
        return;
      }
      await ref.read(profilesActionProvider.notifier).addProfileFromLink(raw);
      if (!mounted) return;
      final profiles = ref.read(profilesProvider);
      if (profiles.isNotEmpty) {
        widget.onReady();
      } else {
        setState(() => _error = 'Не удалось добавить подписку');
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
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  const StarlitMoonMark(size: 72),
                  const SizedBox(height: 18),
                  const Text(
                    appName,
                    style: TextStyle(
                      color: StarlitColors.text,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Войдите — и подписка подтянется сама.\nБез ручных конфигов.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: StarlitColors.muted,
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                  const Spacer(),
                  StarlitPrimaryButton(
                    label: 'Открыть Telegram-бот',
                    onPressed: _busy ? null : () => unawaited(_openTelegram()),
                    icon: const Text('✈', style: TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(height: 12),
                  StarlitGhostButton(
                    label: 'Кабинет / почта',
                    onPressed: _busy ? null : () => unawaited(_openCabinet()),
                    icon: const Text('@', style: TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(height: 18),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: _busy ? null : () => unawaited(_pasteKeyFlow()),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('🔑', style: TextStyle(fontSize: 14)),
                          SizedBox(width: 8),
                          Text(
                            'Вставить ключ подписки',
                            style: TextStyle(
                              color: StarlitColors.text,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: StarlitColors.danger,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  const Spacer(flex: 2),
                  const Text(
                    'Нет подписки? Загляните в кабинет — там пробный период.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: StarlitColors.muted2, fontSize: 12),
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
