import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:starlit_connect/starlit/prefs.dart';
import 'package:path/path.dart' as p;

typedef StarlitSoundPack = ({String id, String label, String on, String off});

const starlitSoundPacks = <StarlitSoundPack>[
  (id: 'signal', label: 'Сигнал', on: 'gac_connect.wav', off: 'gac_off.wav'),
  (
    id: 'crystal',
    label: 'Кристалл',
    on: 'gac_connect_kristall.wav',
    off: 'gac_off_kristall.wav',
  ),
  (
    id: 'sphere',
    label: 'Сфера',
    on: 'gac_connect_sfera.wav',
    off: 'gac_off_sfera.wav',
  ),
  (
    id: 'chime',
    label: 'Звон',
    on: 'gac_connect_zvon.wav',
    off: 'gac_off_zvon.wav',
  ),
];

abstract final class StarlitSound {
  static const _async = 0x0001;
  static const _filename = 0x00020000;
  static const _nodefault = 0x0002;

  static String? _dir;

  static String _soundsDir() {
    final cached = _dir;
    if (cached != null) return cached;
    final exeDir = p.dirname(Platform.resolvedExecutable);
    final bundled = p.join(exeDir, 'data', 'flutter_assets', 'assets', 'sounds');
    return _dir = Directory(bundled).existsSync()
        ? bundled
        : p.join(Directory.current.path, 'assets', 'sounds');
  }

  static void _play(String file) {
    if (!Platform.isWindows) return;
    final path = p.join(_soundsDir(), file);
    if (!File(path).existsSync()) return;
    // SND_ASYNC keeps reading the buffer after the call returns, so it is
    // deliberately not freed.
    final pathPtr = path.toNativeUtf16();
    try {
      final playSound = DynamicLibrary.open('winmm.dll')
          .lookupFunction<
            Int32 Function(Pointer<Utf16>, IntPtr, Uint32),
            int Function(Pointer<Utf16>, int, int)
          >('PlaySoundW');
      playSound(pathPtr, 0, _filename | _async | _nodefault);
    } catch (_) {}
  }

  static StarlitSoundPack _pack(String id) => starlitSoundPacks.firstWhere(
    (s) => s.id == id,
    orElse: () => starlitSoundPacks.first,
  );

  static void preview(String id) => _play(_pack(id).on);

  static void effect(String file) => _play(file);

  static Future<void> connected() async {
    if (!await StarlitPrefs.soundEnabled()) return;
    _play(_pack(await StarlitPrefs.soundId()).on);
  }

  static Future<void> disconnected() async {
    if (!await StarlitPrefs.soundEnabled()) return;
    _play(_pack(await StarlitPrefs.soundId()).off);
  }
}
