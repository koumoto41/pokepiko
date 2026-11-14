import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pokepiko/main.dart' as app;
import 'package:pokepiko/providers/quiz_controller.dart';
import 'package:pokepiko/screens/quiz_screen.dart';
import 'package:pokepiko/screens/result_screen.dart';
import 'package:pokepiko/screens/widgets/choice_button.dart';

/// 10問すべてに正解して、全問正解のお祝い（花火と風船）を撮る
///
/// 動かし方:
///   flutter drive --driver=test_driver/integration_test.dart \
///     --target=integration_test/screenshot_celebration_test.dart -d <端末ID>
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

  testWidgets('全問正解のお祝い', (tester) async {
    await app.main();
    await waitFor(tester, find.text('はじめる'));
    await wait(tester, 500);

    // --- 結果画面の4曲が、iPhone で読み込めて再生できるか ---
    final player = AudioPlayer();
    for (final rank in ResultRank.values) {
      await player.play(AssetSource(rank.jingle));
      await wait(tester, 500);
      final length = await player.getDuration();
      debugPrint('${rank.jingle}: ${player.state} ${length?.inMilliseconds}ms');
      expect(player.state, PlayerState.playing, reason: rank.jingle);
      expect(length!.inMilliseconds, greaterThan(2000), reason: rank.jingle);
      await player.stop();
    }
    await player.dispose();
    await tester.tap(find.text('はじめる'));
    await wait(tester, 1000);
    await tester.tap(find.text('スタート！'));

    // 正解の位置をクイズの状態から読んで、10問とも正解する
    for (var n = 1; n <= 10; n++) {
      await waitFor(tester, find.byType(ChoiceButton));
      await wait(tester, 300);
      final quiz = ProviderScope.containerOf(
        tester.element(find.byType(QuizScreen)),
      ).read(quizControllerProvider);
      await tester.tap(
        find.byType(ChoiceButton).at(quiz.current!.correctIndex),
      );
      await wait(tester, 1300);
    }

    await waitFor(tester, find.text('もういちど'));
    for (final (i, ms) in [(1, 1000), (2, 1500), (3, 2000)]) {
      await wait(tester, ms);
      await binding.takeScreenshot('c0${i}_celebration');
    }

    // お祝いが終わるまで待ってから終わる（動いているアニメーションを残さない）
    await wait(tester, 5000);
    await tester.pumpWidget(const SizedBox());
    await wait(tester, 300);
  });
}
