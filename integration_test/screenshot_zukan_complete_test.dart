import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pokepiko/data/cache_store.dart';
import 'package:pokepiko/data/collection_store.dart';
import 'package:pokepiko/data/poke_api_client.dart';
import 'package:pokepiko/data/pokemon_repository.dart';
import 'package:pokepiko/data/sound_service.dart';
import 'package:pokepiko/main.dart' as app;
import 'package:pokepiko/providers/sound_provider.dart';

/// 進化の仲間（フシギダネ・フシギソウ・フシギバナ）がそろったときのお祝いと、図鑑の曲を確かめる
///
/// 動かし方:
///   flutter drive --driver=test_driver/integration_test.dart \
///     --target=integration_test/screenshot_zukan_complete_test.dart -d <端末ID>
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> waitFor(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 300 && finder.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(finder, findsWidgets);
  }

  Future<void> wait(WidgetTester tester, int ms) async {
    for (var t = 0; t < ms; t += 100) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('進化の仲間がそろったお祝い', (tester) async {
    // --- 図鑑の曲が、iPhone で読み込めて再生できるか ---
    final player = AudioPlayer();
    await player.play(AssetSource(Bgm.zukan.path));
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final length = await player.getDuration();
    expect(player.state, PlayerState.playing);
    expect(length!.inMilliseconds, greaterThan(14000));
    await player.dispose();

    // --- 1〜3番を「みつけた」ことにして、図鑑データを本物の API から保存しておく ---
    final repo = PokemonRepository(api: PokeApiClient(), cache: CacheStore());
    for (final id in [1, 2, 3]) {
      await repo.downloadImages(await repo.getPokemon(id));
      await repo.downloadDex(id);
    }
    final store = CollectionStore();
    await store.write({1, 2, 3});
    await store.writeAnnouncedFamilies({}); // まだお知らせしていないことにする

    await app.main();
    await waitFor(tester, find.text('ずかん'));
    await wait(tester, 500);
    await tester.tap(find.text('ずかん'));
    await waitFor(tester, find.text('やったね！'));
    await wait(tester, 2000); // 絵の読み込みを待つ
    await binding.takeScreenshot('f01_complete_dialog');

    await tester.tap(find.text('やったね！'));
    await wait(tester, 1500);
    await binding.takeScreenshot('f02_list_crown');

    await tester.tap(find.text('No.0001'));
    await wait(tester, 2500);
    await tester.drag(find.byType(ListView).first, const Offset(0, -900));
    await wait(tester, 1500);
    await binding.takeScreenshot('f03_detail_complete');

    // 鳴り続けている BGM（再生位置を見張る処理が残る）を止めてから終わる
    await ProviderScope.containerOf(tester.element(find.text('しんか')))
        .read(soundServiceProvider)
        .stopBgm();
    await tester.pumpWidget(const SizedBox());
    await wait(tester, 2000);
  });
}
