import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:starlit_connect/starlit/prefs.dart';

/// Стабильный HWID для Remnawave (`x-hwid`, 10–64 символа `[a-zA-Z0-9=-]`).
abstract final class StarlitHwid {
  static String? _cached;
  static ({String os, String version, String model})? _deviceCached;

  static Future<String> id() async {
    if (_cached != null) return _cached!;
    final saved = await StarlitPrefs.hwid();
    if (saved != null && _valid(saved)) {
      _cached = saved;
      return saved;
    }
    final generated = await _generate();
    await StarlitPrefs.setHwid(generated);
    _cached = generated;
    return generated;
  }

  /// Real device labels for Remnawave (`x-device-os` / `x-ver-os` / `x-device-model`).
  static Future<({String os, String version, String model})> deviceInfo() async {
    if (_deviceCached != null) return _deviceCached!;
    final host = Platform.localHostname.trim();
    final model = host.isEmpty ? Platform.operatingSystem : host;
    if (Platform.isWindows) {
      final win = await _windowsInfo();
      _deviceCached = (
        os: 'Windows',
        version: _clip(win, 64),
        model: _clip(model, 64),
      );
      return _deviceCached!;
    }
    final os = Platform.isMacOS
        ? 'macOS'
        : Platform.isLinux
            ? 'Linux'
            : Platform.operatingSystem;
    _deviceCached = (
      os: os,
      version: _clip(Platform.operatingSystemVersion.trim(), 64),
      model: _clip(model, 64),
    );
    return _deviceCached!;
  }

  static Future<Map<String, String>> remnawaveHeaders() async {
    final hwid = await id();
    final info = await deviceInfo();
    return {
      'x-hwid': hwid,
      'x-device-os': info.os,
      'x-ver-os': info.version,
      'x-device-model': info.model,
    };
  }

  static bool _valid(String value) =>
      RegExp(r'^[a-zA-Z0-9=-]{10,64}$').hasMatch(value);

  static String _clip(String value, int max) =>
      value.length > max ? value.substring(0, max) : value;

  static Future<String> _generate() async {
    final seed = StringBuffer()
      ..write(Platform.localHostname)
      ..write('|')
      ..write(Platform.operatingSystem)
      ..write('|')
      ..write(Platform.operatingSystemVersion);

    if (Platform.isWindows) {
      try {
        final r = await Process.run(
          'reg',
          const [
            'query',
            r'HKLM\SOFTWARE\Microsoft\Cryptography',
            '/v',
            'MachineGuid',
          ],
          runInShell: false,
        );
        if (r.exitCode == 0) {
          final out = '${r.stdout}';
          final m = RegExp(
            r'MachineGuid\s+REG_SZ\s+([a-fA-F0-9-]+)',
          ).firstMatch(out);
          if (m != null) seed.write('|${m.group(1)}');
        }
      } catch (_) {}
    }

    final digest = sha256.convert(utf8.encode(seed.toString()));
    var id = digest.toString().substring(0, 32);
    if (!_valid(id)) {
      final rnd = Random.secure();
      id = List.generate(24, (_) {
        const alphabet =
            'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
        return alphabet[rnd.nextInt(alphabet.length)];
      }).join();
    }
    return id;
  }

  /// Dart/Win32 still expose Win11 as "Windows 10 … Build N". Read the real
  /// product + build from the registry and map build ≥ 22000 → Windows 11.
  static Future<String> _windowsInfo() async {
    var product = '';
    var display = '';
    var build = 0;
    try {
      final r = await Process.run(
        'reg',
        const [
          'query',
          r'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion',
        ],
        runInShell: false,
      );
      if (r.exitCode == 0) {
        final out = '${r.stdout}';
        product = _regSz(out, 'ProductName') ?? '';
        display = _regSz(out, 'DisplayVersion') ?? '';
        build = int.tryParse(_regSz(out, 'CurrentBuild') ?? '') ?? 0;
        build = int.tryParse(_regSz(out, 'CurrentBuildNumber') ?? '') ?? build;
      }
    } catch (_) {}

    if (build <= 0) {
      final m = RegExp(
        r'Build\s+(\d+)',
        caseSensitive: false,
      ).firstMatch(Platform.operatingSystemVersion);
      build = int.tryParse(m?.group(1) ?? '') ?? 0;
    }
    if (product.isEmpty) {
      product = Platform.operatingSystemVersion;
    }

    final isWin11 =
        build >= 22000 || product.toLowerCase().contains('windows 11');
    // Keep the real edition (Pro/Home/…); only correct the major family.
    var label = product.replaceAll('"', '').trim();
    if (isWin11) {
      label = label.replaceAll(
        RegExp(r'Windows\s*10', caseSensitive: false),
        'Windows 11',
      );
      if (!label.toLowerCase().contains('windows 11')) {
        label = 'Windows 11 $label'.trim();
      }
    }

    final parts = <String>[
      label,
      if (display.isNotEmpty) display,
      if (build > 0) 'Build $build',
    ];
    return parts.join(' ');
  }

  static String? _regSz(String out, String name) {
    final m = RegExp(
      '$name\\s+REG_SZ\\s+(.+)',
      caseSensitive: false,
    ).firstMatch(out);
    return m?.group(1)?.trim();
  }
}
