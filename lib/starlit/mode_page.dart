import 'dart:async';

import 'package:fl_clash/enum/enum.dart' show Mode;
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/starlit/prefs.dart';
import 'package:fl_clash/starlit/theme.dart';
import 'package:fl_clash/starlit/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StarlitModePage extends ConsumerStatefulWidget {
  const StarlitModePage({super.key});

  @override
  ConsumerState<StarlitModePage> createState() => _StarlitModePageState();
}

class _StarlitModePageState extends ConsumerState<StarlitModePage> {
  var _route = 'smart';
  var _services = <String>{};

  static const _catalog = <(String id, String title, String subtitle)>[
    ('youtube', 'YouTube', 'Видео и Shorts'),
    ('instagram', 'Instagram', 'Лента и Reels'),
    ('telegram', 'Telegram', 'Чаты и звонки'),
    ('whatsapp', 'WhatsApp', 'Сообщения'),
    ('tiktok', 'TikTok', 'Клипы'),
    ('discord', 'Discord', 'Голос и чат'),
    ('chatgpt', 'ChatGPT', 'OpenAI'),
    ('gemini', 'Gemini', 'Google AI'),
    ('claude', 'Claude', 'Anthropic'),
    ('x', 'X', 'Лента'),
    ('twitch', 'Twitch', 'Стримы'),
    ('cloudflare', 'Cloudflare', 'Сайты на CF'),
  ];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final mode = await StarlitPrefs.routeMode();
    final services = await StarlitPrefs.enabledServices();
    if (!mounted) return;
    setState(() {
      _route = mode;
      _services = services;
    });
  }

  Future<void> _setRoute(String mode) async {
    setState(() => _route = mode);
    await StarlitPrefs.setRouteMode(mode);
    final clashMode = switch (mode) {
      'all' => Mode.global,
      _ => Mode.rule,
    };
    ref.read(patchClashConfigProvider.notifier).update(
      (state) => state.copyWith(mode: clashMode),
    );
  }

  Future<void> _toggleService(String id, bool on) async {
    final next = {..._services};
    if (on) {
      next.add(id);
    } else {
      next.remove(id);
    }
    setState(() => _services = next);
    await StarlitPrefs.setEnabledServices(next);
  }

  @override
  Widget build(BuildContext context) {
    final tun = ref.watch(
      patchClashConfigProvider.select((s) => s.tun.enable),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const StarlitSectionTitle(
            'Режим',
            subtitle: 'Что идёт через VPN, а что напрямую.',
          ),
          const SizedBox(height: 22),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: ListView(
                    children: [
                      const _Label('Как пускать трафик'),
                      const SizedBox(height: 10),
                      _RouteOption(
                        title: 'Умный',
                        subtitle: 'Российские сайты напрямую, зарубежные — через VPN',
                        selected: _route == 'smart',
                        onTap: () => unawaited(_setRoute('smart')),
                      ),
                      const SizedBox(height: 10),
                      _RouteOption(
                        title: 'Всё через VPN',
                        subtitle: 'Весь трафик компьютера через сервер',
                        selected: _route == 'all',
                        onTap: () => unawaited(_setRoute('all')),
                      ),
                      const SizedBox(height: 10),
                      _RouteOption(
                        title: 'Только выбранные',
                        subtitle: 'Через VPN идут сервисы справа, остальное напрямую',
                        selected: _route == 'selected',
                        onTap: () => unawaited(_setRoute('selected')),
                      ),
                      const SizedBox(height: 18),
                      StarlitCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Режим TUN',
                              style: TextStyle(
                                color: StarlitColors.text,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Обычный прокси видят не все программы. TUN ловит трафик системы: игры, торренты, лаунчеры.',
                              style: TextStyle(
                                color: StarlitColors.muted,
                                fontSize: 13,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                const Text(
                                  '🌐',
                                  style: TextStyle(fontSize: 18),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    tun ? 'Включён' : 'Выключен',
                                    style: const TextStyle(
                                      color: StarlitColors.text,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                StarlitToggle(
                                  value: tun,
                                  onChanged: (_) => ref
                                      .read(systemActionProvider.notifier)
                                      .updateTun(),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      StarlitCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Программы',
                              style: TextStyle(
                                color: StarlitColors.text,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Список процессов — в расширенных настройках профиля Clash.',
                              style: TextStyle(
                                color: StarlitColors.muted,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  flex: 6,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Label('Через VPN'),
                      const SizedBox(height: 10),
                      Expanded(
                        child: GridView.builder(
                          gridDelegate:
                              const MagicalGridDelegate(),
                          itemCount: _catalog.length,
                          itemBuilder: (_, i) {
                            final item = _catalog[i];
                            final on = _services.contains(item.$1);
                            return StarlitCard(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          item.$2,
                                          style: const TextStyle(
                                            color: StarlitColors.text,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Text(
                                          item.$3,
                                          style: const TextStyle(
                                            color: StarlitColors.muted2,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  StarlitToggle(
                                    value: on,
                                    onChanged: (v) =>
                                        unawaited(_toggleService(item.$1, v)),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MagicalGridDelegate extends SliverGridDelegateWithFixedCrossAxisCount {
  const MagicalGridDelegate()
      : super(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.6,
        );
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: StarlitColors.muted2,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
      ),
    );
  }
}

class _RouteOption extends StatelessWidget {
  const _RouteOption({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return StarlitCard(
      highlighted: selected,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: StarlitColors.text,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              color: StarlitColors.muted,
              fontSize: 13,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}
