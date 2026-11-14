import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pokepiko/main.dart' as app;
import 'package:pokepiko/screens/widgets/choice_button.dart';

/// 実機・シミュレーターでアプリを自動で操作して、各画面のスクリーンショットを撮る
/// （画面の切れ・はみ出しを、本物のフォントと画面サイズで確かめるため）
///
/// 動かし方:
///   flutter drive --driver=test_driver/integration_test.dart \
///     --target=integration_test/screenshot_test.dart -d <端末ID>
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

  testWidgets('各画面のスクリーンショット', (tester) async {
    await app.main();
    await waitFor(tester, find.text('はじめる'));
    await wait(tester, 500);
    await binding.takeScreenshot('01_title');

    await tester.tap(find.text('はじめる'));
    await waitFor(tester, find.text('スタート！'));
    await wait(tester, 2000); // 代表ポケモンの絵の読み込みを待つ
    await binding.takeScreenshot('02_settings_top');

    await tester.drag(find.byType(ListView).first, const Offset(0, -600));
    await wait(tester, 800);
    await binding.takeScreenshot('03_settings_bottom');

    await tester.tap(find.text('スタート！'));
    await waitFor(tester, find.byType(ChoiceButton));
    await wait(tester, 2000); // 画像の読み込みを待つ
    await binding.takeScreenshot('04_quiz');

    // 1問目は「まちがい」になりそうな、1番上を押す（どちらでも撮れればよい）
    await tester.tap(find.byType(ChoiceButton).first);
    await wait(tester, 300);
    await binding.takeScreenshot('05_quiz_answered');

    // 残りの問題を進めて結果画面へ
    for (var n = 2; n <= 10; n++) {
      await wait(tester, 1200);
      await waitFor(tester, find.byType(ChoiceButton));
      await tester.tap(find.byType(ChoiceButton).at(1));
    }
    await waitFor(tester, find.text('もういちど'));
    await wait(tester, 2500); // 星のアニメーションと画像を待つ
    await binding.takeScreenshot('06_result');
  });
}
