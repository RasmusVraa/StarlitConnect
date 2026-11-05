# StarlitConnect

Десктоп-клиент [StarlitVPN](https://internet.starlit-moon.ru) на базе [FlClash](https://github.com/chen08209/FlClash) (ClashMeta / mihomo).

- Сайт: https://internet.starlit-moon.ru  
- Кабинет: https://cabinet.starlit-moon.ru  
- Подписки: `https://sub.starlit-moon.ru/...`  
- Поддержка: https://t.me/starlitvpnbot  

## Сборка Windows

Нужны: Flutter 3.47+, Go 1.27+, Rust (rustup), MinGW-w64 GCC, CMake, Ninja, Inno Setup 6.

```powershell
# PATH: Flutter, Go, Rust (cargo), MinGW gcc, CMake, Ninja, Inno Setup, %LOCALAPPDATA%\Pub\Cache\bin
$env:INNO_SETUP_PATH = "$env:LOCALAPPDATA\Programs\Inno Setup 6"  # если Inno не в Program Files (x86)
flutter pub get
dart pub global activate -s git https://github.com/chen08209/flutter_distributor.git --git-ref v0.6.11-flclash.4 --git-path packages/flutter_distributor
dart setup.dart windows
```


Установщик: `dist/StarlitConnect-*-windows-amd64-setup.exe`. Не передавайте `--arch` на Windows — это флаг только для Android.

## Обновления (GitHub Releases)

Репозиторий: https://github.com/RasmusVraa/StarlitConnect  

Приложение само проверяет `releases/latest` и скачивает  
`StarlitConnect-<ver>-windows-amd64-setup.exe` + `SHA256SUMS`, затем ставит через Inno (`/updatefrom=`).

Публикация релиза после сборки:

```powershell
.\scripts\publish-release.ps1
# или: .\scripts\publish-release.ps1 -Tag v1.0.2 -Notes "описание"
```

## Лицензия

GPL-3.0 (как у upstream FlClash).

