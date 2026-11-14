import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pokepiko/data/high_score_store.dart';
import 'package:pokepiko/models/quiz_settings.dart';
import 'package:pokepiko/providers/high_score_provider.dart';
import 'package:pokepiko/screens/result_screen.dart';

/// メモリの中だけに保存する、偽のハイスコア保存係
class FakeHighScoreStore implements HighScoreStore {
  final Map<QuizMode, int> saved = {};

  @override
  Future<int> read(QuizMode mode) async => saved[mode] ?? 0;

  @override
  Future<void> write(QuizMode mode, int score) async => saved[mode] = score;
}

void main() {
  late FakeHighScoreStore store;
  late ProviderContainer container;

  setUp(() {
    store = FakeHighScoreStore();
    container = ProviderContainer(
      overrides: [highScoreStoreProvider.overrideWithValue(store)],
    );
  });
  tearDown(() => container.dispose());

  HighScoresController controller() =>
      container.read(highScoresProvider.notifier);

  test('はじめはどのモードも 0', () async {
    final scores = await container.read(highScoresProvider.future);
    expect(scores, {for (final m in QuizMode.values) m: 0});
  });

  test('前より多いときだけ更新して、保存する', () async {
    expect(await controller().submit(QuizMode.pixel, 5), isTrue);
    expect(await controller().submit(QuizMode.pixel, 5), isFalse); // 同じ点は更新しない
    expect(await controller().submit(QuizMode.pixel, 3), isFalse);
    expect(await controller().submit(QuizMode.pixel, 8), isTrue);

    expect(store.saved[QuizMode.pixel], 8);
    expect(
      (await container.read(highScoresProvider.future))[QuizMode.pixel],
      8,
    );
  });

  test('モードごとに別々に記録する', () async {
    await controller().submit(QuizMode.silhouette, 7);
    final scores = await container.read(highScoresProvider.future);
    expect(scores[QuizMode.silhouette], 7);
    expect(scores[QuizMode.illustration], 0);
  });

  test('保存済みのハイスコアを、起動時に読み込む', () async {
    store.saved[QuizMode.illustration] = 9;
    final fresh = ProviderContainer(
      overrides: [highScoreStoreProvider.overrideWithValue(store)],
    );
    addTearDown(fresh.dispose);
    final scores = await fresh.read(highScoresProvider.future);
    expect(scores[QuizMode.illustration], 9);
  });

  group('結果画面', () {
    Future<void> pumpResult(WidgetTester tester, int correct) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: ResultScreen(
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

    testWidgets('ハイスコアを更新したら「ハイスコア こうしん！」を出す', (tester) async {
      store.saved[QuizMode.illustration] = 4;
      await pumpResult(tester, 6);
      expect(find.text('ハイスコア こうしん！'), findsOneWidget);
      expect(store.saved[QuizMode.illustration], 6);
    });

    testWidgets('更新しなかったら、いまのハイスコアを出す', (tester) async {
      store.saved[QuizMode.illustration] = 8;
      await pumpResult(tester, 6);
      expect(find.text('ハイスコア こうしん！'), findsNothing);
      expect(find.text('イラストの ハイスコア：8 もん'), findsOneWidget);
    });
  });
}
