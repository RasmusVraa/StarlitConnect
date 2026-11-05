import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/starlit/theme.dart';
import 'package:fl_clash/starlit/widgets.dart';
import 'package:fl_clash/views/about.dart';
import 'package:fl_clash/views/theme.dart';
import 'package:fl_clash/views/tools.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

class StarlitProfilePage extends ConsumerWidget {
  const StarlitProfilePage({super.key});

  void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => page,
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  Future<void> _checkGitHubUpdate(WidgetRef ref) async {
    if (ref.read(loadingProvider(LoadingTag.checkUpdate))) return;
    final commonAction = ref.read(commonActionProvider.notifier);
    final result = await globalState.loadingRun(
      () async => (release: await request.checkForUpdate()),
      title: 'Проверка обновлений',
      tag: LoadingTag.checkUpdate,
    );
    if (result == null) return;
    unawaited(
      commonAction.checkUpdateResultHandle(data: result.release, isUser: true),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final version = globalState.packageInfo.version;
    final launch = ref.watch(
      appSettingProvider.select((s) => s.autoLaunch),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const StarlitSectionTitle(
                  'Профиль',
                  subtitle: 'Аккаунт, оформление и помощь.',
                ),
                const Spacer(),
                const Center(child: StarlitMoonMark(size: 96, muted: true)),
                const SizedBox(height: 18),
                const Text(
                  'Кабинет и баланс — на сайте Starlit.\nДрузей можно приглашать из бота.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: StarlitColors.muted,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 22),
                StarlitPrimaryButton(
                  label: 'Открыть Telegram-бот',
                  onPressed: () => unawaited(
                    launchUrl(
                      Uri.parse(supportUrl),
                      mode: LaunchMode.externalApplication,
                    ),
                  ),
                ),
                const Spacer(flex: 2),
                Text(
                  '$appName $version',
                  style: const TextStyle(
                    color: StarlitColors.muted2,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            flex: 6,
            child: ListView(
              children: [
                const _GroupLabel('Оформление'),
                StarlitCard(
                  padding: EdgeInsets.zero,
                  child: _RowNav(
                    title: 'Оформление',
                    subtitle: 'Цвет и плавность (системная тема FlClash)',
                    onTap: () => _push(context, const ThemeView()),
                  ),
                ),
                const SizedBox(height: 16),
                const _GroupLabel('Надёжность'),
                StarlitCard(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    children: [
                      _RowToggle(
                        title: 'Запускать вместе с Windows',
                        subtitle: '$appName откроется в трее при входе',
                        value: launch,
                        onChanged: (v) => ref
                            .read(appSettingProvider.notifier)
                            .update((s) => s.copyWith(autoLaunch: v)),
                      ),
                      const _Divider(),
                      _RowNav(
                        title: 'Не работает?',
                        subtitle: 'Диагностика и расширенные инструменты',
                        onTap: () => _push(context, const ToolsView()),
                      ),
                      const _Divider(),
                      _RowNav(
                        title: 'Статус серверов',
                        subtitle: 'Сайт и кабинет Starlit',
                        trailing: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: StarlitColors.success,
                          ),
                        ),
                        onTap: () => unawaited(
                          launchUrl(
                            Uri.parse(websiteUrl),
                            mode: LaunchMode.externalApplication,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const _GroupLabel('Ещё'),
                StarlitCard(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    children: [
                      _RowNav(
                        title: 'Поддержка',
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
                        title: 'Проверить обновления',
                        subtitle: 'GitHub · $repository',
                        onTap: () => unawaited(_checkGitHubUpdate(ref)),
                      ),
                      const _Divider(),
                      _RowNav(
                        title: 'О приложении',
                        onTap: () => _push(context, const AboutView()),
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

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: StarlitColors.muted2,
          fontSize: 12,
          fontWeight: FontWeight.w700,
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
      margin: const EdgeInsets.only(left: 52),
      color: StarlitColors.stroke.withValues(alpha: 0.7),
    );
  }
}

class _RowNav extends StatelessWidget {
  const _RowNav({
    required this.title,
    this.subtitle,
    required this.onTap,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: StarlitColors.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          color: StarlitColors.muted2,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              trailing ??
                  const Text(
                    '›',
                    style: TextStyle(color: StarlitColors.muted, fontSize: 20),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: StarlitColors.muted2,
                    fontSize: 12,
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
