import 'dart:convert';
import 'dart:io';

class StarlitRunningApp {
  const StarlitRunningApp({required this.name, required this.path});

  final String name;
  final String path;

  String get key => path.isNotEmpty ? path : name;
}

/// Enumerate unique Windows processes that have an executable path.
abstract final class StarlitRunningApps {
  static Future<List<StarlitRunningApp>> list() async {
    if (!Platform.isWindows) return const [];
    try {
      final r = await Process.run(
        'powershell',
        [
          '-NoProfile',
          '-NonInteractive',
          '-Command',
          r'''
$ErrorActionPreference = 'SilentlyContinue'
Get-CimInstance Win32_Process |
  Where-Object { $_.ExecutablePath -and $_.Name -like '*.exe' } |
  Select-Object @{N='n';E={$_.Name}}, @{N='p';E={$_.ExecutablePath}} |
  Sort-Object n, p -Unique |
  ConvertTo-Json -Compress
''',
        ],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );
      if (r.exitCode != 0) return const [];
      final raw = (r.stdout as String).trim();
      if (raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      final list = decoded is List
          ? decoded
          : decoded is Map
              ? [decoded]
              : const [];
      final out = <StarlitRunningApp>[];
      final seen = <String>{};
      for (final item in list) {
        if (item is! Map) continue;
        final name = '${item['n'] ?? ''}'.trim();
        final path = '${item['p'] ?? ''}'.trim();
        if (name.isEmpty) continue;
        final key = path.isNotEmpty ? path.toLowerCase() : name.toLowerCase();
        if (!seen.add(key)) continue;
        out.add(StarlitRunningApp(name: name, path: path));
      }
      out.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      return out;
    } catch (_) {
      return const [];
    }
  }
}
