import 'package:proxy/proxy.dart';

/// Windows system proxy → local Xray mixed inbound.
abstract final class StarlitSystemProxy {
  static final Proxy _proxy = Proxy();

  static Future<void> enable(int port) async {
    final ok = await _proxy.startProxy(port, const [
      'localhost',
      '127.*',
      '10.*',
      '192.168.*',
      '172.16.*',
      '172.17.*',
      '172.18.*',
      '172.19.*',
      '172.2*.*',
      '172.30.*',
      '172.31.*',
      '<local>',
    ]);
    if (!ok) {
      throw StateError('Failed to set Windows system proxy');
    }
  }

  static Future<void> disable() async {
    await forceDisable();
  }

  /// Clears WinINET proxy even if this process did not set it this run.
  static Future<void> forceDisable() async {
    try {
      await _proxy.stopProxy();
    } catch (_) {}
  }
}
