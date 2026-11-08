import 'dart:async';

import 'package:starlit_connect/starlit/l10n.dart';
import 'package:starlit_connect/starlit/popup.dart';
import 'package:starlit_connect/starlit/prefs.dart';
import 'package:starlit_connect/starlit/theme.dart';
import 'package:starlit_connect/starlit/widgets.dart';
import 'package:flutter/widgets.dart';

Future<void> showStarlitPingSettings(BuildContext context) {
  return showStarlitPopup<void>(
    context,
    builder: (_) => const _PingSettingsBody(),
  );
}

class _PingSettingsBody extends StatefulWidget {
  const _PingSettingsBody();

  @override
  State<_PingSettingsBody> createState() => _PingSettingsBodyState();
}

class _PingSettingsBodyState extends State<_PingSettingsBody> {
  var _type = 'tcp';
  var _concurrency = 10;
  var _auto = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final type = await StarlitPrefs.pingType();
    final concurrency = await StarlitPrefs.pingConcurrency();
    final auto = await StarlitPrefs.autoPing();
    if (!mounted) return;
    setState(() {
      _type = type;
      _concurrency = concurrency;
      _auto = auto;
    });
  }

  Future<void> _setType(String type) async {
    setState(() => _type = type);
    await StarlitPrefs.setPingType(type);
  }

  Future<void> _setConcurrency(int value) async {
    final v = value.clamp(1, 32);
    setState(() => _concurrency = v);
    await StarlitPrefs.setPingConcurrency(v);
  }

  Future<void> _setAuto(bool on) async {
    setState(() => _auto = on);
    await StarlitPrefs.setAutoPing(on);
  }

  @override
  Widget build(BuildContext context) {
    return StarlitPopupFrame(
      title: StarlitL10n.of(context, ru: 'Пинг', en: 'Ping'),
      width: 460,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            StarlitL10n.of(context, ru: 'Тип пинга', en: 'Ping type'),
            style: starlitText(size: 13, weight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          _Radio(
            title: 'TCP',
            subtitle: StarlitL10n.of(
              context,
              ru: 'Подключение к порту сервера — самый точный для VPN',
              en: 'Connect to the server port — best for VPN nodes',
            ),
            selected: _type == 'tcp',
            onTap: () => unawaited(_setType('tcp')),
          ),
          _Radio(
            title: 'ICMP',
            subtitle: StarlitL10n.of(
              context,
              ru: 'Системный ping.exe — может не отвечать на части хостов',
              en: 'System ping.exe — some hosts may not reply',
            ),
            selected: _type == 'icmp',
            onTap: () => unawaited(_setType('icmp')),
          ),
          const SizedBox(height: 16),
          Text(
            StarlitL10n.of(
              context,
              ru: 'Серверов в пинге одновременно',
              en: 'Servers pinged at once',
            ),
            style: starlitText(size: 13, weight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _StepButton(
                label: '−',
                onTap: () => unawaited(_setConcurrency(_concurrency - 1)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: StarlitColors.field,
                    border: Border.all(color: StarlitColors.stroke),
                  ),
                  child: Text(
                    '$_concurrency',
                    style: starlitText(size: 16, weight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _StepButton(
                label: '+',
                onTap: () => unawaited(_setConcurrency(_concurrency + 1)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      StarlitL10n.of(
                        context,
                        ru: 'Автопинг при обновлении',
                        en: 'Auto-ping on refresh',
                      ),
                      style: starlitText(size: 14, weight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      StarlitL10n.of(
                        context,
                        ru: 'После обновления подписки и при старте',
                        en: 'After subscription refresh and on start',
                      ),
                      style: starlitText(
                        size: 12,
                        color: StarlitColors.muted2,
                      ),
                    ),
                  ],
                ),
              ),
              StarlitToggle(
                value: _auto,
                onChanged: (v) => unawaited(_setAuto(v)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Radio extends StatelessWidget {
  const _Radio({
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
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 20,
                height: 20,
                margin: const EdgeInsets.only(top: 2),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected
                        ? StarlitColors.accent
                        : StarlitColors.muted2,
                    width: 2,
                  ),
                ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  width: selected ? 9 : 0,
                  height: selected ? 9 : 0,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: StarlitColors.accent,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: starlitText(size: 14, weight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: starlitText(
                        size: 12,
                        color: StarlitColors.muted,
                        height: 1.3,
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

class _StepButton extends StatelessWidget {
  const _StepButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: StarlitColors.field,
            border: Border.all(color: StarlitColors.stroke),
          ),
          child: Text(
            label,
            style: starlitText(size: 18, weight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}
