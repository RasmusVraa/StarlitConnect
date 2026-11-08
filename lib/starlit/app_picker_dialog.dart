import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:starlit_connect/starlit/l10n.dart';
import 'package:starlit_connect/starlit/popup.dart';
import 'package:starlit_connect/starlit/running_apps.dart';
import 'package:starlit_connect/starlit/scroll.dart';
import 'package:starlit_connect/starlit/theme.dart';
import 'package:starlit_connect/starlit/ui_icons.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;

Future<String?> showStarlitAppPicker(BuildContext context) {
  return showStarlitPopup<String>(
    context,
    builder: (_) => const _AppPickerBody(),
  );
}

class _AppPickerBody extends StatefulWidget {
  const _AppPickerBody();

  @override
  State<_AppPickerBody> createState() => _AppPickerBodyState();
}

class _AppPickerBodyState extends State<_AppPickerBody> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  final _scroll = ScrollController();
  var _loading = true;
  var _apps = const <StarlitRunningApp>[];

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    unawaited(_load());
  }

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final apps = await StarlitRunningApps.list();
    if (!mounted) return;
    setState(() {
      _apps = apps;
      _loading = false;
    });
  }

  Future<void> _browse() async {
    final file = await FilePicker.pickFile(
      dialogTitle: StarlitL10n.of(
        context,
        ru: 'Выберите исполняемый файл',
        en: 'Select an executable',
      ),
      type: FileType.custom,
      allowedExtensions: const ['exe'],
    );
    if (!mounted || file == null) return;
    final path = file.path;
    if (path == null || path.isEmpty) return;
    Navigator.of(context).pop(path);
  }

  void _pick(StarlitRunningApp app) {
    final value = app.path.isNotEmpty ? app.path : app.name;
    Navigator.of(context).pop(value);
  }

  List<StarlitRunningApp> get _filtered {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return _apps;
    return [
      for (final a in _apps)
        if (a.name.toLowerCase().contains(q) ||
            a.path.toLowerCase().contains(q))
          a,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return StarlitPopupFrame(
      title: StarlitL10n.of(
        context,
        ru: 'Выберите приложение',
        en: 'Select an application',
      ),
      width: 520,
      maxHeight: 620,
      child: SizedBox(
        height: 520,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SearchField(
              controller: _search,
              focus: _searchFocus,
              placeholder: StarlitL10n.of(
                context,
                ru: 'Поиск по имени или пути…',
                en: 'Search by name or path…',
              ),
            ),
            const SizedBox(height: 12),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => unawaited(_browse()),
                child: Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: StarlitColors.field,
                    border: Border.all(color: StarlitColors.stroke),
                  ),
                  child: Row(
                    children: [
                      StarlitUi.icon(
                        'external-link',
                        size: 16,
                        color: StarlitColors.accent,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          StarlitL10n.of(
                            context,
                            ru: 'Указать путь к .exe…',
                            en: 'Browse for .exe…',
                          ),
                          style: starlitText(
                            size: 13,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
                      StarlitUi.icon(
                        'chevron-right',
                        size: 14,
                        color: StarlitColors.muted2,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              StarlitL10n.of(
                context,
                ru: 'Активные приложения',
                en: 'Running applications',
              ),
              style: starlitText(
                size: 12,
                weight: FontWeight.w700,
                color: StarlitColors.muted,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: _Spinner(),
                      ),
                    )
                  : filtered.isEmpty
                      ? Center(
                          child: Text(
                            StarlitL10n.of(
                              context,
                              ru: 'Ничего не найдено',
                              en: 'Nothing found',
                            ),
                            style: starlitText(
                              size: 13,
                              color: StarlitColors.muted2,
                            ),
                          ),
                        )
                      : StarlitScrollbar(
                          controller: _scroll,
                          contentRight: 8,
                          child: ListView.separated(
                            controller: _scroll,
                            primary: false,
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) => Container(
                              height: 1,
                              color: StarlitColors.stroke.withValues(
                                alpha: 0.45,
                              ),
                            ),
                            itemBuilder: (context, i) {
                              final app = filtered[i];
                              return _AppRow(
                                app: app,
                                onTap: () => _pick(app),
                              );
                            },
                          ),
                        ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).maybePop(),
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: const Color(0x33FFFFFF),
                    ),
                    child: Text(
                      StarlitL10n.of(context, ru: 'Отмена', en: 'Cancel'),
                      style: starlitText(size: 13, weight: FontWeight.w600),
                    ),
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

class _AppRow extends StatelessWidget {
  const _AppRow({required this.app, required this.onTap});

  final StarlitRunningApp app;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = app.name;
    final subtitle = app.path.isEmpty
        ? title
        : (Platform.isWindows ? app.path : p.basename(app.path));
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: StarlitColors.accent.withValues(alpha: 0.12),
                  border: Border.all(
                    color: StarlitColors.accent.withValues(alpha: 0.28),
                  ),
                ),
                child: Text(
                  title.isEmpty ? '?' : title[0].toUpperCase(),
                  style: starlitText(
                    size: 14,
                    weight: FontWeight.w800,
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: starlitText(size: 14, weight: FontWeight.w700),
                    ),
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatefulWidget {
  const _SearchField({
    required this.controller,
    required this.focus,
    required this.placeholder,
  });

  final TextEditingController controller;
  final FocusNode focus;
  final String placeholder;

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
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
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: StarlitColors.field,
          borderRadius: BorderRadius.circular(12),
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
                  ),
                ),
              ),
            Positioned.fill(
              child: EditableText(
                controller: widget.controller,
                focusNode: widget.focus,
                style: starlitText(size: 13),
                cursorColor: StarlitColors.accent,
                backgroundCursorColor: StarlitColors.muted2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Spinner extends StatefulWidget {
  const _Spinner();

  @override
  State<_Spinner> createState() => _SpinnerState();
}

class _SpinnerState extends State<_Spinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _c,
      child: CustomPaint(
        size: const Size(22, 22),
        painter: _ArcPainter(color: StarlitColors.accent),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  _ArcPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    final r = Rect.fromLTWH(1, 1, size.width - 2, size.height - 2);
    canvas.drawArc(r, 0.2, 4.4, false, paint);
  }

  @override
  bool shouldRepaint(covariant _ArcPainter oldDelegate) =>
      oldDelegate.color != color;
}
