import 'package:fl_clash/starlit/theme.dart';
import 'package:fl_clash/starlit/widgets.dart';
import 'package:flutter/widgets.dart';

class StarlitWhatsNew extends StatelessWidget {
  const StarlitWhatsNew({
    super.key,
    required this.version,
    required this.onClose,
  });

  final String version;
  final VoidCallback onClose;

  static const _items = [
    'Ночной интерфейс Starlit — свой стиль, не копия чужих клиентов',
    'Карта и быстрый выбор сервера на главном экране',
    'Режимы: умный / весь трафик / выбранные сервисы + TUN',
    'Вход через бот и вставка ключа с sub.starlit-moon.ru',
    'Быстрее старт за счёт лёгкой оболочки поверх ядра',
  ];

  @override
  Widget build(BuildContext context) {
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
                  'Что нового в $version',
                  style: const TextStyle(
                    color: StarlitColors.text,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                for (final item in _items) ...[
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
                        child: const Text('✦', style: TextStyle(fontSize: 12)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item,
                          style: const TextStyle(
                            color: StarlitColors.muted,
                            fontSize: 14,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 8),
                StarlitPrimaryButton(label: 'Отлично', onPressed: onClose),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
