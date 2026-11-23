import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pokepiko/app_theme.dart';
import 'package:pokepiko/data/collection_store.dart';
import 'package:pokepiko/models/generation.dart';
import 'package:pokepiko/models/pokemon.dart';
import 'package:pokepiko/models/quiz_settings.dart';
import 'package:pokepiko/providers/data_providers.dart';
import 'package:pokepiko/providers/high_score_provider.dart';
import 'package:pokepiko/providers/sound_provider.dart';
import 'package:pokepiko/screens/dex_complete_screen.dart';
import 'package:pokepiko/screens/result_screen.dart';
import 'package:pokepiko/screens/zukan_screen.dart';

import 'bgm_observer_test.dart' show FakeSoundService;
import 'fakes.dart';
import 'high_score_test.dart' show FakeHighScoreStore;

/// 図鑑かんせい（ある世代のポケモンを ぜんぶ みつけた）の おめでとう画面
/// おめでとう画面は光と花火がずっと動くので、pumpAndSettle は使わず、時間を決めて進める
void main() {
  const sizes = {
    'iPhone SE': Size(375, 667),
    'iPhone 18 Pro Max': Size(440, 956),
  };
  final kanto = Generation.all.first.ids.toSet(); // 第1世代の151匹

  late FakeSoundService sound;

  /// found：「みつけた」にしておく図鑑番号
  Future<void> pumpApp(
    WidgetTester tester,
    Widget home, {
    required Set<int> found,
    Size size = const Size(375, 667),
  }) async {
    sound = FakeSoundService();
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await CollectionStore().write(found);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pokemonRepositoryProvider.overrideWithValue(
            FakePokemonRepository()..imagesFail = true,
          ),
          soundServiceProvider.overrideWithValue(sound),
          highScoreStoreProvider.overrideWithValue(FakeHighScoreStore()),
        ],
        child: MaterialApp(theme: buildAppTheme(), home: home),
      ),
    );
    // 保存済みの記録を読み込むまで待つ（本物の非同期処理なので runAsync）
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
    }
  }

  /// 画面の切りかわりが終わるまで進める
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// 動き続けるアニメーションを片づけて終わる
  Future<void> cleanUp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
  }

  group('図鑑を開いたとき', () {
    for (final MapEntry(key: name, value: size) in sizes.entries) {
      testWidgets('$name: 世代がうまっていたら、おめでとう画面を出す（1回だけ）', (tester) async {
        await pumpApp(tester, const ZukanScreen(), found: kanto, size: size);
        await settle(tester);
        expect(find.byType(DexCompleteScreen), findsOneWidget);
        expect(find.text('おめでとう！'), findsOneWidget);
        expect(find.text('カントー ずかん\nかんせい！'), findsOneWidget);
        expect(find.text('151 ひき ぜんぶ みつけたよ！'), findsOneWidget);
        expect(sound.jingle, DexCompleteScreen.jingle);

        // 「やったね！」で図鑑に戻り、ファンファーレも止まる
        await tester.tap(find.text('やったね！'));
        await settle(tester);
        expect(find.byType(DexCompleteScreen), findsNothing);
        expect(sound.jingle, isNull);

        // もう一度図鑑を開いても、同じお祝いは出ない
        await tester.pumpWidget(const SizedBox());
        await pumpApp(tester, const ZukanScreen(), found: kanto, size: size);
        await settle(tester);
        expect(find.byType(DexCompleteScreen), findsNothing);
        expect(sound.jingles, isEmpty);
        await cleanUp(tester);
      });
    }

    testWidgets('1匹でも足りなければ出さない', (tester) async {
      await pumpApp(
        tester,
        const ZukanScreen(),
        found: kanto.difference({151}),
      );
      await settle(tester);
      expect(find.byType(DexCompleteScreen), findsNothing);
      await cleanUp(tester);
    });

    testWidgets('全世代がうまったら「ぜんこく ずかん」', (tester) async {
      await pumpApp(
        tester,
        const ZukanScreen(),
        found: Generation.allIds.toSet(),
      );
      await settle(tester);
      expect(find.text('ぜんこく ずかん\nかんせい！'), findsOneWidget);
      expect(find.text('1025 ひき ぜんぶ みつけたよ！'), findsOneWidget);
      await cleanUp(tester);
    });
  });

  group('結果画面から', () {
    Widget result({int newlyFound = 1, List<Pokemon> legends = const []}) =>
        ResultScreen(
          variant: QuizVariant.name,
          mode: QuizMode.silhouette,
          correctCount: 10,
          total: 10,
          wrongPokemons: const [],
          newlyFound: newlyFound,
          legendsFound: legends,
        );

    testWidgets('最後の1匹をみつけたら、結果を少し見せてから おめでとう画面', (tester) async {
      await pumpApp(tester, result(), found: kanto);
      await tester.pump(const Duration(milliseconds: 1000));
      expect(find.byType(DexCompleteScreen), findsNothing);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await settle(tester);
      expect(find.byType(DexCompleteScreen), findsOneWidget);
      expect(sound.jingles, [
        'se/result_perfect.wav',
        DexCompleteScreen.jingle,
      ]);
      await cleanUp(tester);
    });

    testWidgets('伝説・幻のお祝いを閉じてから、おめでとう画面', (tester) async {
      await pumpApp(
        tester,
        result(legends: const [Pokemon(id: 151, name: 'ミュウ')]),
        found: kanto,
      );
      await tester.pump(const Duration(milliseconds: 1600));
      await settle(tester);
      expect(find.text('まぼろしの ポケモンを\nみつけた！'), findsOneWidget);
      expect(find.byType(DexCompleteScreen), findsNothing);

      await tester.tap(find.text('やったね！'));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await settle(tester);
      expect(find.byType(DexCompleteScreen), findsOneWidget);
      await cleanUp(tester);
    });

    testWidgets('図鑑に増えていないゲームでは調べない', (tester) async {
      await pumpApp(tester, result(newlyFound: 0), found: kanto);
      await tester.pump(const Duration(seconds: 2));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await settle(tester);
      expect(find.byType(DexCompleteScreen), findsNothing);
      await cleanUp(tester);
    });
  });
}
