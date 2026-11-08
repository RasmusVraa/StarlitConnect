import 'dart:io';

/// Detect Flowseal Zapret (winws / zapret service) on Windows.
abstract final class StarlitZapret {
  static const _processNames = <String>{
    'winws',
    'zapret',
    'zapret-winws',
  };

  /// True when a Zapret worker process or the `zapret` Windows service is up.
  static Future<bool> isRunning() async {
    if (!Platform.isWindows) return false;
    try {
      final procs = await Process.run(
        'powershell',
        [
          '-NoProfile',
          '-NonInteractive',
          '-Command',
          r'''
$ErrorActionPreference = 'SilentlyContinue'
$names = @('winws','zapret','zapret-winws')
if (Get-Process -Name $names | Select-Object -First 1) { '1'; exit 0 }
$svc = Get-Service -Name 'zapret'
if ($svc -and $svc.Status -eq 'Running') { '1'; exit 0 }
'0'
''',
        ],
        runInShell: false,
      );
      return (procs.stdout as String).trim().startsWith('1');
    } catch (_) {
      return false;
    }
  }

  /// Fallback path/name scan used by tests and richer UI if needed.
  static bool matchesProcess({required String name, required String path}) {
    final n = name.toLowerCase().replaceAll('.exe', '');
    if (_processNames.contains(n)) return true;
    final p = path.toLowerCase().replaceAll('\\', '/');
    return p.contains('/zapret') ||
        p.contains('\\zapret') ||
        p.contains('flowseal');
  }
}
