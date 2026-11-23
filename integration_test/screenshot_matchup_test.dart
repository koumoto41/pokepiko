import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pokepiko/main.dart' as app;
import 'package:pokepiko/providers/sound_provider.dart';
import 'package:pokepiko/screens/widgets/image_choice.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// あいしょうクイズの画面を自動で操作して、スクリーンショットを撮る
///
/// 動かし方:
///   flutter drive --driver=test_driver/integration_test.dart \
///     --target=integration_test/screenshot_matchup_test.dart -d <端末ID>
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// finder が見つかるまで待つ（ネットからの読み込みがあるので、少しずつ進める）
  Future<void> waitFor(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 300 && finder.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(finder, findsWidgets);
  }

  Future<void> wait(WidgetTester tester, int ms) async {
    for (var t = 0; t < ms; t += 100) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('あいしょうクイズのスクリーンショット', (tester) async {
    await app.main();
    await waitFor(tester, find.text('はじめる'));
    await wait(tester, 3000); // 主役のポケモンの絵が出るのを待つ
    await binding.takeScreenshot('m01_title');

    await tester.tap(find.text('はじめる'));
    await waitFor(tester, find.text('あいしょうクイズ'));
    await wait(tester, 1000); // 画面が切りかわるのを待つ
    await tester.tap(find.text('あいしょうクイズ'));
    await wait(tester, 1000);
    await binding.takeScreenshot('m02_settings');
    // SE では画像の見せかたの段が下に隠れているので、見えるところまで動かしてから押す
    await tester.ensureVisible(find.text('イラスト'));
    await wait(tester, 500);
    await tester.tap(find.text('イラスト'));
    await wait(tester, 300);
    await binding.takeScreenshot('m02b_settings_scrolled');

    await tester.tap(find.text('スタート！'));
    await waitFor(tester, find.byType(ImageChoice));
    await wait(tester, 3000);
    await binding.takeScreenshot('m03_matchup');
    await tester.tap(find.byType(ImageChoice).first);
    await wait(tester, 300);
    await binding.takeScreenshot('m04_matchup_answered');

    // 設定にもどって、シルエット
    await wait(tester, 1500);
    await tester.pageBack();
    await wait(tester, 1000);
    await waitFor(tester, find.text('シルエット'));
    await tester.ensureVisible(find.text('シルエット'));
    await wait(tester, 500);
    await tester.tap(find.text('シルエット'));
    await wait(tester, 300);
    await tester.tap(find.text('スタート！'));
    await waitFor(tester, find.byType(ImageChoice));
    await wait(tester, 3000);
    await binding.takeScreenshot('m05_matchup_silhouette');
    await tester.tap(find.byType(ImageChoice).at(1));
    await wait(tester, 300);
    await binding.takeScreenshot('m06_matchup_silhouette_answered');

    // 片づけ（BGM とアニメーションを止める）
    await tester.pageBack();
    await wait(tester, 1500);
    final container = ProviderScope.containerOf(
      tester.element(find.text('スタート！')),
    );
    await container.read(soundServiceProvider).stopBgm();
    await tester.pumpWidget(const SizedBox());
    await wait(tester, 2000);
  });
}
