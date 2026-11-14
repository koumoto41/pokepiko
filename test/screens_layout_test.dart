import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pokepiko/app_theme.dart';
import 'package:pokepiko/models/pokemon.dart';
import 'package:pokepiko/models/quiz_settings.dart';
import 'package:pokepiko/providers/data_providers.dart';
import 'package:pokepiko/providers/high_score_provider.dart';
import 'package:pokepiko/providers/quiz_controller.dart';
import 'package:pokepiko/providers/sound_provider.dart';
import 'package:pokepiko/screens/quiz_screen.dart';
import 'package:pokepiko/screens/result_screen.dart';
import 'package:pokepiko/screens/settings_screen.dart';
import 'package:pokepiko/screens/title_screen.dart';
import 'package:pokepiko/screens/widgets/answer_effect.dart';
import 'package:pokepiko/screens/widgets/choice_button.dart';

import 'bgm_observer_test.dart' show FakeSoundService;
import 'fakes.dart';
import 'high_score_test.dart' show FakeHighScoreStore;

/// いろいろな画面サイズで、はみ出し（黄色と黒のしましま）が出ないかを確かめる
void main() {
  const sizes = {
    'iPhone SE': Size(375, 667),
    'iPhone 18 Pro Max': Size(440, 956),
  };

  Widget app(Widget home) => ProviderScope(
    overrides: [
      pokemonRepositoryProvider.overrideWithValue(
        FakePokemonRepository()..imagesFail = true,
      ),
      soundServiceProvider.overrideWithValue(FakeSoundService()),
      highScoreStoreProvider.overrideWithValue(FakeHighScoreStore()),
    ],
    child: MaterialApp(theme: buildAppTheme(), home: home),
  );

  void setSize(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  for (final MapEntry(key: name, value: size) in sizes.entries) {
    testWidgets('$name: クイズ画面で答えると、演出が出てボタンの色が変わる', (tester) async {
      setSize(tester, size);
      await tester.pumpWidget(app(const QuizScreen()));
      await tester.pump();
      await tester.pump();

      expect(find.byType(ChoiceButton), findsNWidgets(4));
      expect(find.byType(ProgressDots), findsOneWidget);

      // 正解のボタンを探して押す
      final container = ProviderScope.containerOf(
        tester.element(find.byType(QuizScreen)),
      );
      final answer = container.read(quizControllerProvider).current!.answer;
      await tester.tap(find.text(answer.name));
      await tester.pump();

      expect(find.byType(AnswerEffect), findsOneWidget);
      expect(find.text('せいかい！'), findsOneWidget);
      final looks = tester
          .widgetList<ChoiceButton>(find.byType(ChoiceButton))
          .map((b) => b.look);
      expect(looks.where((l) => l == ChoiceLook.correct).length, 1);
      expect(looks.where((l) => l == ChoiceLook.faded).length, 3);

      // 演出が終わるまで進めて、次の問題へ
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(find.byType(AnswerEffect), findsNothing);
      expect(container.read(quizControllerProvider).results, [true]);

      // 画面を閉じて、タイマーを止める
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('$name: 結果画面（全問正解・たくさん間違い）', (tester) async {
      setSize(tester, size);
      for (final wrong in [0, 10]) {
        await tester.pumpWidget(
          app(
            ResultScreen(
              mode: QuizMode.illustration,
              correctCount: 10 - wrong,
              total: 10,
              wrongPokemons: [
                for (var i = 0; i < wrong; i++)
                  Pokemon(id: i + 1, name: 'ポケモン${i + 1}'),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('もういちど'), findsOneWidget);
      }
    });
  }

  for (final MapEntry(key: name, value: size) in sizes.entries) {
    testWidgets('$name: タイトル画面・設定画面', (tester) async {
      setSize(tester, size);
      await tester.pumpWidget(app(const TitleScreen()));
      await tester.pumpAndSettle();
      expect(find.text('はじめる'), findsOneWidget);
      expect(find.text('ハイスコア'), findsOneWidget);

      await tester.pumpWidget(app(const SettingsScreen()));
      await tester.pumpAndSettle();
      expect(find.text('スタート！'), findsOneWidget);
    });
  }

  test('星の数：9問以上で3つ、5問以上で2つ、それ以外も1つはもらえる', () {
    expect(ResultScreen.starsFor(10, 10), 3);
    expect(ResultScreen.starsFor(9, 10), 3);
    expect(ResultScreen.starsFor(8, 10), 2);
    expect(ResultScreen.starsFor(5, 10), 2);
    expect(ResultScreen.starsFor(4, 10), 1);
    expect(ResultScreen.starsFor(0, 10), 1);
  });
}
