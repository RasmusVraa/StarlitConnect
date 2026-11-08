import 'dart:async';

import 'package:starlit_connect/providers/providers.dart';
import 'package:starlit_connect/starlit/popup.dart';
import 'package:starlit_connect/starlit/prefs.dart';
import 'package:starlit_connect/starlit/sound.dart';
import 'package:starlit_connect/starlit/theme.dart';
import 'package:starlit_connect/starlit/ui_icons.dart';
import 'package:starlit_connect/starlit/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> showStarlitAppearance(BuildContext context) {
  return showStarlitPopup<void>(
    context,
    builder: (_) => const _AppearanceBody(),
  );
}

class _AppearanceBody extends ConsumerStatefulWidget {
  const _AppearanceBody();

  @override
  ConsumerState<_AppearanceBody> createState() => _AppearanceBodyState();
}

class _AppearanceBodyState extends ConsumerState<_AppearanceBody> {
  var _accent = 'pink';
  var _soundOn = true;
  var _soundId = 'signal';
  var _smooth = false;
  var _liveGlobe = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final accent = await StarlitPrefs.accentId();
    final soundOn = await StarlitPrefs.soundEnabled();
    final soundId = await StarlitPrefs.soundId();
    final smooth = await StarlitPrefs.smoothMode();
    final live = await StarlitPrefs.liveGlobe();
    if (!mounted) return;
    setState(() {
      _accent = accent;
      _soundOn = soundOn;
      _soundId = soundId;
      _smooth = smooth;
      _liveGlobe = live;
    });
  }

  Future<void> _setAccent(String id) async {
    final accent = starlitAccentById(id);
    setState(() => _accent = id);
    await StarlitPrefs.setAccentId(id);
    ref
        .read(themeSettingProvider.notifier)
        .update((s) => s.copyWith(primaryColor: accent.color.toARGB32()));
    StarlitColors.applyAccent(accent.color, accent.deep);
  }

  @override
  Widget build(BuildContext context) {
    return StarlitPopupFrame(
      title: 'Оформление',
      width: 440,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Group('Цвет'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final a in starlitAccents)
                  _ColorChoice(
                    accent: a,
                    selected: _accent == a.id,
                    onTap: () => unawaited(_setAccent(a.id)),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            const _Group('Звук'),
            const SizedBox(height: 4),
            _ToggleRow(
              icon: 'sparkles',
              title: 'Звук подключения',
              subtitle: 'При подключении и отключении',
              value: _soundOn,
              onChanged: (v) {
                setState(() => _soundOn = v);
                unawaited(StarlitPrefs.setSoundEnabled(v));
                if (v) StarlitSound.preview(_soundId);
              },
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in starlitSoundPacks)
                  _SoundChip(
                    label: s.label,
                    selected: _soundId == s.id,
                    enabled: _soundOn,
                    onTap: () {
                      setState(() => _soundId = s.id);
                      unawaited(StarlitPrefs.setSoundId(s.id));
                      StarlitSound.preview(s.id);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 18),
            const _Group('Плавность'),
            const SizedBox(height: 4),
            _ToggleRow(
              icon: 'activity',
              title: 'Плавный режим',
              subtitle: 'Меньше анимаций для слабых компьютеров',
              value: _smooth,
              onChanged: (v) {
                setState(() => _smooth = v);
                unawaited(StarlitPrefs.setSmoothMode(v));
                StarlitColors.revision.value++;
              },
            ),
            _ToggleRow(
              icon: 'globe',
              title: 'Живой глобус',
              subtitle: 'Дышащие кольца и бегущий по дуге свет',
              value: _liveGlobe,
              onChanged: (v) {
                setState(() => _liveGlobe = v);
                unawaited(StarlitPrefs.setLiveGlobe(v));
                StarlitColors.revision.value++;
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: starlitText(
        size: 11,
        weight: FontWeight.w700,
        color: StarlitColors.muted2,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _ColorChoice extends StatelessWidget {
  const _ColorChoice({
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  final StarlitAccent accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 74,
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [accent.color, accent.deep],
                  ),
                  border: Border.all(
                    color: selected ? StarlitColors.text : const Color(0x22FFFFFF),
                    width: selected ? 2 : 1,
                  ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: accent.color.withValues(alpha: 0.55),
                            blurRadius: 14,
                          ),
                        ]
                      : null,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                accent.label,
                textAlign: TextAlign.center,
                style: starlitText(
                  size: 11,
                  weight: FontWeight.w600,
                  color: selected ? StarlitColors.text : StarlitColors.muted2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String icon;
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
          StarlitUi.box(icon, size: 36),
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
                  style: starlitText(size: 12, color: StarlitColors.muted2),
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

class _SoundChip extends StatelessWidget {
  const _SoundChip({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: enabled ? onTap : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: selected
                  ? StarlitColors.accent.withValues(alpha: 0.14)
                  : StarlitColors.field,
              border: Border.all(
                color: selected ? StarlitColors.accent : StarlitColors.stroke,
              ),
            ),
            child: Text(
              '▶  $label',
              style: starlitText(
                size: 12.5,
                weight: FontWeight.w700,
                height: 1,
                color: selected ? StarlitColors.accent : StarlitColors.text,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
