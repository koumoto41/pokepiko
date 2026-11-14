import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pokepiko/data/high_score_store.dart';
import 'package:pokepiko/models/quiz_settings.dart';
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

  test('はじめはどの区分も 0（クイズ3種類 × 画像3種類）', () async {
    final scores = await container.read(highScoresProvider.future);
    expect(scores.length, 9);
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

  test('タイプクイズ追加前の、なまえクイズのハイスコアを引き継ぐ', () async {
    // 以前のバージョンが保存していた名前（highScore.モード）
    await SharedPreferencesAsync().setInt('highScore.silhouette', 6);

    final real = HighScoreStore();
    expect(await real.read(QuizVariant.name, QuizMode.silhouette), 6);
    // タイプクイズは別の名前で保存するので、なまえクイズとまざらない
    expect(await real.read(QuizVariant.pokemonToType, QuizMode.silhouette), 0);
    await real.write(QuizVariant.pokemonToType, QuizMode.silhouette, 3);
    expect(await real.read(QuizVariant.name, QuizMode.silhouette), 6);
  });

  group('結果画面', () {
    Future<void> pumpResult(WidgetTester tester, int correct) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: ResultScreen(
              variant: QuizVariant.name,
              mode: QuizMode.illustration,
              correctCount: correct,
              total: 10,
              wrongPokemons: const [],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    const key = (QuizVariant.name, QuizMode.illustration);

    testWidgets('ハイスコアを更新したら「ハイスコア こうしん！」を出す', (tester) async {
      store.saved[key] = 4;
      await pumpResult(tester, 6);
      expect(find.text('ハイスコア こうしん！'), findsOneWidget);
      expect(store.saved[key], 6);
    });

    testWidgets('更新しなかったら、いまのハイスコアを出す', (tester) async {
      store.saved[key] = 8;
      await pumpResult(tester, 6);
      expect(find.text('ハイスコア こうしん！'), findsNothing);
      expect(find.text('なまえ・イラストの ハイスコア：8 もん'), findsOneWidget);
    });
  });
}
