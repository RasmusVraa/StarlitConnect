import 'dart:async';
import 'dart:io';

import 'package:starlit_connect/engine/provider.dart';
import 'package:starlit_connect/starlit/app_picker_dialog.dart';
import 'package:starlit_connect/starlit/prefs.dart';
import 'package:starlit_connect/starlit/l10n.dart';
import 'package:starlit_connect/starlit/routing.dart';
import 'package:starlit_connect/starlit/scroll.dart';
import 'package:starlit_connect/starlit/theme.dart';
import 'package:starlit_connect/starlit/tun_guard.dart';
import 'package:starlit_connect/starlit/ui_icons.dart';
import 'package:starlit_connect/starlit/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

class StarlitModePage extends ConsumerStatefulWidget {
  const StarlitModePage({super.key});

  @override
  ConsumerState<StarlitModePage> createState() => _StarlitModePageState();
}

class _StarlitModePageState extends ConsumerState<StarlitModePage> {
  var _happ = true;
  var _appRoute = 'off';
  var _sites = <String>[];
  var _programs = <String>[];
  final _siteCtrl = TextEditingController();
  final _siteFocus = FocusNode();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _siteCtrl.dispose();
    _siteFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    await StarlitPrefs.setRouteMode('all');
    await StarlitPrefs.setEnabledServices({});
    // "Proxy only for selected apps" without TUN made browsers keep the home IP.
    var appRoute = await StarlitPrefs.appRouteMode();
    if (appRoute == 'proxy') {
      appRoute = 'off';
      await StarlitPrefs.setAppRouteMode('off');
    }
    final happ = await StarlitPrefs.happRouting();
    final sites = await StarlitPrefs.customSites();
    final programs = await StarlitPrefs.programs();
    if (!mounted) return;
    setState(() {
      _happ = happ;
      _appRoute = appRoute;
      _sites = sites;
      _programs = programs;
    });
    unawaited(StarlitRouting.sync(ref));
  }

  Future<void> _setHapp(bool on) async {
    setState(() => _happ = on);
    await StarlitPrefs.setHappRouting(on);
    _apply();
  }

  Future<void> _setTun(bool on) async {
    await starlitSetTun(context, ref.read(starlitEngineProvider), on);
  }

  void _apply() => unawaited(StarlitRouting.sync(ref));

  Future<void> _addSite() async {
    final host = _siteCtrl.text
        .trim()
        .toLowerCase()
        .replaceFirst(RegExp(r'^https?://'), '')
        .split('/')
        .first
        .trim();
    if (host.isEmpty || _sites.contains(host)) return;
    final next = [..._sites, host];
    setState(() {
      _sites = next;
      _siteCtrl.clear();
    });
    await StarlitPrefs.setCustomSites(next);
    _apply();
  }

  Future<void> _removeSite(String host) async {
    final next = [
      for (final s in _sites)
        if (s != host) s,
    ];
    setState(() => _sites = next);
    await StarlitPrefs.setCustomSites(next);
    _apply();
  }

  Future<void> _setAppRoute(String mode) async {
    setState(() => _appRoute = mode);
    await StarlitPrefs.setAppRouteMode(mode);
    _apply();
  }

  Future<void> _pickProgram() async {
    final picked = await showStarlitAppPicker(context);
    if (picked == null || picked.isEmpty) return;
    await _addProgramValue(picked);
  }

  Future<void> _addProgramValue(String raw) async {
    var value = raw.trim();
    if (value.isEmpty) return;
    if (!value.contains(r'\') &&
        !value.contains('/') &&
        !value.toLowerCase().endsWith('.exe')) {
      value = '$value.exe';
    }
    final key = value.toLowerCase();
    if (_programs.any((e) => e.toLowerCase() == key)) return;
    final next = [..._programs, value];
    setState(() => _programs = next);
    await StarlitPrefs.setPrograms(next);
    _apply();
  }

  Future<void> _removeProgram(String name) async {
    final next = [
      for (final p in _programs)
        if (p != name) p,
    ];
    setState(() => _programs = next);
    await StarlitPrefs.setPrograms(next);
    _apply();
  }

  String _programLabel(String value) {
    if (value.contains(r'\') || value.contains('/')) {
      return p.basename(value);
    }
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final tun = ref.watch(starlitEngineProvider.select((e) => e.tun));

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 20, 0, 16),
      child: StarlitScrollbar(
        controller: _scroll,
        contentRight: 18,
        child: ListView(
          controller: _scroll,
          primary: false,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          children: [
            StarlitSectionTitle(
              StarlitL10n.of(context, ru: 'Режим', en: 'Mode'),
              subtitle: StarlitL10n.of(
                context,
                ru: 'Выберите, что идёт через VPN. Список приложений справа — для режимов «Исключения» и «Только список».',
                en: 'Choose what goes through VPN. The app list is for Exceptions and List only.',
              ),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, c) {
                final wide = c.maxWidth >= 720;
                final w = wide ? (c.maxWidth - 12) / 2 : c.maxWidth;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: w,
                      child: _ToggleCard(
                        icon: 'globe',
                        title: StarlitL10n.of(
                          context,
                          ru: 'Режим TUN',
                          en: 'TUN mode',
                        ),
                        subtitle: tun
                            ? StarlitL10n.of(
                                context,
                                ru: 'Включён — весь компьютер (нужен админ)',
                                en: 'On — whole PC (admin required)',
                              )
                            : StarlitL10n.of(
                                context,
                                ru: 'Выключен — системный прокси Windows',
                                en: 'Off — Windows system proxy',
                              ),
                        value: tun,
                        onChanged: (v) => unawaited(_setTun(v)),
                      ),
                    ),
                    SizedBox(
                      width: w,
                      child: _ToggleCard(
                        icon: 'share-2',
                        title: StarlitL10n.of(
                          context,
                          ru: 'Happ-роутинг',
                          en: 'Happ routing',
                        ),
                        subtitle: _happ
                            ? StarlitL10n.of(
                                context,
                                ru: 'Вкл — geo-правила + блокировка рекламы',
                                en: 'On — geo rules + ad block',
                              )
                            : StarlitL10n.of(
                                context,
                                ru: 'Выкл — простой полный туннель',
                                en: 'Off — simple full tunnel',
                              ),
                        value: _happ,
                        onChanged: (v) => unawaited(_setHapp(v)),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            StarlitCard(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
                    child: Text(
                      StarlitL10n.of(
                        context,
                        ru: 'Маршрутизация приложений',
                        en: 'App routing',
                      ),
                      style: starlitText(size: 15, weight: FontWeight.w700),
                    ),
                  ),
                  LayoutBuilder(
                    builder: (context, c) {
                      final wide = c.maxWidth >= 900;
                      if (!wide) {
                        return Column(
                          children: [
                            _RouteOption(
                              title: StarlitL10n.of(
                                context,
                                ru: 'Весь трафик',
                                en: 'All traffic',
                              ),
                              subtitle: StarlitL10n.of(
                                context,
                                ru: 'Все программы ПК идут через VPN. Список справа не нужен.',
                                en: 'Every app on this PC goes through VPN. The list is unused.',
                              ),
                              selected: _appRoute == 'off',
                              onTap: () => unawaited(_setAppRoute('off')),
                            ),
                            const _ThinLine(),
                            _RouteOption(
                              title: StarlitL10n.of(
                                context,
                                ru: 'Исключения',
                                en: 'Exceptions',
                              ),
                              subtitle: StarlitL10n.of(
                                context,
                                ru: 'VPN для всех, кроме приложений из списка — они идут напрямую.',
                                en: 'VPN for everything except listed apps, which go direct.',
                              ),
                              selected: _appRoute == 'direct',
                              onTap: () => unawaited(_setAppRoute('direct')),
                            ),
                            const _ThinLine(),
                            _RouteOption(
                              title: StarlitL10n.of(
                                context,
                                ru: 'Только список',
                                en: 'List only',
                              ),
                              subtitle: StarlitL10n.of(
                                context,
                                ru: 'Через VPN только приложения из списка. Остальное — напрямую. Лучше с TUN.',
                                en: 'Only listed apps use VPN; the rest go direct. Best with TUN.',
                              ),
                              selected: _appRoute == 'proxy',
                              onTap: () => unawaited(_setAppRoute('proxy')),
                            ),
                          ],
                        );
                      }
                      final w = (c.maxWidth - 16) / 3;
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
                        child: Row(
                          children: [
                            SizedBox(
                              width: w,
                              child: _RouteOption(
                                title: StarlitL10n.of(
                                  context,
                                  ru: 'Весь трафик',
                                  en: 'All traffic',
                                ),
                                subtitle: StarlitL10n.of(
                                  context,
                                  ru: 'Весь ПК через VPN',
                                  en: 'Whole PC via VPN',
                                ),
                                selected: _appRoute == 'off',
                                onTap: () => unawaited(_setAppRoute('off')),
                              ),
                            ),
                            SizedBox(
                              width: w,
                              child: _RouteOption(
                                title: StarlitL10n.of(
                                  context,
                                  ru: 'Исключения',
                                  en: 'Exceptions',
                                ),
                                subtitle: StarlitL10n.of(
                                  context,
                                  ru: 'Список — без VPN',
                                  en: 'Listed apps bypass VPN',
                                ),
                                selected: _appRoute == 'direct',
                                onTap: () =>
                                    unawaited(_setAppRoute('direct')),
                              ),
                            ),
                            SizedBox(
                              width: w,
                              child: _RouteOption(
                                title: StarlitL10n.of(
                                  context,
                                  ru: 'Только список',
                                  en: 'List only',
                                ),
                                subtitle: StarlitL10n.of(
                                  context,
                                  ru: 'VPN лишь для списка · TUN',
                                  en: 'VPN for the list only · TUN',
                                ),
                                selected: _appRoute == 'proxy',
                                onTap: () =>
                                    unawaited(_setAppRoute('proxy')),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, c) {
                final wide = c.maxWidth >= 900;
                final w = wide ? (c.maxWidth - 12) / 2 : c.maxWidth;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: w,
                      child: StarlitCard(
                        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              StarlitL10n.of(
                                context,
                                ru: 'Выбранные приложения',
                                en: 'Selected apps',
                              ),
                              style: starlitText(
                                size: 16,
                                weight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              StarlitL10n.of(
                                context,
                                ru: 'Плюс — активные процессы или путь к .exe',
                                en: 'Plus — running processes or .exe path',
                              ),
                              style: starlitText(
                                size: 13,
                                color: StarlitColors.muted,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 14),
                            if (_programs.isNotEmpty) ...[
                              for (final item in _programs) ...[
                                _ProgramRow(
                                  title: _programLabel(item),
                                  subtitle: item.contains(r'\') ||
                                          item.contains('/')
                                      ? item
                                      : (Platform.isWindows ? item : ''),
                                  onRemove: () =>
                                      unawaited(_removeProgram(item)),
                                ),
                                const SizedBox(height: 8),
                              ],
                            ],
                            MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                onTap: () => unawaited(_pickProgram()),
                                child: Container(
                                  height: 44,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    color: StarlitColors.field,
                                    border: Border.all(
                                      color: StarlitColors.stroke,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 28,
                                        height: 28,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          gradient: LinearGradient(
                                            colors: [
                                              StarlitColors.accent,
                                              StarlitColors.accentDeep,
                                            ],
                                          ),
                                        ),
                                        child: CustomPaint(
                                          size: const Size(28, 28),
                                          painter: _PlusPainter(),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        StarlitL10n.of(
                                          context,
                                          ru: 'Добавить…',
                                          en: 'Add…',
                                        ),
                                        style: starlitText(
                                          size: 14,
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
                      ),
                    ),
                    SizedBox(
                      width: w,
                      child: _ListCard(
                        title: StarlitL10n.of(
                          context,
                          ru: 'Свои сайты',
                          en: 'Custom sites',
                        ),
                        hint: StarlitL10n.of(
                          context,
                          ru: 'Всегда через VPN, включая поддомены.',
                          en: 'Always via VPN, including subdomains.',
                        ),
                        placeholder: StarlitL10n.of(
                          context,
                          ru: 'например, twitch.tv',
                          en: 'e.g. twitch.tv',
                        ),
                        controller: _siteCtrl,
                        focus: _siteFocus,
                        items: _sites,
                        onAdd: () => unawaited(_addSite()),
                        onRemove: (s) => unawaited(_removeSite(s)),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _ToggleCard extends StatelessWidget {
  const _ToggleCard({
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
    return StarlitCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Row(
        children: [
          StarlitUi.box(icon, size: 42),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: starlitText(size: 16, weight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: starlitText(size: 13, color: StarlitColors.muted2),
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

class _ProgramRow extends StatelessWidget {
  const _ProgramRow({
    required this.title,
    required this.subtitle,
    required this.onRemove,
  });

  final String title;
  final String subtitle;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: StarlitColors.field,
        border: Border.all(color: StarlitColors.stroke),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              color: StarlitColors.accent.withValues(alpha: 0.14),
            ),
            child: Text(
              title.isEmpty ? '?' : title[0].toUpperCase(),
              style: starlitText(
                size: 13,
                weight: FontWeight.w800,
                color: StarlitColors.accent,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: starlitText(size: 13, weight: FontWeight.w700),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: starlitText(
                      size: 11,
                      color: StarlitColors.muted2,
                    ),
                  ),
                ],
              ],
            ),
          ),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: onRemove,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: SizedBox(
                  width: 10,
                  height: 10,
                  child: CustomPaint(painter: _CrossPainter()),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ListCard extends StatelessWidget {
  const _ListCard({
    required this.title,
    required this.hint,
    required this.placeholder,
    required this.controller,
    required this.focus,
    required this.items,
    required this.onAdd,
    required this.onRemove,
  });

  final String title;
  final String hint;
  final String placeholder;
  final TextEditingController controller;
  final FocusNode focus;
  final List<String> items;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    return StarlitCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: starlitText(size: 16, weight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            hint,
            style: starlitText(size: 13, color: StarlitColors.muted, height: 1.35),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: _Field(
                  controller: controller,
                  focus: focus,
                  placeholder: placeholder,
                  onSubmit: onAdd,
                ),
              ),
              const SizedBox(width: 10),
              _PlusButton(onTap: onAdd),
            ],
          ),
          if (items.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in items)
                  _Chip(label: item, onRemove: () => onRemove(item)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Field extends StatefulWidget {
  const _Field({
    required this.controller,
    required this.focus,
    required this.placeholder,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final FocusNode focus;
  final String placeholder;
  final VoidCallback onSubmit;

  @override
  State<_Field> createState() => _FieldState();
}

class _FieldState extends State<_Field> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_rebuild);
    widget.focus.addListener(_rebuild);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_rebuild);
    widget.focus.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final focused = widget.focus.hasFocus;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => widget.focus.requestFocus(),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: StarlitColors.field,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: focused ? StarlitColors.accent : StarlitColors.stroke,
          ),
        ),
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            if (widget.controller.text.isEmpty)
              IgnorePointer(
                child: Text(
                  widget.placeholder,
                  style: starlitText(
                    size: 13,
                    color: StarlitColors.muted2,
                    height: 1.2,
                  ),
                ),
              ),
            Positioned.fill(
              child: EditableText(
                controller: widget.controller,
                focusNode: widget.focus,
                style: starlitText(size: 13, height: 1.2),
                cursorColor: StarlitColors.accent,
                backgroundCursorColor: StarlitColors.muted2,
                onSubmitted: (_) => widget.onSubmit(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlusButton extends StatelessWidget {
  const _PlusButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [StarlitColors.accent, StarlitColors.accentDeep],
            ),
            boxShadow: [
              BoxShadow(
                color: StarlitColors.accent.withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: CustomPaint(
            size: const Size(44, 44),
            painter: _PlusPainter(),
          ),
        ),
      ),
    );
  }
}

class _PlusPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final paint = Paint()
      ..color = const Color(0xFF1A1020)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(c.translate(-6, 0), c.translate(6, 0), paint);
    canvas.drawLine(c.translate(0, -6), c.translate(0, 6), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onRemove,
        child: Container(
          height: 32,
          padding: const EdgeInsets.only(left: 12, right: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: StarlitColors.field,
            border: Border.all(color: StarlitColors.stroke),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: starlitText(size: 13, weight: FontWeight.w600, height: 1),
              ),
              const SizedBox(width: 7),
              SizedBox(
                width: 9,
                height: 9,
                child: CustomPaint(painter: _CrossPainter()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CrossPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = StarlitColors.muted
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset.zero, Offset(size.width, size.height), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(0, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: selected
                ? StarlitColors.accent.withValues(alpha: 0.08)
                : const Color(0x00000000),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 22,
                height: 22,
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
                  duration: const Duration(milliseconds: 160),
                  width: selected ? 10 : 0,
                  height: selected ? 10 : 0,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: StarlitColors.accent,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: starlitText(size: 16, weight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: starlitText(
                        size: 13,
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

class _ThinLine extends StatelessWidget {
  const _ThinLine();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: StarlitColors.stroke.withValues(alpha: 0.55),
    );
  }
}
