import 'dart:async';
import 'dart:io';

import 'package:starlit_connect/engine/config.dart';
import 'package:starlit_connect/engine/node.dart';
import 'package:starlit_connect/engine/ping.dart';
import 'package:starlit_connect/engine/process.dart';
import 'package:starlit_connect/engine/routing.dart';
import 'package:starlit_connect/engine/stats.dart';
import 'package:starlit_connect/engine/storage.dart';
import 'package:starlit_connect/engine/subscription.dart';
import 'package:starlit_connect/engine/system_proxy.dart';
import 'package:starlit_connect/engine/tun.dart';
import 'package:starlit_connect/starlit/servers.dart';
import 'package:flutter/foundation.dart';

/// Starlit VPN engine: Xray process + subscription + ping + system proxy.
class StarlitEngine extends ChangeNotifier {
  StarlitEngine();

  final _process = StarlitXrayProcess();
  List<StarlitNode> _nodes = const [];
  final Map<String, int> _delays = {};
  String? _selectedId;
  String? _subscriptionUrl;
  String? _userInfo;
  var _connected = false;
  var _busy = false;
  var _pingBusy = false;
  var _tun = false;
  String? _lastError;
  Timer? _speedTimer;
  var _upBytes = 0;
  var _downBytes = 0;
  var _upBps = 0;
  var _downBps = 0;
  DateTime? _speedAt;

  List<StarlitNode> get nodes => _nodes;
  Map<String, int> get delays => Map.unmodifiable(_delays);
  String? get selectedId => _selectedId;
  StarlitNode? get selectedNode {
    final id = _selectedId;
    if (id == null) return null;
    for (final n in _nodes) {
      if (n.id == id) return n;
    }
    return null;
  }

  String? get subscriptionUrl => _subscriptionUrl;
  String? get userInfo => _userInfo;
  bool get hasSession =>
      (_subscriptionUrl != null && _subscriptionUrl!.isNotEmpty) ||
      _nodes.isNotEmpty;
  bool get connected => _connected;
  bool get busy => _busy;
  bool get pingBusy => _pingBusy;
  bool get tun => _tun;
  String? get lastError => _lastError;
  int get mixedPort => StarlitXrayConfig.defaultMixedPort;
  int get upBps => _upBps;
  int get downBps => _downBps;

  List<StarlitNode> get visibleNodes => [
        for (final n in _nodes)
          if (!StarlitServers.isSystem(n.name) && !StarlitServers.isAuto(n.name))
            n,
      ];

  Future<void> init() async {
    // Heal a previous hard exit that left WinINET pointed at a dead port.
    await StarlitSystemProxy.forceDisable();
    _subscriptionUrl = await StarlitEngineStorage.subscriptionUrl();
    _selectedId = await StarlitEngineStorage.selectedNodeId();
    _userInfo = await StarlitEngineStorage.userInfo();
    _tun = await StarlitEngineStorage.tunEnabled();
    _nodes = await StarlitEngineStorage.loadNodes();
    notifyListeners();
  }

  Future<void> importSubscription(String url) async {
    _busy = true;
    _lastError = null;
    notifyListeners();
    try {
      final result = await StarlitSubscription.fetch(url);
      if (result.nodes.isEmpty) {
        throw StateError('Подписка пуста или формат не распознан (Xray JSON)');
      }
      _subscriptionUrl = url;
      _nodes = result.nodes;
      _userInfo = result.userInfo;
      await StarlitEngineStorage.setSubscriptionUrl(url);
      await StarlitEngineStorage.setUserInfo(result.userInfo);
      await StarlitEngineStorage.saveNodes(_nodes);
      if (_selectedId == null ||
          !_nodes.any((n) => n.id == _selectedId)) {
        _selectedId = _nodes.first.id;
        await StarlitEngineStorage.setSelectedNodeId(_selectedId!);
      }
    } catch (e) {
      _lastError = e.toString();
      rethrow;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> refreshSubscription() async {
    final url = _subscriptionUrl;
    if (url == null || url.isEmpty) return;
    await importSubscription(url);
    if (_connected) await _applyRunning();
  }

  Future<void> clearSession() async {
    await disconnect();
    await StarlitEngineStorage.clearSubscription();
    _subscriptionUrl = null;
    _nodes = const [];
    _selectedId = null;
    _userInfo = null;
    _delays.clear();
    notifyListeners();
  }

  Future<void> selectNode(String id) async {
    if (!_nodes.any((n) => n.id == id)) return;
    _selectedId = id;
    await StarlitEngineStorage.setSelectedNodeId(id);
    notifyListeners();
    if (_connected) await _applyRunning();
  }

  Future<void> setTun(bool enabled) async {
    if (enabled && !await StarlitTun.wintunPresent()) {
      throw StateError(
        'wintun.dll не найден — TUN недоступен в этой установке',
      );
    }
    if (enabled && Platform.isWindows && !await StarlitTun.isElevated()) {
      throw StateError(
        'TUN нужен запуск от имени администратора. Закройте приложение и откройте его через «Запуск от имени администратора».',
      );
    }
    _tun = enabled;
    await StarlitEngineStorage.setTunEnabled(enabled);
    notifyListeners();
    if (!_connected) return;
    try {
      await _applyRunning();
      if (_tun) {
        await StarlitSystemProxy.forceDisable();
      } else {
        await StarlitSystemProxy.enable(mixedPort);
      }
    } catch (e) {
      _lastError = e.toString();
      await StarlitSystemProxy.forceDisable();
      await _process.stop();
      _connected = false;
      _stopSpeedPoll();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> connect({String? nodeId}) async {
    if (nodeId != null) await selectNode(nodeId);
    final node = selectedNode ??
        (visibleNodes.isNotEmpty ? visibleNodes.first : null);
    if (node == null) {
      throw StateError('Нет серверов для подключения');
    }
    _selectedId = node.id;
    await StarlitEngineStorage.setSelectedNodeId(node.id);
    _busy = true;
    _lastError = null;
    notifyListeners();
    try {
      await _applyRunning();
      // TUN owns routes; WinINET system proxy on top of a dead mixed port
      // is what breaks Happ and other clients after a hard exit.
      if (!_tun) {
        await StarlitSystemProxy.enable(mixedPort);
      } else {
        await StarlitSystemProxy.forceDisable();
      }
      _connected = true;
      _startSpeedPoll();
    } catch (e) {
      _lastError = e.toString();
      _connected = false;
      _stopSpeedPoll();
      await StarlitSystemProxy.forceDisable();
      await _process.stop();
      rethrow;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    _busy = true;
    notifyListeners();
    try {
      _stopSpeedPoll();
      await StarlitSystemProxy.forceDisable();
      await _process.stop();
    } finally {
      _connected = false;
      _upBps = 0;
      _downBps = 0;
      _busy = false;
      notifyListeners();
    }
  }

  void _startSpeedPoll() {
    _stopSpeedPoll();
    _upBytes = 0;
    _downBytes = 0;
    _speedAt = null;
    _speedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      unawaited(_tickSpeed());
    });
  }

  void _stopSpeedPoll() {
    _speedTimer?.cancel();
    _speedTimer = null;
  }

  Future<void> _tickSpeed() async {
    if (!_connected) return;
    final t = await StarlitXrayStats.queryTraffic();
    final now = DateTime.now();
    final prevAt = _speedAt;
    if (prevAt != null) {
      final dt = now.difference(prevAt).inMilliseconds / 1000.0;
      if (dt > 0.2) {
        final du = t.up - _upBytes;
        final dd = t.down - _downBytes;
        _upBps = du > 0 ? (du / dt).round() : 0;
        _downBps = dd > 0 ? (dd / dt).round() : 0;
        notifyListeners();
      }
    }
    _upBytes = t.up;
    _downBytes = t.down;
    _speedAt = now;
  }

  Future<void> _applyRunning() async {
    final node = selectedNode;
    if (node == null) throw StateError('No node selected');
    final built = await StarlitXrayRouting.build();
    final config = StarlitXrayConfig.build(
      node: node,
      routingRules: built.rules,
      domainStrategy: built.strategy,
      mixedPort: mixedPort,
      tun: _tun,
      dns: built.dns,
    );
    await _process.start(config);
  }

  Future<void> syncRouting() async {
    if (!_connected) return;
    await _applyRunning();
  }

  Future<void> runPing() async {
    if (_pingBusy) return;
    final list = visibleNodes;
    if (list.isEmpty) return;
    _pingBusy = true;
    notifyListeners();
    try {
      final map = await StarlitEnginePing.probeAll(list);
      _delays
        ..clear()
        ..addAll(map);
    } finally {
      _pingBusy = false;
      notifyListeners();
    }
  }

  int? delayOf(String nodeId) {
    final v = _delays[nodeId];
    if (v == null) return null;
    return v;
  }

  StarlitNode? bestNode() {
    StarlitNode? winner;
    var best = 1 << 30;
    for (final n in visibleNodes) {
      final d = _delays[n.id];
      if (d != null && d > 0 && d < best) {
        best = d;
        winner = n;
      }
    }
    return winner;
  }

  List<StarlitNode> orderedByPing() {
    final list = [...visibleNodes];
    list.sort((a, b) {
      int rank(StarlitNode n) {
        final d = _delays[n.id];
        return d != null && d > 0 ? d : 1 << 30;
      }

      return rank(a).compareTo(rank(b));
    });
    return list;
  }

  @override
  void dispose() {
    _stopSpeedPoll();
    unawaited(disconnect());
    unawaited(_process.dispose());
    super.dispose();
  }
}
