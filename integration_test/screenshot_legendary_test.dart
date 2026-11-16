import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pokepiko/main.dart' as app;
import 'package:pokepiko/providers/quiz_controller.dart';
import 'package:pokepiko/providers/sound_provider.dart';
import 'package:pokepiko/screens/quiz_screen.dart';
import 'package:pokepiko/screens/widgets/choice_button.dart';
import 'package:pokepiko/screens/widgets/legendary_widgets.dart';

/// でんせつクイズ（シルエット）で全問正解して、伝説・幻を見つけたお祝いと図鑑の札を撮る
///
/// 動かし方:
///   flutter drive --driver=test_driver/integration_test.dart \
///     --target=integration_test/screenshot_legendary_test.dart -d <端末ID>
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

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

  testWidgets('でんせつクイズ', (tester) async {
    await app.main();
    await waitFor(tester, find.text('はじめる'));
    await wait(tester, 2000);
    await binding.takeScreenshot('l01_title');

    await tester.tap(find.text('はじめる'));
    await wait(tester, 1000);
    await tester.tap(find.text('でんせつクイズ'));
    await tester.tap(find.text('シルエット'));
    await wait(tester, 1500);
    await binding.takeScreenshot('l02_settings');

    await tester.tap(find.text('スタート！'));
    for (var n = 1; n <= 10; n++) {
      await waitFor(tester, find.byType(ChoiceButton));
      await wait(tester, 300);
      if (n == 1) {
        await wait(tester, 1500);
        await binding.takeScreenshot('l03_quiz');
      }
      final quiz = ProviderScope.containerOf(
        tester.element(find.byType(QuizScreen)),
      ).read(quizControllerProvider);
      await tester.tap(
        find.byType(ChoiceButton).at(quiz.current!.correctIndex),
      );
      await wait(tester, 1300);
    }

    // 結果画面のあとに出る、伝説・幻のお祝い
    await waitFor(tester, find.byType(LegendaryFoundDialog));
    await wait(tester, 2500);
    await binding.takeScreenshot('l04_legendary_found');
    await tester.tap(find.text('やったね！'));
    await wait(tester, 9000); // 全問正解の花火が終わるまで

    // タイトルに戻って、図鑑の札を見る
    await tester.tap(find.text('タイトル'));
    await wait(tester, 1500);
    await tester.tap(find.text('ずかん'));
    await wait(tester, 2000);
    // 進化の仲間のお祝いが出たら閉じる
    if (find.text('やったね！').evaluate().isNotEmpty) {
      await tester.tap(find.text('やったね！'));
      await wait(tester, 1000);
    }
    await tester.tap(find.text('みつけた だけ'));
    await wait(tester, 2500);
    await binding.takeScreenshot('l05_zukan_badges');
    await tester.tap(find.byType(SpecialBadge).first);
    await wait(tester, 3000);
    await binding.takeScreenshot('l06_zukan_detail');

    await ProviderScope.containerOf(
      tester.element(find.byType(SpecialBadge).first),
    ).read(soundServiceProvider).stopBgm();
    await tester.pumpWidget(const SizedBox());
    await wait(tester, 2000);
  });
}
