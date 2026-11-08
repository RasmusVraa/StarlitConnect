import 'dart:async';
import 'dart:io';

import 'package:starlit_connect/engine/node.dart';
import 'package:starlit_connect/starlit/prefs.dart';

abstract final class StarlitEnginePing {
  static Future<int> probe(
    StarlitNode node, {
    Duration timeout = const Duration(seconds: 5),
    String? type,
  }) async {
    final mode = type ?? await StarlitPrefs.pingType();
    if (mode == 'icmp') {
      return _icmp(node, timeout: timeout);
    }
    if (node.isHy2) {
      return _udpOrFail(node, timeout: timeout);
    }
    return _tcp(node, timeout: timeout);
  }

  static Future<Map<String, int>> probeAll(
    List<StarlitNode> nodes, {
    int? concurrency,
  }) async {
    final type = await StarlitPrefs.pingType();
    final workers = concurrency ?? await StarlitPrefs.pingConcurrency();
    final results = <String, int>{};
    var i = 0;
    Future<void> worker() async {
      while (true) {
        final idx = i++;
        if (idx >= nodes.length) return;
        final n = nodes[idx];
        try {
          results[n.id] = await probe(n, type: type);
        } catch (_) {
          results[n.id] = -1;
        }
      }
    }

    await Future.wait([
      for (var c = 0; c < workers && c < nodes.length; c++) worker(),
    ]);
    return results;
  }

  static Future<int> _tcp(
    StarlitNode node, {
    required Duration timeout,
  }) async {
    final host = node.address;
    final port = node.port;
    if (host == null || host.isEmpty || port == null || port <= 0) {
      return -1;
    }
    final sw = Stopwatch()..start();
    try {
      final socket = await Socket.connect(
        host,
        port,
        timeout: timeout,
      );
      await socket.close();
      final ms = sw.elapsedMilliseconds;
      return ms <= 0 ? 1 : ms;
    } catch (_) {
      return -1;
    }
  }

  static Future<int> _icmp(
    StarlitNode node, {
    required Duration timeout,
  }) async {
    final host = node.address;
    if (host == null || host.isEmpty) return -1;
    if (!Platform.isWindows) return _tcp(node, timeout: timeout);
    final msBudget = timeout.inMilliseconds.clamp(500, 8000);
    try {
      final r = await Process.run(
        'ping',
        ['-n', '1', '-w', '$msBudget', host],
        runInShell: false,
      );
      final out = '${r.stdout}\n${r.stderr}';
      final m = RegExp(r'(?:time[=<]|время[=<])\s*(\d+)\s*ms', caseSensitive: false)
          .firstMatch(out);
      if (m != null) {
        final ms = int.tryParse(m.group(1)!) ?? -1;
        return ms <= 0 ? 1 : ms;
      }
      if (out.toLowerCase().contains('ttl=')) {
        return 1;
      }
      return -1;
    } catch (_) {
      return -1;
    }
  }

  /// HY2 listens on UDP — try a short UDP connect; timeout = fail.
  static Future<int> _udpOrFail(
    StarlitNode node, {
    required Duration timeout,
  }) async {
    final host = node.address;
    final port = node.port;
    if (host == null || host.isEmpty || port == null || port <= 0) {
      return -1;
    }
    final sw = Stopwatch()..start();
    RawDatagramSocket? socket;
    try {
      final addresses = await InternetAddress.lookup(host);
      if (addresses.isEmpty) return -1;
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.send(const [0], addresses.first, port);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final ms = sw.elapsedMilliseconds;
      return ms <= 0 ? 1 : ms;
    } catch (_) {
      return -1;
    } finally {
      socket?.close();
    }
  }
}
