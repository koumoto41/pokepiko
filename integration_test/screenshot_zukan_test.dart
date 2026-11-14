import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pokepiko/main.dart' as app;
import 'package:pokepiko/providers/collection_provider.dart';
import 'package:pokepiko/providers/data_providers.dart';
import 'package:pokepiko/providers/quiz_controller.dart';
import 'package:pokepiko/screens/quiz_screen.dart';
import 'package:pokepiko/screens/widgets/choice_button.dart';

/// 図鑑を、本物の PokéAPI と iPhone で確かめる
/// - 鳴き声（OGG と、中身が MP3 のもの）を flutter_soloud で読み込んで鳴らせるか
/// - クイズで正解すると図鑑に入るか、各画面のスクリーンショット
///
/// 動かし方:
///   flutter drive --driver=test_driver/integration_test.dart \
///     --target=integration_test/screenshot_zukan_test.dart -d <端末ID>
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

  testWidgets('図鑑のスクリーンショットと鳴き声', (tester) async {
    await app.main();
    await waitFor(tester, find.text('はじめる'));
    await wait(tester, 500);
    await binding.takeScreenshot('z00_title');

    // --- 鳴き声を本物の音声エンジンで読み込んで鳴らす ---
    final container = ProviderScope.containerOf(
      tester.element(find.text('はじめる')),
    );
    final repo = container.read(pokemonRepositoryProvider);
    await SoLoud.instance.init();
    // 25：ピカチュウ（中身は MP3）、1：フシギダネ（本物の OGG Vorbis）
    for (final id in [25, 1]) {
      final file = await repo.getCry(id);
      expect(file, isNotNull, reason: '$id の鳴き声のファイル');
      final source = await SoLoud.instance.loadFile(file!.path);
      final length = SoLoud.instance.getLength(source);
      final handle = SoLoud.instance.play(source);
      expect(SoLoud.instance.getIsValidVoiceHandle(handle), isTrue);
      debugPrint('鳴き声 $id: ${length.inMilliseconds}ms 再生できた');
      expect(length.inMilliseconds, greaterThan(100));
      await wait(tester, 1200);
    }

    // --- クイズで3問正解して、図鑑に入れる ---
    await tester.tap(find.text('はじめる'));
    await wait(tester, 1000);
    await tester.tap(find.text('スタート！'));
    for (var n = 1; n <= 3; n++) {
      await waitFor(tester, find.byType(ChoiceButton));
      await wait(tester, 300);
      final quiz = ProviderScope.containerOf(
        tester.element(find.byType(QuizScreen)),
      ).read(quizControllerProvider);
      await tester.tap(
        find.byType(ChoiceButton).at(quiz.current!.correctIndex),
      );
      await wait(tester, 1500);
    }
    // タイトルまで戻って、ずかんを開く
    await tester.pageBack();
    await wait(tester, 1000);
    await tester.pageBack();
    await wait(tester, 1000);
    await tester.tap(find.text('ずかん'));
    await wait(tester, 3000);
    await binding.takeScreenshot('z01_list');

    // みつけたポケモンのうち、いま表示している世代でいちばん番号が小さいものを開く
    // （一覧の下のほうにいることもあるので、見えるまでドラッグしてから押す）
    final found = await container.read(collectionProvider.future);
    final target = (found.toList()..sort()).first;
    final label = find.text('No.${target.toString().padLeft(4, '0')}');
    await tester.dragUntilVisible(
      label,
      find.byType(GridView),
      const Offset(0, -200),
    );
    await wait(tester, 500);
    await tester.tap(label);
    await wait(tester, 4000);
    await binding.takeScreenshot('z02_detail');

    await tester.tap(find.text('なきごえ'));
    await wait(tester, 1500);

    await tester.tap(find.text('かんじ'));
    await wait(tester, 500);
    await tester.drag(find.byType(ListView).first, const Offset(0, -500));
    await wait(tester, 1500);
    await binding.takeScreenshot('z03_detail_kanji_evolution');

    // 動いているアニメーションを止めてから終わる（画面を空にする）
    await tester.pumpWidget(const SizedBox());
    await wait(tester, 300);
  });
}
