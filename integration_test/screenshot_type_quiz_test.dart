import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pokepiko/main.dart' as app;
import 'package:pokepiko/screens/widgets/choice_button.dart';
import 'package:pokepiko/screens/widgets/image_choice.dart';

/// タイプクイズの画面を自動で操作して、スクリーンショットを撮る
///
/// 動かし方:
///   flutter drive --driver=test_driver/integration_test.dart \
///     --target=integration_test/screenshot_type_quiz_test.dart -d <端末ID>
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

  testWidgets('タイプクイズのスクリーンショット', (tester) async {
    await app.main();
    await waitFor(tester, find.text('はじめる'));
    await wait(tester, 500);
    await binding.takeScreenshot('t01_title');

    await tester.tap(find.text('はじめる'));
    await waitFor(tester, find.text('タイプクイズ'));
    await wait(tester, 1000); // 画面が切りかわるのを待つ
    await tester.tap(find.text('タイプクイズ'));
    await wait(tester, 300); // 「もんだい」の段が出てくるのを待つ
    await tester.tap(find.text('ポケモン→タイプ'));
    await wait(tester, 2000);
    await binding.takeScreenshot('t02_settings_type');

    // ポケモン→タイプ
    await tester.tap(find.text('スタート！'));
    await waitFor(tester, find.byType(ChoiceButton));
    await wait(tester, 2000);
    await binding.takeScreenshot('t03_pokemon_to_type');
    await tester.tap(find.byType(ChoiceButton).first);
    await wait(tester, 300);
    await binding.takeScreenshot('t04_pokemon_to_type_answered');

    // 設定にもどって、タイプ→ポケモン
    await wait(tester, 1500);
    await tester.pageBack();
    // 画面が切りかわるアニメーションの間は、押しても反応しないので待つ
    await wait(tester, 1000);
    await waitFor(tester, find.text('タイプ→ポケモン'));
    await tester.tap(find.text('タイプ→ポケモン'));
    await wait(tester, 300);
    await tester.tap(find.text('スタート！'));
    await waitFor(tester, find.byType(ImageChoice));
    await wait(tester, 3000);
    await binding.takeScreenshot('t05_type_to_pokemon');
    await tester.tap(find.byType(ImageChoice).first);
    await wait(tester, 300);
    await binding.takeScreenshot('t06_type_to_pokemon_answered');

    // 残りを進めて結果画面へ
    for (var n = 2; n <= 10; n++) {
      await wait(tester, 1200);
      await waitFor(tester, find.byType(ImageChoice));
      await tester.tap(find.byType(ImageChoice).at(1));
    }
    await waitFor(tester, find.text('もういちど'));
    await wait(tester, 2500);
    await binding.takeScreenshot('t07_result');
  });
}
