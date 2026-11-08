import 'dart:convert';
import 'dart:io';

import 'package:starlit_connect/engine/config.dart';
import 'package:starlit_connect/engine/paths.dart';

/// Poll Xray StatsService via `xray api statsquery`.
abstract final class StarlitXrayStats {
  static Future<({int up, int down})> queryTraffic({
    int apiPort = StarlitXrayConfig.defaultApiPort,
  }) async {
    final exe = await StarlitEnginePaths.resolveXrayExe();
    if (exe == null) return (up: 0, down: 0);
    try {
      final dataDir = await StarlitEnginePaths.dataDir();
      final r = await Process.run(
        exe.path,
        [
          'api',
          'statsquery',
          '--server=127.0.0.1:$apiPort',
        ],
        workingDirectory: dataDir.path,
        environment: {
          ...Platform.environment,
          'XRAY_LOCATION_ASSET': dataDir.path,
        },
        runInShell: false,
      );
      final out = '${r.stdout}\n${r.stderr}';
      // Prefer JSON if present; else parse name/value lines.
      try {
        final start = out.indexOf('{');
        if (start >= 0) {
          final json = jsonDecode(out.substring(start));
          return _fromJson(json);
        }
      } catch (_) {}
      return _fromText(out);
    } catch (_) {
      return (up: 0, down: 0);
    }
  }

  static ({int up, int down}) _fromJson(Object? json) {
    var up = 0;
    var down = 0;
    void walk(Object? node) {
      if (node is Map) {
        final name = '${node['name'] ?? node['Name'] ?? ''}';
        final value = int.tryParse('${node['value'] ?? node['Value'] ?? ''}') ?? 0;
        if (name.contains('>>>uplink') || name.endsWith('uplink')) {
          up += value;
        } else if (name.contains('>>>downlink') || name.endsWith('downlink')) {
          down += value;
        }
        for (final v in node.values) {
          walk(v);
        }
      } else if (node is List) {
        for (final e in node) {
          walk(e);
        }
      }
    }

    walk(json);
    return (up: up, down: down);
  }

  static ({int up, int down}) _fromText(String out) {
    var up = 0;
    var down = 0;
    final re = RegExp(
      r'(outbound>>>proxy>>>traffic>>>(uplink|downlink))\s*[:=]\s*(\d+)',
      caseSensitive: false,
    );
    for (final m in re.allMatches(out)) {
      final kind = m.group(2)!.toLowerCase();
      final v = int.tryParse(m.group(3)!) ?? 0;
      if (kind == 'uplink') {
        up += v;
      } else {
        down += v;
      }
    }
    return (up: up, down: down);
  }
}
