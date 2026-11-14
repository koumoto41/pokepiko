import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// integration_test/ のテストを動かし、撮ったスクリーンショットを Mac に保存する
/// 保存先: 環境変数 SCREENSHOT_DIR（なければ build/screenshots）
Future<void> main() => integrationDriver(
  onScreenshot: (name, bytes, [args]) async {
    final dir = Platform.environment['SCREENSHOT_DIR'] ?? 'build/screenshots';
    final file = File('$dir/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
    return true;
  },
);
