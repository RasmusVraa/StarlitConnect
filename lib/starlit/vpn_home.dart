import 'dart:async';

import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/starlit/prefs.dart';
import 'package:fl_clash/starlit/theme.dart';
import 'package:fl_clash/starlit/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StarlitVpnHome extends ConsumerStatefulWidget {
  const StarlitVpnHome({super.key});

  @override
  ConsumerState<StarlitVpnHome> createState() => _StarlitVpnHomeState();
}

class _StarlitVpnHomeState extends ConsumerState<StarlitVpnHome> {
  var _autopilot = true;
  var _bypass = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadPrefs());
  }

  Future<void> _loadPrefs() async {
    final a = await StarlitPrefs.autopilot();
    final b = await StarlitPrefs.bypass();
    if (!mounted) return;
    setState(() {
      _autopilot = a;
      _bypass = b;
    });
  }

  Group? _selectorGroup(List<Group> groups) {
    for (final g in groups) {
      if (g.type == GroupType.Selector || g.type == GroupType.URLTest) {
        return g;
      }
    }
    return groups.isEmpty ? null : groups.first;
  }

  @override
  Widget build(BuildContext context) {
    final running = ref.watch(isStartProvider);
    final groups = ref.watch(currentGroupsStateProvider).value;
    final delayMap = ref.watch(delayDataSourceProvider);
    final group = _selectorGroup(groups);
    final selected = group?.now;
    final proxies = group?.all ?? const <Proxy>[];

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.only(right: 360),
            child: StarlitMapBackdrop(connected: running),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(36, 36, 24, 36),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: StarlitColors.card.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(StarlitRadii.pill),
                        border: Border.all(color: StarlitColors.stroke),
                      ),
                      child: Text(
                        running ? 'Активно' : 'Первое касание',
                        style: const TextStyle(
                          color: StarlitColors.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      running ? 'Подключено' : 'Не подключено',
                      style: const TextStyle(
                        color: StarlitColors.text,
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      running
                          ? (selected ?? 'сервер выбран')
                          : 'Нажмите кнопку справа, чтобы включить Starlit',
                      style: const TextStyle(
                        color: StarlitColors.muted,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: 360,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 24, 24, 24),
                child: StarlitCard(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Подключение',
                        style: TextStyle(
                          color: StarlitColors.muted,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: _ConnectOrb(
                          running: running,
                          onTap: () => ref
                              .read(commonActionProvider.notifier)
                              .toggleRunning(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (selected != null)
                        Text(
                          selected,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: StarlitColors.text,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      const SizedBox(height: 16),
                      const Text(
                        'Серверы по отклику',
                        style: TextStyle(
                          color: StarlitColors.muted2,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: proxies.isEmpty
                            ? const Center(
                                child: Text(
                                  'Добавьте подписку — здесь появятся страны',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: StarlitColors.muted,
                                    fontSize: 13,
                                  ),
                                ),
                              )
                            : ListView.separated(
                                itemCount: proxies.length.clamp(0, 12),
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (_, i) {
                                  final proxy = proxies[i];
                                  final byUrl = delayMap[proxy.name];
                                  final delay =
                                      byUrl?[group?.testUrl ?? ''] ??
                                      byUrl?.values.whereType<int>().firstOrNull;
                                  final active = proxy.name == selected;
                                  return _ServerTile(
                                    name: proxy.name,
                                    delay: delay,
                                    active: active,
                                    onTap: group == null
                                        ? null
                                        : () => ref
                                              .read(
                                                proxiesActionProvider.notifier,
                                              )
                                              .changeProxyDebounce(
                                                group.name,
                                                proxy.name,
                                              ),
                                  );
                                },
                              ),
                      ),
                      const SizedBox(height: 8),
                      _MiniSwitchRow(
                        title: 'Автопилот',
                        subtitle: 'переключит, если страна упала',
                        value: _autopilot,
                        onChanged: (v) {
                          setState(() => _autopilot = v);
                          unawaited(StarlitPrefs.setAutopilot(v));
                        },
                      ),
                      _MiniSwitchRow(
                        title: 'Обход БС',
                        subtitle: 'когда режут белыми списками',
                        value: _bypass,
                        onChanged: (v) {
                          setState(() => _bypass = v);
                          unawaited(StarlitPrefs.setBypass(v));
                        },
                      ),
                      Consumer(
                        builder: (_, ref, _) {
                          final tun = ref.watch(
                            patchClashConfigProvider.select(
                              (s) => s.tun.enable,
                            ),
                          );
                          return _MiniSwitchRow(
                            title: 'Режим TUN',
                            subtitle: 'весь ПК: игры, Discord, программы',
                            value: tun,
                            onChanged: (_) => ref
                                .read(systemActionProvider.notifier)
                                .updateTun(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ConnectOrb extends StatelessWidget {
  const _ConnectOrb({required this.running, required this.onTap});

  final bool running;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          width: 108,
          height: 108,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: running
                  ? const [StarlitColors.accent, StarlitColors.accentDeep]
                  : const [Color(0xFF2A3548), Color(0xFF1A2333)],
            ),
            boxShadow: [
              BoxShadow(
                color: (running ? StarlitColors.accent : StarlitColors.stroke)
                    .withValues(alpha: 0.4),
                blurRadius: 28,
              ),
            ],
            border: Border.all(
              color: running
                  ? StarlitColors.accent.withValues(alpha: 0.7)
                  : StarlitColors.stroke,
              width: 2,
            ),
          ),
          child: Center(
            child: StarlitMoonMark(size: 42, muted: !running),
          ),
        ),
      ),
    );
  }
}

class _ServerTile extends StatelessWidget {
  const _ServerTile({
    required this.name,
    required this.delay,
    required this.active,
    required this.onTap,
  });

  final String name;
  final int? delay;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return StarlitCard(
      highlighted: active,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: StarlitColors.text,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
          if (delay != null && delay! > 0)
            Text(
              '$delay мс',
              style: TextStyle(
                color: delay! < 120
                    ? StarlitColors.success
                    : StarlitColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}

class _MiniSwitchRow extends StatelessWidget {
  const _MiniSwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: StarlitColors.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: StarlitColors.muted2,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          StarlitToggle(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
