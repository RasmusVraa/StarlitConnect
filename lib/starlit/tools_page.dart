import 'package:starlit_connect/common/common.dart';
import 'package:starlit_connect/l10n/l10n.dart';
import 'package:starlit_connect/providers/providers.dart';
import 'package:starlit_connect/state.dart';
import 'package:starlit_connect/starlit/appearance_dialog.dart';
import 'package:starlit_connect/starlit/brand.dart';
import 'package:starlit_connect/starlit/l10n.dart';
import 'package:starlit_connect/starlit/popup.dart';
import 'package:starlit_connect/starlit/theme.dart';
import 'package:starlit_connect/starlit/ui_icons.dart';
import 'package:starlit_connect/starlit/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Starlit tools — language, appearance, about. No FlClash config screens.
class StarlitToolsPage extends ConsumerWidget {
  const StarlitToolsPage({super.key});

  Future<void> _pickLocale(
    BuildContext context,
    WidgetRef ref,
    Locale? currentLocale,
  ) {
    final options = <Locale?>[
      null,
      ...AppLocalizations.delegate.supportedLocales,
    ];
    return showStarlitPopup<void>(
      context,
      builder: (ctx) {
        final l10n = ctx.appLocalizations;
        return StarlitPopupFrame(
          title: l10n.language,
          width: 360,
          maxHeight: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < options.length; i++) ...[
                  if (i > 0)
                    Container(
                      height: 1,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      color: StarlitColors.stroke.withValues(alpha: 0.55),
                    ),
                  _LocaleChoice(
                    label: options[i]?.label ?? l10n.defaultText,
                    selected: _sameLocale(options[i], currentLocale),
                    onTap: () {
                      ref.read(appSettingProvider.notifier).update(
                        (s) => s.copyWith(locale: options[i]?.toString()),
                      );
                      Navigator.of(ctx).maybePop();
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  static bool _sameLocale(Locale? a, Locale? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    return a.toString() == b.toString();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(appSettingProvider.select((s) => s.locale));
    final currentLocale = getLocaleForString(locale);
    final version = globalState.packageInfo.version;

    return StarlitScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
            child: Row(
              children: [
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: StarlitColors.field,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: StarlitColors.stroke),
                      ),
                      child: Text(
                        '←',
                        style: starlitText(
                          size: 18,
                          weight: FontWeight.w700,
                          color: StarlitColors.text,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const StarlitLogo(size: 34),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        StarlitL10n.of(
                          context,
                          ru: 'Инструменты',
                          en: 'Tools',
                        ),
                        style: starlitText(
                          size: 18,
                          weight: FontWeight.w800,
                          display: true,
                        ),
                      ),
                      Text(
                        StarlitL10n.of(
                          context,
                          ru: 'Язык, внешний вид, о приложении',
                          en: 'Language, appearance, about',
                        ),
                        style: starlitText(
                          size: 12,
                          color: StarlitColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
              children: [
                _Group(
                  title: StarlitL10n.of(
                    context,
                    ru: 'Настройки',
                    en: 'Settings',
                  ),
                  children: [
                    _Tile(
                      icon: 'globe',
                      tint: const Color(0xFF7C9CFF),
                      title: context.appLocalizations.language,
                      trailing:
                          currentLocale?.label ??
                          context.appLocalizations.defaultText,
                      onTap: () => _pickLocale(context, ref, currentLocale),
                    ),
                    _Tile(
                      icon: 'palette',
                      tint: const Color(0xFFE891C4),
                      title: context.appLocalizations.theme,
                      onTap: () => showStarlitAppearance(context),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _Group(
                  title: StarlitL10n.of(context, ru: 'О приложении', en: 'About'),
                  children: [
                    _Tile(
                      icon: 'sparkles',
                      tint: StarlitColors.accent,
                      title: appName,
                      trailing: 'v$version',
                      onTap: () {},
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LocaleChoice extends StatelessWidget {
  const _LocaleChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: starlitText(
                    size: 15,
                    weight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? StarlitColors.accent : StarlitColors.text,
                  ),
                ),
              ),
              if (selected)
                StarlitUi.icon(
                  'check',
                  size: 18,
                  color: StarlitColors.accent,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 6, bottom: 8),
          child: Text(
            title,
            style: starlitText(
              size: 13,
              weight: FontWeight.w700,
              color: StarlitColors.muted,
            ),
          ),
        ),
        StarlitCard(
          padding: EdgeInsets.zero,
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.tint,
    required this.title,
    required this.onTap,
    this.trailing,
  });

  final String icon;
  final Color tint;
  final String title;
  final String? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: StarlitUi.icon(icon, size: 16, color: tint),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: starlitText(size: 14, weight: FontWeight.w600),
                ),
              ),
              if (trailing != null)
                Text(
                  trailing!,
                  style: starlitText(size: 12, color: StarlitColors.muted),
                ),
              const SizedBox(width: 6),
              StarlitUi.icon(
                'chevron-right',
                size: 16,
                color: StarlitColors.muted2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
