import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pokepiko/app_theme.dart';
import 'package:pokepiko/data/collection_store.dart';
import 'package:pokepiko/models/generation.dart';
import 'package:pokepiko/providers/data_providers.dart';
import 'package:pokepiko/providers/high_score_provider.dart';
import 'package:pokepiko/providers/sound_provider.dart';
import 'package:pokepiko/screens/title_screen.dart';
import 'package:pokepiko/screens/widgets/title_decorations.dart';

import 'bgm_observer_test.dart' show FakeSoundService;
import 'fakes.dart';
import 'high_score_test.dart' show FakeHighScoreStore;

void main() {
  Future<void> pumpTitle(
    WidgetTester tester, {
    Set<int> found = const {},
    bool disableAnimations = false,
  }) async {
    tester.view.physicalSize = const Size(375, 667); // iPhone SE
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await CollectionStore().write(found);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pokemonRepositoryProvider.overrideWithValue(
            FakePokemonRepository()..imagesFail = true,
          ),
          soundServiceProvider.overrideWithValue(FakeSoundService()),
          highScoreStoreProvider.overrideWithValue(FakeHighScoreStore()),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(disableAnimations: disableAnimations),
            child: child!,
          ),
          home: const TitleScreen(),
        ),
      ),
    );
    // 図鑑の記録を読み込むまで待つ（本物の非同期処理なので runAsync）
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    // 主役が決まる → 名前を読み込む → 表示する、の順に進める
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  int featuredId(WidgetTester tester) =>
      tester.widget<FeaturedPokemon>(find.byType(FeaturedPokemon)).id;

  testWidgets('主役のポケモンは、図鑑でみつけたポケモンから選ぶ', (tester) async {
    await pumpTitle(tester, found: {4, 5});
    expect(featuredId(tester), isIn([4, 5]));
    expect(find.byType(FloatingSilhouettes), findsOneWidget);
    expect(find.byType(TitleLogo), findsOneWidget);
  });

  testWidgets('まだ1匹もみつけていなければ、代表の9匹から選ぶ', (tester) async {
    await pumpTitle(tester);
    expect(
      featuredId(tester),
      isIn([for (final g in Generation.all) g.mascotId]),
    );
  });

  testWidgets('主役のポケモンは、ふわふわ動き、名前も出る', (tester) async {
    await pumpTitle(tester, found: {4});
    Offset position() => tester.getTopLeft(find.text('P4')); // 偽の窓口の名前は「P番号」
    final before = position();
    await tester.pump(const Duration(milliseconds: 800));
    expect(position(), isNot(before));
  });

  testWidgets('「動きを減らす」の設定では、主役も背景も動かない', (tester) async {
    await pumpTitle(tester, found: {4}, disableAnimations: true);
    final before = tester.getTopLeft(find.text('P4'));
    await tester.pump(const Duration(milliseconds: 800));
    expect(tester.getTopLeft(find.text('P4')), before);
    // 動き続けるものがないので、pumpAndSettle も終わる
    await tester.pumpAndSettle();
  });
}
