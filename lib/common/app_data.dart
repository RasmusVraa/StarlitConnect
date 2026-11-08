import 'dart:io';

import 'package:starlit_connect/common/common.dart';
import 'package:starlit_connect/database/database.dart';
import 'package:starlit_connect/enum/enum.dart';

Future<void> clearAppData() async {
  await preferences.clearPreferences();
  try {
    await database.close();
  } catch (error) {
    // Drift rethrows a failed open from close; that file still has to go.
    commonPrint.log(
      'close database failed: $error',
      logLevel: LogLevel.warning,
    );
  }
  await File(await appPath.databasePath).safeDelete(recursive: true);
  await Directory(await appPath.profilesPath).safeDelete(recursive: true);
}
