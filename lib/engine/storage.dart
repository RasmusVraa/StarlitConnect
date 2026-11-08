import 'dart:convert';

import 'package:starlit_connect/engine/node.dart';
import 'package:starlit_connect/engine/paths.dart';
import 'package:starlit_connect/starlit/prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract final class StarlitEngineStorage {
  static const _urlKey = 'starlit_sub_url';
  static const _selectedKey = 'starlit_selected_node';
  static const _userInfoKey = 'starlit_sub_userinfo';
  static const _tunKey = 'starlit_tun_enabled';

  static Future<SharedPreferences> get _p => SharedPreferences.getInstance();

  static Future<String?> subscriptionUrl() async =>
      (await _p).getString(_urlKey);

  static Future<void> setSubscriptionUrl(String url) async =>
      (await _p).setString(_urlKey, url);

  static Future<void> clearSubscription() async {
    final p = await _p;
    await p.remove(_urlKey);
    await p.remove(_selectedKey);
    await p.remove(_userInfoKey);
    final cache = await StarlitEnginePaths.nodesCacheFile();
    if (await cache.exists()) await cache.delete();
    await StarlitPrefs.clearCabinetToken();
    await StarlitPrefs.clearCabinetCsrf();
  }

  static Future<String?> selectedNodeId() async =>
      (await _p).getString(_selectedKey);

  static Future<void> setSelectedNodeId(String id) async =>
      (await _p).setString(_selectedKey, id);

  static Future<String?> userInfo() async =>
      (await _p).getString(_userInfoKey);

  static Future<void> setUserInfo(String? value) async {
    final p = await _p;
    if (value == null || value.isEmpty) {
      await p.remove(_userInfoKey);
    } else {
      await p.setString(_userInfoKey, value);
    }
  }

  static Future<bool> tunEnabled() async =>
      (await _p).getBool(_tunKey) ?? false;

  static Future<void> setTunEnabled(bool v) async =>
      (await _p).setBool(_tunKey, v);

  static Future<void> saveNodes(List<StarlitNode> nodes) async {
    final file = await StarlitEnginePaths.nodesCacheFile();
    final payload = [
      for (final n in nodes)
        {
          'id': n.id,
          'name': n.name,
          'address': n.address,
          'port': n.port,
          'protocol': n.protocol,
          'outbound': n.outbound,
        },
    ];
    await file.writeAsString(jsonEncode(payload));
  }

  static Future<List<StarlitNode>> loadNodes() async {
    final file = await StarlitEnginePaths.nodesCacheFile();
    if (!await file.exists()) return const [];
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! List) return const [];
      return [
        for (final item in decoded)
          if (item is Map)
            StarlitNode(
              id: '${item['id']}',
              name: '${item['name']}',
              outbound: Map<String, dynamic>.from(item['outbound'] as Map),
              address: item['address'] as String?,
              port: item['port'] is int
                  ? item['port'] as int
                  : int.tryParse('${item['port']}'),
              protocol: '${item['protocol'] ?? ''}',
            ),
      ];
    } catch (_) {
      return const [];
    }
  }
}
