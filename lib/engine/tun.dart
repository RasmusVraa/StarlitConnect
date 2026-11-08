import 'dart:io';

import 'package:starlit_connect/engine/paths.dart';

/// Windows TUN notes for Xray.
///
/// Xray's tun inbound needs WinTun next to `xray.exe` (and preferably in the
/// working / asset dir) plus an elevated process for
/// `autoSystemRoutingTable`.
abstract final class StarlitTun {
  static Future<bool> wintunPresent() async {
    final dataDir = await StarlitEnginePaths.dataDir();
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final xray = await StarlitEnginePaths.resolveXrayExe();
    final candidates = [
      if (xray != null)
        '${xray.parent.path}${Platform.pathSeparator}wintun.dll',
      '${dataDir.path}${Platform.pathSeparator}wintun.dll',
      '$exeDir${Platform.pathSeparator}xray${Platform.pathSeparator}wintun.dll',
      '$exeDir${Platform.pathSeparator}wintun.dll',
      '${Directory.current.path}${Platform.pathSeparator}third_party${Platform.pathSeparator}xray${Platform.pathSeparator}wintun.dll',
    ];
    for (final path in candidates) {
      if (await File(path).exists()) return true;
    }
    return false;
  }

  /// WinTun + auto routes need an elevated token on Windows.
  static Future<bool> isElevated() async {
    if (!Platform.isWindows) return true;
    try {
      final r = await Process.run(
        'net',
        const ['session'],
        runInShell: true,
      );
      return r.exitCode == 0;
    } catch (_) {
      return false;
    }
  }
}
