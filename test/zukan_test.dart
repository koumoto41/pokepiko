import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pokepiko/app_theme.dart';
import 'package:pokepiko/data/collection_store.dart';
import 'package:pokepiko/data/settings_store.dart';
import 'package:pokepiko/models/quiz_settings.dart';
import 'package:pokepiko/providers/collection_provider.dart';
import 'package:pokepiko/providers/data_providers.dart';
import 'package:pokepiko/providers/quiz_controller.dart';
import 'package:pokepiko/providers/settings_provider.dart';
import 'package:pokepiko/providers/sound_provider.dart';
import 'package:pokepiko/screens/zukan_detail_screen.dart';
import 'package:pokepiko/screens/widgets/cached_image.dart';
import 'package:pokepiko/screens/widgets/trimmed_sprite.dart';
import 'package:pokepiko/screens/zukan_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'bgm_observer_test.dart' show FakeSoundService;
import 'fakes.dart';

void main() {
  group('あつめる（シルエットのクイズで正解すると図鑑に入る）', () {
    late ProviderContainer container;
    late FakePokemonRepository repo;

    /// settings：遊ぶクイズの設定（ふつうはシルエットのなまえクイズ）
    void setUpContainer({
      QuizSettings settings = const QuizSettings(mode: QuizMode.silhouette),
    }) {
      repo = FakePokemonRepository();
      container = ProviderContainer(
        overrides: [
          pokemonRepositoryProvider.overrideWithValue(repo),
          initialSettingsProvider.overrideWithValue(settings),
        ],
      );
      container.listen(quizControllerProvider, (_, _) {});
    }

    QuizState read() => container.read(quizControllerProvider);

    Future<void> waitUntilAnswering(WidgetTester tester) async {
      for (var i = 0; i < 100 && read().status != QuizStatus.answering; i++) {
        await tester.pump();
      }
    }

    /// 1問目に正解して、図鑑の記録を返す
    Future<Set<int>> answerFirstCorrectly(WidgetTester tester) async {
      await waitUntilAnswering(tester);
      container
          .read(quizControllerProvider.notifier)
          .answer(read().current!.correctIndex);
      await tester.pump();
      return container.read(collectionProvider.future);
    }

    testWidgets('正解したポケモンだけ図鑑に入り、はじめてなら newlyFound にも入る', (tester) async {
      setUpContainer();
      await waitUntilAnswering(tester);
      final first = read().current!;
      container
          .read(quizControllerProvider.notifier)
          .answer(first.correctIndex);
      await tester.pump();

      await tester.pump(const Duration(seconds: 1));
      await waitUntilAnswering(tester);
      final second = read().current!;
      container
          .read(quizControllerProvider.notifier)
          .answer((second.correctIndex + 1) % 4); // わざと間違える
      await tester.pump();

      final found = await container.read(collectionProvider.future);
      expect(found, {first.pokemon.id});
      expect(read().newlyFound.map((p) => p.id), [first.pokemon.id]);
      // 図鑑のくわしいページも、裏で保存されている
      expect(repo.savedDex, contains(first.pokemon.id));
      container.dispose();
    });

    for (final mode in [QuizMode.illustration, QuizMode.pixel]) {
      testWidgets('${mode.label}のクイズで正解しても、図鑑には入らない', (tester) async {
        setUpContainer(settings: QuizSettings(mode: mode));
        expect(await answerFirstCorrectly(tester), isEmpty);
        expect(read().isCorrect, isTrue);
        expect(read().newlyFound, isEmpty);
        container.dispose();
      });
    }

    testWidgets('タイプクイズでも、シルエットなら図鑑に入る', (tester) async {
      setUpContainer(
        settings: const QuizSettings(
          mode: QuizMode.silhouette,
          kind: QuizKind.type,
          typeDirection: TypeDirection.typeToPokemon,
        ),
      );
      final pokemon = (await (() async {
        await waitUntilAnswering(tester);
        return read().current!.pokemon;
      })());
      expect(await answerFirstCorrectly(tester), {pokemon.id});
      container.dispose();
    });

    test('以前の記録（どのクイズでも入っていたころ）は消して、からっぽから集め直す', () async {
      await SharedPreferencesAsync().setStringList('collection.found', [
        '1',
        '4',
      ]);
      final c = ProviderContainer();
      addTearDown(c.dispose);
      expect(await c.read(collectionProvider.future), isEmpty);
      expect(
        await SharedPreferencesAsync().getStringList('collection.found'),
        isNull,
      );
    });

    test('みつけたポケモンは端末に残り、2回目は「はじめて」にならない', () async {
      final c1 = ProviderContainer();
      addTearDown(c1.dispose);
      expect(await c1.read(collectionProvider.notifier).add(25), isTrue);
      expect(await c1.read(collectionProvider.notifier).add(25), isFalse);

      expect(await CollectionStore().read(), {25});
      // アプリを起動し直したつもり
      final c2 = ProviderContainer();
      addTearDown(c2.dispose);
      expect(await c2.read(collectionProvider.future), {25});
    });

    test('説明文の「かんじ」の切りかえも保存される', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      c.read(settingsProvider.notifier).setDexKanji(true);
      await pumpEventQueue();
      expect((await SettingsStore().read()).dexKanji, isTrue);
    });
  });

  group('図鑑の画面', () {
    const sizes = {
      'iPhone SE': Size(375, 667),
      'iPhone 18 Pro Max': Size(440, 956),
    };

    late FakeSoundService sound;

    /// savedDex：図鑑データ（進化の情報）を保存済みにしておく図鑑番号
    Future<void> pumpApp(
      WidgetTester tester,
      Size size,
      Widget home, {
      Set<int> found = const {},
      Set<int> savedDex = const {},
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
              FakePokemonRepository()
                ..imagesFail = true
                ..savedDex.addAll(savedDex),
            ),
            soundServiceProvider.overrideWithValue(sound),
          ],
          child: MaterialApp(theme: buildAppTheme(), home: home),
        ),
      );
      // 保存済みの「みつけた」を読み込むまで待つ（本物の非同期処理なので runAsync）
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
    }

    group('でんせつ・まぼろしの札', () {
      testWidgets('一覧：みつけた伝説・幻に札が出る（ふつうのポケモンには出ない）', (tester) async {
        // 150 ミュウツー（伝説）・151 ミュウ（幻）・149 カイリュー（ふつう）
        await pumpApp(
          tester,
          sizes['iPhone SE']!,
          const ZukanScreen(),
          found: {149, 150, 151},
          // 一覧の下のほうなので、みつけた だけにして見えるところに並べる
        );
        await tester.tap(find.text('みつけた だけ'));
        await tester.pumpAndSettle();
        expect(find.text('でんせつ'), findsOneWidget);
        expect(find.text('まぼろし'), findsOneWidget);
      });

      testWidgets('くわしいページ：タイプの横に札が出る', (tester) async {
        await pumpApp(
          tester,
          sizes['iPhone SE']!,
          const ZukanDetailScreen(id: 151),
          found: {151},
        );
        expect(find.text('まぼろし'), findsOneWidget);
      });
    });

    group('くわしいページの絵', () {
      String shownUrl(WidgetTester tester) {
        // いま画面のまん中に見えている絵の URL
        final images = tester.widgetList<CachedImage>(find.byType(CachedImage));
        final center = tester.getCenter(find.byType(PageView));
        return images
            .firstWhere(
              (w) => tester
                  .getRect(find.byWidget(w))
                  .contains(Offset(center.dx, center.dy)),
            )
            .url;
      }

      testWidgets('イラストとドット絵を、スワイプで切りかえる', (tester) async {
        await pumpApp(
          tester,
          sizes['iPhone SE']!,
          const ZukanDetailScreen(id: 4),
          found: {4},
        );
        expect(shownUrl(tester), 'https://example.com/art/4.png');
        expect(find.text('イラスト'), findsOneWidget);
        expect(find.text('ドット'), findsOneWidget);

        // 左にスワイプすると、ドット絵（ぼかさずに表示）
        await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
        await tester.pumpAndSettle();
        // ドット絵は、余白を切りとって大きく表示する部品で出す
        final dot = tester.widget<TrimmedSprite>(find.byType(TrimmedSprite));
        expect(dot.url, 'https://example.com/dot/4.png');
        expect(
          tester
              .getRect(find.byType(TrimmedSprite))
              .contains(tester.getCenter(find.byType(PageView))),
          isTrue,
        );

        // 「イラスト」を押すと、イラストに戻る
        await tester.tap(find.text('イラスト'));
        await tester.pumpAndSettle();
        expect(shownUrl(tester), 'https://example.com/art/4.png');
      });

      testWidgets('ドット絵がないポケモンは、イラストだけ', (tester) async {
        await pumpApp(
          tester,
          sizes['iPhone SE']!,
          const ZukanDetailScreen(id: 7),
          found: {7},
        );
        expect(find.text('ドット'), findsNothing);
        expect(
          find.descendant(
            of: find.byType(PageView),
            matching: find.byType(CachedImage),
          ),
          findsOneWidget,
        );
      });
    });

    // 偽の窓口では、番号 n のポケモンは n → n+1 に進化する（4 と 5 で仲間がそろう）
    group('進化の仲間がそろったとき', () {
      testWidgets('図鑑を開くと、新しくそろった仲間をお祝いする（1回だけ）', (tester) async {
        await pumpApp(
          tester,
          sizes['iPhone SE']!,
          const ZukanScreen(),
          found: {4, 5, 10},
          savedDex: {4, 5, 10},
        );
        expect(find.text('コンプリート！'), findsOneWidget);
        expect(find.text('しんかの なかまが\nぜんぶ そろったよ！'), findsOneWidget);
        expect(sound.jingles, ['se/result_great.wav']);
        await tester.tap(find.text('やったね！'));
        await tester.pumpAndSettle();
        expect(find.text('コンプリート！'), findsNothing);

        // そろった仲間のマスには王冠がつく（10 は 11 がいないので、つかない）
        expect(find.byIcon(Icons.emoji_events), findsNWidgets(2));

        // もう一度図鑑を開いても、同じお祝いは出ない
        await tester.pumpWidget(const SizedBox());
        await pumpApp(
          tester,
          sizes['iPhone SE']!,
          const ZukanScreen(),
          found: {4, 5, 10},
          savedDex: {4, 5, 10},
        );
        expect(find.text('コンプリート！'), findsNothing);
        expect(sound.jingles, isEmpty);
      });

      testWidgets('進化の情報を保存していない仲間は、まだ数えない', (tester) async {
        await pumpApp(
          tester,
          sizes['iPhone SE']!,
          const ZukanScreen(),
          found: {4, 5},
        );
        expect(find.text('コンプリート！'), findsNothing);
      });

      testWidgets('くわしいページの進化の欄に「コンプリート！」が出る', (tester) async {
        await pumpApp(
          tester,
          sizes['iPhone SE']!,
          const ZukanDetailScreen(id: 4),
          found: {4, 5},
        );
        // 進化の欄はページの下のほうなので、見えるまでスクロールする
        await tester.scrollUntilVisible(
          find.text('しんか'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('コンプリート！'), findsOneWidget);
      });

      testWidgets('仲間がそろっていなければ、くわしいページにも出ない', (tester) async {
        await pumpApp(
          tester,
          sizes['iPhone SE']!,
          const ZukanDetailScreen(id: 4),
          found: {4},
        );
        expect(find.text('コンプリート！'), findsNothing);
      });
    });

    testWidgets('「みつけた だけ」をオンにすると、みつけたポケモンだけ並ぶ', (tester) async {
      await pumpApp(
        tester,
        sizes['iPhone SE']!,
        const ZukanScreen(),
        found: {1, 4, 152},
      );
      expect(find.text('No.0002'), findsOneWidget); // オフのときは全部並ぶ

      await tester.tap(find.text('みつけた だけ'));
      await tester.pumpAndSettle();
      expect(find.text('P1'), findsOneWidget);
      expect(find.text('P4'), findsOneWidget);
      expect(find.text('No.0002'), findsNothing); // まだのポケモンは出ない
      expect(find.text('？'), findsNothing);

      // 第3世代は1匹もいないので、さがそうと案内する
      // 世代のボタンの列は横にスクロールするので、見える位置まで動かしてから押す
      await tester.ensureVisible(find.text('3 ホウエン'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('3 ホウエン'));
      await tester.pumpAndSettle();
      expect(find.textContaining('まだ みつけていないよ'), findsOneWidget);

      // オフに戻すと、また全部並ぶ
      await tester.tap(find.text('みつけた だけ'));
      await tester.pumpAndSettle();
      expect(find.text('No.0252'), findsOneWidget);
    });

    testWidgets('はじめは、みつけたポケモンがいる いちばん若い世代を見せる', (tester) async {
      await pumpApp(
        tester,
        sizes['iPhone SE']!,
        const ZukanScreen(),
        found: {152, 300},
      );
      expect(find.text('このせだい：1 / 100 ひき'), findsOneWidget); // 第2世代
      expect(find.text('P152'), findsOneWidget);
    });

    for (final MapEntry(key: name, value: size) in sizes.entries) {
      testWidgets('$name: 一覧は、みつけたポケモンだけ名前が出る', (tester) async {
        await pumpApp(tester, size, const ZukanScreen(), found: {1, 4});
        expect(find.text('このせだい：2 / 151 ひき'), findsOneWidget);
        expect(find.text('P1'), findsOneWidget); // 偽の窓口の名前は「P番号」
        expect(find.text('P4'), findsOneWidget);
        expect(find.text('P2'), findsNothing); // まだみつけていない
        expect(find.text('？'), findsWidgets);

        // 「？」のマスを押すと、クイズでみつけようと案内する

        await tester.tap(find.text('No.0002'));
        await tester.pump();
        expect(find.text('シルエットクイズで せいかいすると みつかるよ！'), findsOneWidget);
      });

      testWidgets('$name: くわしいページ（ひらがな／かんじ・進化）', (tester) async {
        await pumpApp(
          tester,
          size,
          const ZukanDetailScreen(id: 4),
          found: {4, 5},
        );
        expect(find.text('P4'), findsWidgets);
        expect(find.text('なきごえ'), findsOneWidget);
        expect(find.text('テストポケモン'), findsOneWidget);
        expect(find.text('0.4 m'), findsOneWidget);
        expect(find.text('ひらがなの せつめい 4'), findsOneWidget);

        // かんじ に切りかえる
        await tester.ensureVisible(find.text('かんじ'));
        await tester.tap(find.text('かんじ'));
        await tester.pumpAndSettle();
        expect(find.text('漢字の説明 4'), findsOneWidget);
        expect(find.text('試験ポケモン'), findsOneWidget);

        // 進化の仲間（5番）を押すと、そのページに移る
        await tester.ensureVisible(find.text('P5'));
        await tester.tap(find.text('P5'));
        await tester.pumpAndSettle();
        expect(find.text('No.0005'), findsOneWidget);
        expect(find.text('漢字の説明 5'), findsOneWidget);
      });
    }
  });
}
