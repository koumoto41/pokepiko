import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pokepiko/app_theme.dart';
import 'package:pokepiko/models/pokemon.dart';
import 'package:pokepiko/models/quiz_settings.dart';
import 'package:pokepiko/providers/data_providers.dart';
import 'package:pokepiko/providers/high_score_provider.dart';
import 'package:pokepiko/providers/quiz_controller.dart';
import 'package:pokepiko/providers/settings_provider.dart';
import 'package:pokepiko/providers/sound_provider.dart';
import 'package:pokepiko/screens/quiz_screen.dart';
import 'package:pokepiko/screens/result_screen.dart';
import 'package:pokepiko/screens/settings_screen.dart';
import 'package:pokepiko/screens/title_screen.dart';
import 'package:pokepiko/screens/widgets/answer_effect.dart';
import 'package:pokepiko/screens/widgets/choice_button.dart';
import 'package:pokepiko/screens/widgets/image_choice.dart';
import 'package:pokepiko/screens/widgets/type_badge.dart';

import 'bgm_observer_test.dart' show FakeSoundService;
import 'fakes.dart';
import 'high_score_test.dart' show FakeHighScoreStore;

/// いろいろな画面サイズで、はみ出し（黄色と黒のしましま）が出ないかを確かめる
void main() {
  const sizes = {
    'iPhone SE': Size(375, 667),
    'iPhone 18 Pro Max': Size(440, 956),
  };

  /// settings：はじめの設定（クイズの種類などを変えたいとき）
  Widget app(Widget home, {QuizSettings settings = const QuizSettings()}) =>
      ProviderScope(
        overrides: [
          initialSettingsProvider.overrideWithValue(settings),
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
      final answer = container.read(quizControllerProvider).current!.pokemon;
      await tester.tap(find.text(answer.name));
      await tester.pump();

      expect(find.byType(AnswerEffect), findsOneWidget);
      expect(find.text('せいかい！'), findsOneWidget);
      // すぐ答えたので、せいかい100＋はやさ300 の点数がぴょこっと出る
      expect(find.text('+400'), findsOneWidget);
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
              // タイプクイズのときは、カードにタイプも出る
              variant: QuizVariant.pokemonToType,
              mode: QuizMode.illustration,
              correctCount: 10 - wrong,
              total: 10,
              wrongPokemons: [
                for (var i = 0; i < wrong; i++)
                  Pokemon(
                    id: i + 1,
                    name: 'ポケモン${i + 1}',
                    types: FakePokemonRepository.typesOf(i + 1),
                  ),
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
    testWidgets('$name: ポケモン→タイプ（タイプの色のボタンで答える）', (tester) async {
      setSize(tester, size);
      await tester.pumpWidget(
        app(
          const QuizScreen(),
          settings: const QuizSettings(kind: QuizKind.type),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('このポケモンの タイプは？'), findsOneWidget);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(QuizScreen)),
      );
      final q = container.read(quizControllerProvider).current!;
      final buttons = tester
          .widgetList<ChoiceButton>(find.byType(ChoiceButton))
          .toList();
      // ボタンの文字と色は、そのタイプの日本語名と色
      for (final (i, t) in q.typeChoices.indexed) {
        expect(buttons[i].label, t.label);
        expect(buttons[i].color, t.color);
      }

      await tester.tap(find.text(q.typeChoices[q.correctIndex].label));
      await tester.pump();
      expect(container.read(quizControllerProvider).isCorrect, isTrue);
      expect(find.byType(AnswerEffect), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('$name: タイプ→ポケモン（4匹の絵から選ぶ）', (tester) async {
      setSize(tester, size);
      await tester.pumpWidget(
        app(
          const QuizScreen(),
          settings: const QuizSettings(
            kind: QuizKind.type,
            typeDirection: TypeDirection.typeToPokemon,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('このタイプの ポケモンは？'), findsOneWidget);
      expect(find.byType(ImageChoice), findsNWidgets(4));

      final container = ProviderScope.containerOf(
        tester.element(find.byType(QuizScreen)),
      );
      final q = container.read(quizControllerProvider).current!;
      // 聞いているタイプが、大きなラベルで出ている
      expect(
        tester.widget<TypeBadge>(find.byType(TypeBadge)).type,
        q.askedType,
      );
      // 答える前は名前を出さない（絵だけで選ぶ）
      expect(find.text(q.pokemon.name), findsNothing);

      // まちがいの絵を押す
      final wrong = (q.correctIndex + 1) % 4;
      await tester.tap(find.byType(ImageChoice).at(wrong));
      await tester.pump();
      expect(container.read(quizControllerProvider).isCorrect, isFalse);
      // 答えたあとは、正解の名前が絵の下とメッセージに出る
      expect(find.textContaining(q.pokemon.name), findsWidgets);
      await tester.pumpWidget(const SizedBox());
    });

    for (final mode in [QuizMode.illustration, QuizMode.silhouette]) {
      testWidgets('$name: あいしょう・${mode.label}（2匹から勝つほうを選ぶ）', (tester) async {
        setSize(tester, size);
        await tester.pumpWidget(
          app(
            const QuizScreen(),
            settings: QuizSettings(kind: QuizKind.matchup, mode: mode),
          ),
        );
        await tester.pump();
        await tester.pump();
        expect(find.text('あいしょうで かつのは どっち？'), findsOneWidget);
        expect(find.byType(ImageChoice), findsNWidgets(2));
        expect(find.text('VS'), findsOneWidget);
        // シルエットのときは、答える前はタイプも出さない（影だけで考える）
        final silhouette = mode == QuizMode.silhouette;
        expect(find.byType(TypeBadges), findsNWidgets(silhouette ? 0 : 2));

        final container = ProviderScope.containerOf(
          tester.element(find.byType(QuizScreen)),
        );
        final q = container.read(quizControllerProvider).current!;
        await tester.tap(find.byType(ImageChoice).at(q.correctIndex));
        await tester.pump();
        expect(container.read(quizControllerProvider).isCorrect, isTrue);
        // 答えたあとは、タイプと勝つ理由を見せる
        expect(find.byType(TypeBadges), findsNWidgets(2));
        expect(
          find.text('せいかい！ ${q.reason!.$1.label}は ${q.reason!.$2.label}に つよい'),
          findsOneWidget,
        );
        await tester.pumpWidget(const SizedBox());
      });
    }

    testWidgets('$name: タイトル画面・設定画面', (tester) async {
      setSize(tester, size);
      await tester.pumpWidget(app(const TitleScreen()));
      // タイトル画面はずっと動き続けるので、決まった時間だけ進める
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('はじめる'), findsOneWidget);
      expect(find.text('ハイスコア'), findsOneWidget);

      await tester.pumpWidget(app(const SettingsScreen()));
      await tester.pumpAndSettle();
      expect(find.text('スタート！'), findsOneWidget);
      // なまえクイズのときは、問題の向きの段は出ない
      expect(find.text('ポケモン→タイプ'), findsNothing);
      await tester.tap(find.text('タイプクイズ'));
      await tester.pumpAndSettle();
      expect(find.text('ポケモン→タイプ'), findsOneWidget);
      expect(find.text('タイプ→ポケモン'), findsOneWidget);

      // でんせつクイズを選ぶと、世代は押せなくなり、全世代から出ると案内する
      await tester.tap(find.text('でんせつクイズ'));
      await tester.pumpAndSettle();
      expect(find.textContaining('ぜんぶの せだいから でるよ'), findsOneWidget);
      expect(
        tester
            .widgetList<IgnorePointer>(find.byType(IgnorePointer))
            .any((w) => w.ignoring),
        isTrue,
      );

      await tester.tap(find.text('あいしょうクイズ'));
      await tester.pumpAndSettle();
      expect(find.text('ポケモン→タイプ'), findsNothing);
    });
  }

  test('正解数でメッセージが4段階に変わる（全問／8〜9／5〜7／0〜4）', () {
    ResultRank rank(int correct) => ResultRank.of(correct, 10);

    expect(rank(10), ResultRank.perfect);
    expect(rank(10).message, 'かんぺき！ ポケモン マスターだね！');
    for (final n in [9, 8]) {
      expect(rank(n), ResultRank.great);
    }
    for (final n in [7, 6, 5]) {
      expect(rank(n), ResultRank.good);
    }
    for (final n in [4, 3, 2, 1, 0]) {
      expect(rank(n), ResultRank.tryAgain);
    }
    // 星：全問と8〜9問は3つ、5〜7問は2つ、0〜4問も1つはもらえる
    expect([for (final r in ResultRank.values) r.stars], [3, 3, 2, 1]);
  });
}
