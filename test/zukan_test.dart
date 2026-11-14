import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pokepiko/app_theme.dart';
import 'package:pokepiko/data/collection_store.dart';
import 'package:pokepiko/data/settings_store.dart';
import 'package:pokepiko/providers/collection_provider.dart';
import 'package:pokepiko/providers/data_providers.dart';
import 'package:pokepiko/providers/quiz_controller.dart';
import 'package:pokepiko/providers/settings_provider.dart';
import 'package:pokepiko/screens/zukan_detail_screen.dart';
import 'package:pokepiko/screens/zukan_screen.dart';

import 'fakes.dart';

void main() {
  group('あつめる（クイズで正解すると図鑑に入る）', () {
    late ProviderContainer container;
    late FakePokemonRepository repo;

    void setUpContainer() {
      repo = FakePokemonRepository();
      container = ProviderContainer(
        overrides: [pokemonRepositoryProvider.overrideWithValue(repo)],
      );
      container.listen(quizControllerProvider, (_, _) {});
    }

    QuizState read() => container.read(quizControllerProvider);

    Future<void> waitUntilAnswering(WidgetTester tester) async {
      for (var i = 0; i < 100 && read().status != QuizStatus.answering; i++) {
        await tester.pump();
      }
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

    Future<void> pumpApp(
      WidgetTester tester,
      Size size,
      Widget home, {
      Set<int> found = const {},
    }) async {
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
          ],
          child: MaterialApp(theme: buildAppTheme(), home: home),
        ),
      );
      // 保存済みの「みつけた」を読み込むまで待つ（本物の非同期処理なので runAsync）
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
    }

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
        expect(find.text('クイズで せいかいすると みつかるよ！'), findsOneWidget);
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
