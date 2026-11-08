import 'package:starlit_connect/starlit/l10n.dart';
import 'package:starlit_connect/starlit/theme.dart';
import 'package:starlit_connect/starlit/widgets.dart';
import 'package:flutter/widgets.dart';

class StarlitWhatsNew extends StatelessWidget {
  const StarlitWhatsNew({
    super.key,
    required this.version,
    required this.onClose,
  });

  final String version;
  final VoidCallback onClose;

  /// Per-version bullets; unknown versions fall back to the latest notes.
  static List<String> itemsFor(String version, {required bool ru}) {
    final notes = _notes[version] ?? _notes.values.last;
    return [for (final n in notes) ru ? n.ru : n.en];
  }

  static const _notes = <String, List<({String ru, String en})>>{
    '1.0.29': [
      (
        ru: 'Выбор языка списком — больше не застревает на китайском',
        en: 'Language picker list — no more getting stuck on Chinese',
      ),
      (
        ru: 'Страницы Starlit следуют выбранному языку (RU/EN)',
        en: 'Starlit pages follow the selected language (RU/EN)',
      ),
      (
        ru: 'TCP-пинг через прокси до Cloudflare',
        en: 'TCP ping through the proxy to Cloudflare',
      ),
    ],
    '1.0.30': [
      (
        ru: 'Пинг считает полный TLS-handshake — без ложных «1 мс»',
        en: 'Ping measures a full TLS handshake — no fake “1 ms”',
      ),
      (
        ru: 'Экраны из «Инструментов» на звёздном фоне Starlit',
        en: 'Tools screens use the Starlit starfield',
      ),
      (
        ru: 'Окно «Что нового» показывает заметки этой версии',
        en: 'What’s new shows notes for this version',
      ),
    ],
    '1.0.31': [
      (
        ru: 'Пинг снова через Cloudflare HTTP — VLESS и HY2',
        en: 'Ping uses Cloudflare HTTP again — VLESS and HY2',
      ),
      (
        ru: 'Таймаут пинга 8 с; URL из подписки больше не перебивает тест',
        en: '8s ping timeout; subscription test URL no longer overrides',
      ),
    ],
    '1.0.32': [
      (
        ru: 'Пинг больше не перезагружает Core на каждый клик',
        en: 'Ping no longer reloads the Core on every click',
      ),
      (
        ru: 'VLESS xhttp: пробы по 5 нод, без гонки с apply',
        en: 'VLESS xhttp: probes in batches of 5, no race with apply',
      ),
    ],
    '1.0.33': [
      (
        ru: 'Пинг = TCP до домена:порта самой ноды (не HTTP через туннель)',
        en: 'Ping = TCP to the node’s own host:port (not HTTP through the tunnel)',
      ),
    ],
    '1.0.34': [
      (
        ru: 'Серверы «АВТО» скрыты из списка',
        en: 'AUTO servers are hidden from the list',
      ),
      (
        ru: 'HY2: пинг через туннель (UDP-порт нельзя прощупать TCP)',
        en: 'HY2: tunnel probe (UDP ports cannot be TCP-pinged)',
      ),
    ],
    '1.0.35': [
      (
        ru: 'Ядро Xray вместо Clash Meta — клиент самостоятельный',
        en: 'Xray core replaces Clash Meta — standalone client',
      ),
      (
        ru: 'Подписка Remnawave как Xray JSON; пинг TCP / HY2 UDP',
        en: 'Remnawave subscription as Xray JSON; TCP / HY2 UDP ping',
      ),
      (
        ru: 'Инструменты без экранов FlClash',
        en: 'Tools without FlClash screens',
      ),
    ],
    '1.0.36': [
      (
        ru: 'Happ-роутинг (geosite RU/банки) с выключателем в «Режим»',
        en: 'Happ routing (geosite RU/banks) with a Mode-page toggle',
      ),
      (
        ru: 'Страны подписки светлее на карте; снова лайв-скорость',
        en: 'Subscription countries glow on the map; live speed is back',
      ),
      (
        ru: 'Срок подписки >2к дней больше не «истекла»; вкладка «Настройки»',
        en: 'Long subscriptions no longer show as expired; Settings tab',
      ),
    ],
    '1.0.37': [
      (
        ru: 'Плавный скролл и полоса справа; срок подписки из кабинета',
        en: 'Smoother scrolling; subscription term from the cabinet',
      ),
      (
        ru: 'Программы как в Happ: активные процессы + путь к .exe',
        en: 'Apps like Happ: running processes + browse for .exe',
      ),
      (
        ru: 'Настройки пинга; реальный город на карте и км до серверов',
        en: 'Ping settings; real city on the map and km to servers',
      ),
    ],
    '1.0.38': [
      (
        ru: 'Режим на всю ширину — без узких столбцов',
        en: 'Mode page fills the width — no narrow columns',
      ),
      (
        ru: 'Боковая панель со статусом, орбитой и версией',
        en: 'Sidebar with status, orbit mark and version',
      ),
    ],
    '1.0.39': [
      (
        ru: 'Навигация — спутники на орбите вокруг глобуса',
        en: 'Navigation — satellites on an orbit around the globe',
      ),
    ],
    '1.0.40': [
      (
        ru: 'Планета всегда на фоне; порядок спутников сверху вниз',
        en: 'Planet always in the background; satellites top to bottom',
      ),
      (
        ru: 'Плавный скролл колесом — без деревянных рывков',
        en: 'Smooth mouse-wheel scrolling — no wooden stutter',
      ),
    ],
    '1.0.41': [
      (
        ru: 'Снова подключается: geo-файлы Happ больше не затираются',
        en: 'Connects again: Happ geo files are no longer overwritten',
      ),
      (
        ru: 'Живая скорость ↑↓ после успешного старта Xray',
        en: 'Live ↑↓ speed after Xray starts successfully',
      ),
      (
        ru: 'Полоска расхода трафика подписки на главном экране',
        en: 'Subscription traffic usage bar on the home screen',
      ),
    ],
    '1.0.42': [
      (
        ru: 'Убраны соглашение FlClash и ошибочный старт mihomo-ядра',
        en: 'Removed the FlClash disclaimer and broken mihomo core start',
      ),
      (
        ru: 'При выходе сбрасывается системный прокси — Happ больше не «ломается»',
        en: 'Exit clears the system proxy — Happ no longer breaks afterward',
      ),
      (
        ru: 'TUN: autoRoute + gvisor; без системного прокси поверх туннеля',
        en: 'TUN: autoRoute + gvisor; no system proxy stacked on the tunnel',
      ),
    ],
    '1.1.6': [
      (
        ru: 'Флаги на карте: у Турции полумесяц со звездой, у Албании орёл',
        en: 'Map flags: Turkey gets crescent and star, Albania the eagle',
      ),
    ],
    '1.1.5': [
      (
        ru: 'Список серверов по умолчанию в порядке подписки, не по пингу',
        en: 'Server list defaults to subscription order, not ping',
      ),
      (
        ru: 'Понятнее заливка флагов: Япония, Турция, Албания, Беларусь, Латвия',
        en: 'Clearer flag fills: Japan, Turkey, Albania, Belarus, Latvia',
      ),
      (
        ru: 'На главной при включении TUN — то же предупреждение про Zapret и права администратора',
        en: 'Home TUN toggle shows the same Zapret and administrator warnings',
      ),
    ],
    '1.1.4': [
      (
        ru: 'Понятнее описания режимов маршрутизации приложений',
        en: 'Clearer app-routing mode descriptions',
      ),
      (
        ru: 'В кабинете устройств показывается реальная ОС (Windows 11 определяется по build)',
        en: 'Device card shows the real OS (Windows 11 detected by build)',
      ),
    ],
    '1.1.3': [
      (
        ru: 'Автопилот больше не выбирает серверы БС / LTE',
        en: 'Autopilot no longer picks whitelist / LTE servers',
      ),
      (
        ru: 'Hysteria2: правильный формат outbound для Xray 26+',
        en: 'Hysteria2: correct outbound shape for Xray 26+',
      ),
      (
        ru: 'TUN: актуальный inbound Xray + проверка прав администратора',
        en: 'TUN: current Xray inbound + administrator check',
      ),
    ],
    '1.1.2': [
      (
        ru: 'Починена кодировка русских строк на экране режима',
        en: 'Fixed mojibake in Russian strings on the Mode screen',
      ),
      (
        ru: 'Флаги на карте: крест для скандинавских стран, вертикальные полосы где нужно',
        en: 'Map flags: Nordic cross and vertical stripes where they belong',
      ),
      (
        ru: 'Подпись города на карте больше не переносится посередине слова',
        en: 'City label on the map no longer wraps mid-word',
      ),
    ],
    '1.1.1': [
      (
        ru: 'Страна на карте заливается цветами флага; карточка закреплена в углу',
        en: 'Connected country fills with flag colours; info card pinned in the corner',
      ),
      (
        ru: 'Русские названия и факты почти для всех стран на глобусе',
        en: 'Russian names and facts for nearly every country on the globe',
      ),
      (
        ru: 'Убраны режимы и сервисы — только полный VPN и маршрутизация приложений',
        en: 'Modes and services removed — full VPN plus app routing only',
      ),
      (
        ru: 'Весь трафик снова идёт через сервер (умный RU-direct больше не «съедает» IP)',
        en: 'All traffic goes via the server again (smart RU-direct no longer eats your exit IP)',
      ),
    ],
    '1.1.0': [
      (
        ru: 'Стабильный Xray-клиент без FlClash-ядра и экрана соглашения',
        en: 'Stable Xray client without the FlClash core and disclaimer screen',
      ),
      (
        ru: 'Корректный выход: прокси сбрасывается, Happ и интернет не ломаются',
        en: 'Clean exit: proxy is cleared so Happ and the internet keep working',
      ),
      (
        ru: 'Предупреждение, если включить TUN при запущенном Zapret (Flowseal)',
        en: 'Warning when enabling TUN while Zapret (Flowseal) is running',
      ),
      (
        ru: 'Полоска трафика подписки и живая скорость на главном экране',
        en: 'Subscription traffic bar and live speed on the home screen',
      ),
    ],
  };

  @override
  Widget build(BuildContext context) {
    final ru = StarlitL10n.isRu(context);
    final items = itemsFor(version, ru: ru);
    return ColoredBox(
      color: const Color(0xCC060912),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: StarlitCard(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  StarlitL10n.of(
                    context,
                    ru: 'Что нового в $version',
                    en: 'What’s new in $version',
                  ),
                  style: starlitText(
                    size: 22,
                    weight: FontWeight.w800,
                    display: true,
                  ),
                ),
                const SizedBox(height: 16),
                for (final item in items) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: StarlitColors.cardHi,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: StarlitColors.stroke),
                        ),
                        child: Text(
                          '✦',
                          style: starlitText(size: 12),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item,
                          style: starlitText(
                            size: 14,
                            color: StarlitColors.muted,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 8),
                StarlitPrimaryButton(
                  label: StarlitL10n.of(
                    context,
                    ru: 'Отлично',
                    en: 'Got it',
                  ),
                  onPressed: onClose,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
