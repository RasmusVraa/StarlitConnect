import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

abstract final class StarlitEnginePaths {
  static Directory? _data;

  static Future<Directory> dataDir() async {
    if (_data != null) return _data!;
    final root = await getApplicationSupportDirectory();
    final dir = Directory(p.join(root.path, 'starlit_xray'));
    if (!await dir.exists()) await dir.create(recursive: true);
    _data = dir;
    return dir;
  }

  static Future<File> configFile() async =>
      File(p.join((await dataDir()).path, 'config.json'));

  static Future<File> nodesCacheFile() async =>
      File(p.join((await dataDir()).path, 'nodes.json'));

  /// Prefer bundled next to the app, then third_party for dev runs.
  static Future<File?> resolveXrayExe() async {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final candidates = <String>[
      p.join(exeDir, 'xray', 'xray.exe'),
      p.join(exeDir, 'Xray.exe'),
      p.join(exeDir, 'xray.exe'),
      p.join(Directory.current.path, 'third_party', 'xray', 'xray.exe'),
      p.join(
        File(Platform.script.toFilePath()).parent.path,
        '..',
        '..',
        'third_party',
        'xray',
        'xray.exe',
      ),
    ];
    for (final path in candidates) {
      final f = File(p.normalize(path));
      if (await f.exists()) return f;
    }
    return null;
  }
}
