import 'dart:async';

import 'package:starlit_connect/common/common.dart';
import 'package:starlit_connect/enum/enum.dart';
import 'package:starlit_connect/engine/provider.dart';
import 'package:starlit_connect/providers/providers.dart';
import 'package:starlit_connect/state.dart';
import 'package:starlit_connect/starlit/appearance_dialog.dart';
import 'package:starlit_connect/starlit/brand.dart';
import 'package:starlit_connect/starlit/key_dialog.dart';
import 'package:starlit_connect/starlit/l10n.dart';
import 'package:starlit_connect/starlit/ping_settings_dialog.dart';
import 'package:starlit_connect/starlit/scroll.dart';
import 'package:starlit_connect/starlit/session.dart';
import 'package:starlit_connect/starlit/status_api.dart';
import 'package:starlit_connect/starlit/theme.dart';
import 'package:starlit_connect/starlit/tools_page.dart' deferred as tools;
import 'package:starlit_connect/starlit/ui_icons.dart';
import 'package:starlit_connect/starlit/widgets.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// App settings (formerly Profile).
class StarlitSettingsPage extends ConsumerStatefulWidget {
  const StarlitSettingsPage({super.key});

  @override
  ConsumerState<StarlitSettingsPage> createState() =>
      _StarlitSettingsPageState();
}

class _StarlitSettingsPageState extends ConsumerState<StarlitSettingsPage> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => page,
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  Future<void> _openTools(BuildContext context) async {
    await tools.loadLibrary();
    if (!context.mounted) return;
    _push(context, tools.StarlitToolsPage());
  }

  Future<void> _checkGitHubUpdate(WidgetRef ref) async {
    if (ref.read(loadingProvider(LoadingTag.checkUpdate))) return;
    final commonAction = ref.read(commonActionProvider.notifier);
    final result = await globalState.loadingRun(
      () async => (release: await request.checkForUpdate()),
      title: StarlitL10n.t(ru: 'Проверка обновлений', en: 'Checking for updates'),
      tag: LoadingTag.checkUpdate,
    );
    if (result == null) return;
    unawaited(
      commonAction.checkUpdateResultHandle(data: result.release, isUser: true),
    );
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final ok = await StarlitSession.confirm(
      context,
      title: StarlitL10n.of(context, ru: 'Выйти из аккаунта', en: 'Sign out'),
      message: StarlitL10n.of(
        context,
        ru: 'Подписка будет удалена из приложения, VPN отключится. '
            'Чтобы снова пользоваться сервисом, войдите заново.',
        en: 'The subscription will be removed and VPN will disconnect. '
            'Sign in again to keep using the service.',
      ),
      confirmText: StarlitL10n.of(context, ru: 'Выйти', en: 'Sign out'),
    );
    if (!ok) return;
    await StarlitSession.clearSubscriptions(ref);
  }

  Future<void> _replaceKey(BuildContext context, WidgetRef ref) async {
    final link = await showStarlitKeyDialog(
      context,
      source: StarlitAuthSource.manual,
    );
    if (link == null) return;
    await StarlitSession.clearSubscriptions(ref);
    await ref.read(starlitEngineProvider).importSubscription(link);
  }

  Future<void> _showServers(BuildContext context) async {
    List<StarlitPublicNode> nodes = const [];
    try {
      nodes = await StarlitStatusApi.fetchNodes();
    } catch (_) {}
    if (!context.mounted) return;
    await Navigator.of(context).push<void>(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: const Color(0x99000000),
        pageBuilder: (ctx, _, _) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440, maxHeight: 560),
              child: StarlitCard(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            StarlitL10n.of(
                              context,
                              ru: 'Статус серверов',
                              en: 'Server status',
                            ),
                            style: starlitText(
                              size: 18,
                              weight: FontWeight.w800,
                              display: true,
                            ),
                          ),
                        ),
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () => Navigator.of(ctx).pop(),
                            child: Text(
                              '✕',
                              style: starlitText(
                                size: 18,
                                color: StarlitColors.muted,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: nodes.isEmpty
                          ? Center(
                              child: Text(
                                StarlitL10n.of(
                                  context,
                                  ru: 'Нет данных',
                                  en: 'No data',
                                ),
                                style: starlitText(color: StarlitColors.muted),
                              ),
                            )
                          : ListView.builder(
                              itemCount: nodes.length,
                              itemBuilder: (_, i) {
                                final n = nodes[i];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    children: [
                                      Text(
                                        n.country,
                                        style: starlitText(
                                          size: 13,
                                          weight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          n.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: starlitText(
                                            size: 13,
                                            color: StarlitColors.muted,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        n.state,
                                        style: starlitText(
                                          size: 12,
                                          weight: FontWeight.w600,
                                          color: n.state == 'up'
                                              ? StarlitColors.success
                                              : StarlitColors.warn,
                                        ),
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
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final version = globalState.packageInfo.version;
    final launch = ref.watch(appSettingProvider.select((s) => s.autoLaunch));
    final hasSub = ref.watch(starlitEngineProvider.select((e) => e.hasSession));

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 28, 0, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 28),
            child: StarlitSectionTitle(
              StarlitL10n.of(context, ru: 'Настройки', en: 'Settings'),
              subtitle: StarlitL10n.of(
                context,
                ru: 'Внешний вид, аккаунт и помощь в стиле Starlit.',
                en: 'Appearance, account and help — Starlit style.',
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
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
                StarlitCard(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                  child: Row(
                    children: [
                      const StarlitLogo(size: 64),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const StarlitText(
                              'StarlitConnect',
                              size: 20,
                              weight: FontWeight.w800,
                              display: true,
                            ),
                            const SizedBox(height: 4),
                            StarlitText(
                              hasSub
                                  ? StarlitL10n.of(
                                      context,
                                      ru: 'Аккаунт привязан · $version',
                                      en: 'Account linked · $version',
                                    )
                                  : StarlitL10n.of(
                                      context,
                                      ru: 'Гость · $version',
                                      en: 'Guest · $version',
                                    ),
                              size: 13,
                              color: StarlitColors.muted,
                            ),
                          ],
                        ),
                      ),
                      Text(
                        hasSub
                            ? StarlitL10n.of(
                                context,
                                ru: 'онлайн',
                                en: 'online',
                              )
                            : StarlitL10n.of(
                                context,
                                ru: 'гость',
                                en: 'guest',
                              ),
                        style: starlitText(
                          size: 12,
                          weight: FontWeight.w700,
                          color: hasSub
                              ? StarlitColors.success
                              : StarlitColors.muted2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _GroupLabel(
                  StarlitL10n.of(context, ru: 'Внешний вид', en: 'Appearance'),
                ),
                StarlitCard(
                  padding: EdgeInsets.zero,
                  child: _RowNav(
                    icon: 'palette',
                    title: StarlitL10n.of(
                      context,
                      ru: 'Оформление',
                      en: 'Appearance',
                    ),
                    subtitle: StarlitL10n.of(
                      context,
                      ru: 'Цвет, звук подключения, плавность',
                      en: 'Color, connect sound, smoothness',
                    ),
                    onTap: () => unawaited(showStarlitAppearance(context)),
                  ),
                ),
                const SizedBox(height: 16),
                _GroupLabel(
                  StarlitL10n.of(context, ru: 'Система', en: 'System'),
                ),
                StarlitCard(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    children: [
                      _RowToggle(
                        icon: 'monitor',
                        title: StarlitL10n.of(
                          context,
                          ru: 'Запуск вместе с Windows',
                          en: 'Launch with Windows',
                        ),
                        subtitle: StarlitL10n.of(
                          context,
                          ru: '$appName откроется в трее при входе',
                          en: '$appName opens in the tray at login',
                        ),
                        value: launch,
                        onChanged: (v) => ref
                            .read(appSettingProvider.notifier)
                            .update((s) => s.copyWith(autoLaunch: v)),
                      ),
                      const _Divider(),
                      _RowNav(
                        icon: 'settings-2',
                        title: StarlitL10n.of(
                          context,
                          ru: 'Инструменты',
                          en: 'Tools',
                        ),
                        subtitle: StarlitL10n.of(
                          context,
                          ru: 'Язык и дополнительные опции',
                          en: 'Language and extra options',
                        ),
                        onTap: () => unawaited(_openTools(context)),
                      ),
                      const _Divider(),
                      _RowNav(
                        icon: 'zap',
                        title: StarlitL10n.of(
                          context,
                          ru: 'Пинг',
                          en: 'Ping',
                        ),
                        subtitle: StarlitL10n.of(
                          context,
                          ru: 'Тип, параллельность, автопинг',
                          en: 'Type, concurrency, auto-ping',
                        ),
                        onTap: () => unawaited(showStarlitPingSettings(context)),
                      ),
                      const _Divider(),
                      _RowNav(
                        icon: 'activity',
                        title: StarlitL10n.of(
                          context,
                          ru: 'Статус серверов',
                          en: 'Server status',
                        ),
                        subtitle: StarlitL10n.of(
                          context,
                          ru: 'онлайн-узлы Starlit',
                          en: 'Starlit online nodes',
                        ),
                        trailing: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: StarlitColors.success,
                          ),
                        ),
                        onTap: () => unawaited(_showServers(context)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _GroupLabel(
                  StarlitL10n.of(context, ru: 'Аккаунт', en: 'Account'),
                ),
                StarlitCard(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    children: [
                      _RowNav(
                        icon: 'key-round',
                        title: StarlitL10n.of(
                          context,
                          ru: 'Сменить ключ подписки',
                          en: 'Change subscription key',
                        ),
                        subtitle: StarlitL10n.of(
                          context,
                          ru: 'Вставьте новую ссылку с sub.starlit-moon.ru',
                          en: 'Paste a new link from sub.starlit-moon.ru',
                        ),
                        onTap: () => unawaited(_replaceKey(context, ref)),
                      ),
                      const _Divider(),
                      _RowNav(
                        icon: 'trash-2',
                        title: StarlitL10n.of(
                          context,
                          ru: 'Выйти из аккаунта',
                          en: 'Sign out',
                        ),
                        subtitle: StarlitL10n.of(
                          context,
                          ru: 'Удалить подписку из приложения',
                          en: 'Remove the subscription from the app',
                        ),
                        tint: StarlitColors.danger,
                        onTap: () => unawaited(_logout(context, ref)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _GroupLabel(StarlitL10n.of(context, ru: 'Ещё', en: 'More')),
                StarlitCard(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    children: [
                      _RowNav(
                        icon: 'bot',
                        title: StarlitL10n.of(
                          context,
                          ru: 'Поддержка',
                          en: 'Support',
                        ),
                        subtitle: '@starlitvpnbot',
                        onTap: () => unawaited(
                          launchUrl(
                            Uri.parse(supportUrl),
                            mode: LaunchMode.externalApplication,
                          ),
                        ),
                      ),
                      const _Divider(),
                      _RowNav(
                        icon: 'download',
                        title: StarlitL10n.of(
                          context,
                          ru: 'Проверить обновления',
                          en: 'Check for updates',
                        ),
                        subtitle: 'GitHub · $repository',
                        onTap: () => unawaited(_checkGitHubUpdate(ref)),
                      ),
                      const _Divider(),
                      _RowNav(
                        icon: 'circle-help',
                        title: StarlitL10n.of(
                          context,
                          ru: 'О приложении',
                          en: 'About',
                        ),
                        subtitle: 'StarlitConnect · $version',
                        onTap: () {},
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6, bottom: 8),
      child: Text(
        text,
        style: starlitText(
          size: 13,
          weight: FontWeight.w700,
          color: StarlitColors.muted,
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 14),
      color: StarlitColors.stroke.withValues(alpha: 0.55),
    );
  }
}

class _RowNav extends StatelessWidget {
  const _RowNav({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailing,
    this.tint,
  });

  final String icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Color? tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = tint ?? StarlitColors.text;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              StarlitUi.box(icon, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: starlitText(
                        size: 15,
                        weight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: starlitText(
                          color: StarlitColors.muted2,
                          size: 12,
                        ),
                      ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                trailing!,
                const SizedBox(width: 8),
              ],
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

class _RowToggle extends StatelessWidget {
  const _RowToggle({
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          StarlitUi.box(icon, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: starlitText(size: 15, weight: FontWeight.w600),
                ),
                Text(
                  subtitle,
                  style: starlitText(color: StarlitColors.muted2, size: 12),
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
