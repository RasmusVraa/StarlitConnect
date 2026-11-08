import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:starlit_connect/engine/paths.dart';

/// Owns the Xray.exe child process.
class StarlitXrayProcess {
  Process? _process;
  final _logController = StreamController<String>.broadcast();

  Stream<String> get logs => _logController.stream;
  bool get isRunning => _process != null;

  Future<void> start(Map<String, dynamic> config) async {
    await stop();
    final exe = await StarlitEnginePaths.resolveXrayExe();
    if (exe == null) {
      throw StateError(
        'Xray.exe not found. Place it in third_party/xray or next to the app.',
      );
    }
    final configFile = await StarlitEnginePaths.configFile();
    await configFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(config),
    );

    // Seed bundled assets only when missing — never overwrite Happ/Starlit
    // geosite/geoip that routing already fetched (tags like ru-banks).
    // WinTun must sit next to xray.exe (LoadLibrary) and in the work dir.
    final geoDir = exe.parent;
    final dataDir = await StarlitEnginePaths.dataDir();
    final needsTun = _configHasTun(config);
    for (final name in ['geoip.dat', 'geosite.dat', 'wintun.dll']) {
      final dest = File('${dataDir.path}${Platform.pathSeparator}$name');
      final force = name == 'wintun.dll' && needsTun;
      if (!force && await dest.exists() && await dest.length() > 0) continue;
      final src = File('${geoDir.path}${Platform.pathSeparator}$name');
      if (await src.exists()) {
        await src.copy(dest.path);
      }
    }
    if (needsTun) {
      final besideExe = File(
        '${geoDir.path}${Platform.pathSeparator}wintun.dll',
      );
      final inData = File('${dataDir.path}${Platform.pathSeparator}wintun.dll');
      if (!await besideExe.exists() && await inData.exists()) {
        await inData.copy(besideExe.path);
      }
      if (!await besideExe.exists() && !await inData.exists()) {
        throw StateError(
          'wintun.dll not found — TUN mode needs it next to Xray',
        );
      }
    }

    final logBuf = StringBuffer();
    final proc = await Process.start(
      exe.path,
      ['run', '-c', configFile.path],
      workingDirectory: dataDir.path,
      environment: {
        ...Platform.environment,
        // Prefer Happ/Starlit geo in the data dir over bundled files next to exe.
        'XRAY_LOCATION_ASSET': dataDir.path,
      },
      mode: ProcessStartMode.normal,
    );
    _process = proc;
    void onLog(String s) {
      logBuf.write(s);
      if (!_logController.isClosed) _logController.add(s);
    }

    proc.stdout.transform(utf8.decoder).listen(onLog);
    proc.stderr.transform(utf8.decoder).listen(onLog);
    unawaited(
      proc.exitCode.then((code) {
        if (_process == proc) _process = null;
        if (!_logController.isClosed) {
          _logController.add('xray exited: $code');
        }
      }),
    );
    // Give the process a moment to bind the mixed port / fail config load.
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (_process == null) {
      final raw = logBuf.toString().trim();
      final hint = raw.isEmpty
          ? 'Xray exited immediately after start'
          : raw.split('\n').where((l) => l.trim().isNotEmpty).take(6).join('\n');
      throw StateError(hint);
    }
  }

  Future<void> stop() async {
    final proc = _process;
    _process = null;
    if (proc == null) return;
    // Prefer a normal kill first so WinTun can tear down routes; only
    // escalate if the process ignores it.
    proc.kill();
    try {
      await proc.exitCode.timeout(const Duration(seconds: 3));
      return;
    } catch (_) {}
    proc.kill(ProcessSignal.sigkill);
    try {
      await proc.exitCode.timeout(const Duration(seconds: 2));
    } catch (_) {}
  }

  Future<void> dispose() async {
    await stop();
    await _logController.close();
  }

  static bool _configHasTun(Map<String, dynamic> config) {
    final inbounds = config['inbounds'];
    if (inbounds is! List) return false;
    for (final item in inbounds) {
      if (item is Map && item['protocol'] == 'tun') return true;
    }
    return false;
  }
}
