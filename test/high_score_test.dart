import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pokepiko/data/high_score_store.dart';
import 'package:pokepiko/models/quiz_settings.dart';
import 'package:pokepiko/models/score.dart';
import 'package:pokepiko/providers/high_score_provider.dart';
import 'package:pokepiko/providers/sound_provider.dart';
import 'package:pokepiko/screens/result_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'bgm_observer_test.dart' show FakeSoundService;

/// メモリの中だけに保存する、偽のハイスコア保存係
class FakeHighScoreStore implements HighScoreStore {
  final Map<ScoreKey, int> saved = {};

  @override
  Future<int> read(QuizVariant variant, QuizMode mode) async =>
      saved[(variant, mode)] ?? 0;

  @override
  Future<void> write(QuizVariant variant, QuizMode mode, int score) async =>
      saved[(variant, mode)] = score;
}

void main() {
  late FakeHighScoreStore store;
  late ProviderContainer container;

  const namePixel = (QuizVariant.name, QuizMode.pixel);

  setUp(() {
    store = FakeHighScoreStore();
    container = ProviderContainer(
      overrides: [
        highScoreStoreProvider.overrideWithValue(store),
        soundServiceProvider.overrideWithValue(FakeSoundService()),
      ],
    );
  });
  tearDown(() => container.dispose());

  HighScoresController controller() =>
      container.read(highScoresProvider.notifier);

  test('はじめはどの区分も 0（クイズ4種類 × 画像3種類）', () async {
    final scores = await container.read(highScoresProvider.future);
    expect(scores.length, 12);
    expect(scores.values, everyElement(0));
  });

  test('前より多いときだけ更新して、保存する', () async {
    final c = controller();
    expect(await c.submit(QuizVariant.name, QuizMode.pixel, 5), isTrue);
    // 同じ点は更新しない
    expect(await c.submit(QuizVariant.name, QuizMode.pixel, 5), isFalse);
    expect(await c.submit(QuizVariant.name, QuizMode.pixel, 3), isFalse);
    expect(await c.submit(QuizVariant.name, QuizMode.pixel, 8), isTrue);

    expect(store.saved[namePixel], 8);
    expect((await container.read(highScoresProvider.future))[namePixel], 8);
  });

  test('クイズの種類・画像の見せかたごとに別々に記録する', () async {
    await controller().submit(
      QuizVariant.typeToPokemon,
      QuizMode.silhouette,
      7,
    );
    final scores = await container.read(highScoresProvider.future);
    expect(scores[(QuizVariant.typeToPokemon, QuizMode.silhouette)], 7);
    expect(scores[(QuizVariant.name, QuizMode.silhouette)], 0);
    expect(scores[(QuizVariant.pokemonToType, QuizMode.silhouette)], 0);
  });

  test('保存済みのハイスコアを、起動時に読み込む', () async {
    store.saved[(QuizVariant.pokemonToType, QuizMode.illustration)] = 9;
    final fresh = ProviderContainer(
      overrides: [highScoreStoreProvider.overrideWithValue(store)],
    );
    addTearDown(fresh.dispose);
    final scores = await fresh.read(highScoresProvider.future);
    expect(scores[(QuizVariant.pokemonToType, QuizMode.illustration)], 9);
  });

  test('以前の正解数の記録は読まず、点数は 0点から集め直す', () async {
    // 以前のバージョンが保存していた正解数（highScore.〜）
    final prefs = SharedPreferencesAsync();
    await prefs.setInt('highScore.silhouette', 6);
    await prefs.setInt('highScore.pokemonToType.pixel', 9);

    final real = HighScoreStore();
    expect(await real.read(QuizVariant.name, QuizMode.silhouette), 0);
    expect(await real.read(QuizVariant.pokemonToType, QuizMode.pixel), 0);

    // 点数は、クイズの種類・画像ごとに別々に保存される
    await real.write(QuizVariant.name, QuizMode.silhouette, 2450);
    expect(await real.read(QuizVariant.name, QuizMode.silhouette), 2450);
    expect(await real.read(QuizVariant.typeToPokemon, QuizMode.silhouette), 0);
  });

  group('結果画面', () {
    /// points：このゲームの点数
    Future<void> pumpResult(WidgetTester tester, int points) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: ResultScreen(
              variant: QuizVariant.name,
              mode: QuizMode.illustration,
              correctCount: 7,
              total: 10,
              wrongPokemons: const [],
              score: Score(correct: points),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    const key = (QuizVariant.name, QuizMode.illustration);

    testWidgets('ハイスコアを更新したら「ハイスコア こうしん！」を出す', (tester) async {
      store.saved[key] = 1200;
      await pumpResult(tester, 2450);
      expect(find.text('ハイスコア こうしん！'), findsOneWidget);
      expect(store.saved[key], 2450); // 正解数ではなく点数で記録する
    });

    testWidgets('更新しなかったら、いまのハイスコアを出す', (tester) async {
      store.saved[key] = 3000;
      await pumpResult(tester, 2450);
      expect(find.text('ハイスコア こうしん！'), findsNothing);
      expect(find.text('なまえ・イラストの ハイスコア：3000 てん'), findsOneWidget);
    });

    testWidgets('点数を大きく出し、正解数と内訳も出す', (tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ResultScreen(
              variant: QuizVariant.name,
              mode: QuizMode.illustration,
              correctCount: 10,
              total: 10,
              wrongPokemons: [],
              score: Score(
                correct: 1000,
                speed: 2500,
                combo: 700,
                perfect: 500,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 9)); // 全問正解のお祝いが終わるまで
      expect(find.textContaining('4700'), findsOneWidget);
      expect(find.text('10 もん中 10 もん せいかい'), findsOneWidget);
      expect(
        find.text('せいかい 1000・はやさ 2500・れんぞく 700・パーフェクト 500'),
        findsOneWidget,
      );
    });
  });
}
