import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pokepiko/models/pokemon.dart';
import 'package:pokepiko/models/quiz_settings.dart';
import 'package:pokepiko/providers/data_providers.dart';
import 'package:pokepiko/screens/widgets/cached_image.dart';
import 'package:pokepiko/screens/widgets/pokemon_image.dart';

import 'fakes.dart';

// 画像そのものは読み込まない（偽の窓口でずっと読み込み中）が、
// 「どのURLを表示しようとしたか」と「黒塗りされているか」は確かめられる
void main() {
  const pikachu = Pokemon(
    id: 25,
    name: 'ピカチュウ',
    artworkUrl: 'https://example.com/art.png',
    spriteUrl: 'https://example.com/dot.png',
  );

  Future<void> pump(
    WidgetTester tester,
    QuizMode mode, {
    Pokemon pokemon = pikachu,
    bool revealed = false,
  }) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [
          pokemonRepositoryProvider.overrideWithValue(FakePokemonRepository()),
        ],
        child: MaterialApp(
          home: PokemonImage(pokemon: pokemon, mode: mode, revealed: revealed),
        ),
      ),
    );
  }

  String shownUrl(WidgetTester tester) =>
      tester.widget<CachedImage>(find.byType(CachedImage)).url;

  testWidgets('イラストモードは公式イラストを表示する', (tester) async {
    await pump(tester, QuizMode.illustration);
    expect(shownUrl(tester), pikachu.artworkUrl);
    expect(find.byType(ColorFiltered), findsNothing);
  });

  testWidgets('ドットモードはドット絵を表示する', (tester) async {
    await pump(tester, QuizMode.pixel);
    expect(shownUrl(tester), pikachu.spriteUrl);
  });

  testWidgets('シルエットモードはイラストを黒塗りし、答えたら色つきに戻る', (tester) async {
    await pump(tester, QuizMode.silhouette);
    expect(shownUrl(tester), pikachu.artworkUrl);
    expect(find.byType(ColorFiltered), findsOneWidget);

    await pump(tester, QuizMode.silhouette, revealed: true);
    expect(find.byType(ColorFiltered), findsNothing);
  });

  testWidgets('ドット絵が無いポケモンは、ドットモードでもイラストを出す', (tester) async {
    const artOnly = Pokemon(
      id: 1000,
      name: 'テスト',
      artworkUrl: 'https://example.com/art.png',
    );
    await pump(tester, QuizMode.pixel, pokemon: artOnly);
    expect(shownUrl(tester), artOnly.artworkUrl);
  });
}
