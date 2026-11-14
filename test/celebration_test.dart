import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pokepiko/app_theme.dart';
import 'package:pokepiko/models/pokemon.dart';
import 'package:pokepiko/models/quiz_settings.dart';
import 'package:pokepiko/providers/data_providers.dart';
import 'package:pokepiko/providers/high_score_provider.dart';
import 'package:pokepiko/providers/sound_provider.dart';
import 'package:pokepiko/screens/result_screen.dart';
import 'package:pokepiko/screens/widgets/celebration.dart';

import 'bgm_observer_test.dart' show FakeSoundService;
import 'fakes.dart';
import 'high_score_test.dart' show FakeHighScoreStore;

/// 全問正解のお祝い（花火と風船）
void main() {
  late FakeSoundService sound;

  Future<void> pumpResult(
    WidgetTester tester,
    int correct, {
    bool disableAnimations = false,
    Size size = const Size(375, 667), // iPhone SE
  }) async {
    sound = FakeSoundService();
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pokemonRepositoryProvider.overrideWithValue(
            FakePokemonRepository()..imagesFail = true,
          ),
          highScoreStoreProvider.overrideWithValue(FakeHighScoreStore()),
          soundServiceProvider.overrideWithValue(sound),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          // 「動きを減らす」の設定をまねる
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(disableAnimations: disableAnimations),
            child: child!,
          ),
          home: ResultScreen(
            variant: QuizVariant.name,
            mode: QuizMode.silhouette,
            correctCount: correct,
            total: 10,
            wrongPokemons: [
              for (var i = 0; i < 10 - correct; i++)
                Pokemon(id: i + 1, name: 'P${i + 1}'),
            ],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
  }

  /// お祝いの絵が描かれているか
  Finder painting() => find.descendant(
    of: find.byType(Celebration),
    matching: find.byType(CustomPaint),
  );

  testWidgets('全問正解のときだけ、花火と風船が出る', (tester) async {
    await pumpResult(tester, 10);
    expect(find.byType(Celebration), findsOneWidget);
    expect(painting(), findsOneWidget);
    expect(find.text('かんぺき！ ポケモン マスターだね！'), findsOneWidget);
  });

  for (final correct in [9, 0]) {
    testWidgets('$correct問正解では出ない', (tester) async {
      await pumpResult(tester, correct);
      expect(find.byType(Celebration), findsNothing);
    });
  }

  testWidgets('約8秒で消える', (tester) async {
    await pumpResult(tester, 10);
    await tester.pump(const Duration(seconds: 4));
    expect(painting(), findsOneWidget); // まだ出ている
    await tester.pump(Celebration.duration);
    expect(painting(), findsNothing); // 終わった
  });

  testWidgets('お祝いの最中でも、下のボタンは押せる', (tester) async {
    await pumpResult(tester, 10);
    // お祝いの絵は、タップを受け取らない（下の画面に通す）
    final ignore = tester.widget<IgnorePointer>(
      find
          .descendant(
            of: find.byType(Celebration),
            matching: find.byType(IgnorePointer),
          )
          .first,
    );
    expect(ignore.ignoring, isTrue);
    // 「もういちど」の場所をタップしたとき、届く先にそのボタンがある
    final center = tester.getCenter(find.text('もういちど'));
    final hits = tester.hitTestOnBinding(center).path.map((e) => e.target);
    final button = tester.renderObject(find.text('もういちど'));
    expect(hits, contains(button));
  });

  testWidgets('「動きを減らす」の設定では出さない', (tester) async {
    await pumpResult(tester, 10, disableAnimations: true);
    expect(painting(), findsNothing);
  });

  testWidgets('大きい画面でも、はみ出さずに描ける', (tester) async {
    await pumpResult(tester, 10, size: const Size(440, 956));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(tester.takeException(), isNull);
  });

  group('結果画面の曲', () {
    for (final (correct, jingle) in [
      (10, 'se/result_perfect.wav'),
      (9, 'se/result_great.wav'),
      (8, 'se/result_great.wav'),
      (7, 'se/result_good.wav'),
      (5, 'se/result_good.wav'),
      (4, 'se/result_try.wav'),
      (0, 'se/result_try.wav'),
    ]) {
      testWidgets('$correct問正解で $jingle を1回鳴らす', (tester) async {
        await pumpResult(tester, correct);
        expect(sound.jingles, [jingle]);
        if (correct == 10) await tester.pump(Celebration.duration);
      });
    }

    test('どの段の曲のファイルも、assets にある', () {
      for (final rank in ResultRank.values) {
        expect(
          File('assets/${rank.jingle}').existsSync(),
          isTrue,
          reason: rank.jingle,
        );
      }
    });
  });
}
