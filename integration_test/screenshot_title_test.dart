import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pokepiko/data/sound_service.dart';
import 'package:pokepiko/main.dart' as app;
import 'package:pokepiko/providers/sound_provider.dart';
import 'package:pokepiko/screens/widgets/title_decorations.dart';

/// タイトル画面の見た目（主役のポケモン・ロゴ・背景のシルエット）と、タイトルの曲を確かめる
///
/// 動かし方:
///   flutter drive --driver=test_driver/integration_test.dart \
///     --target=integration_test/screenshot_title_test.dart -d <端末ID>
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> wait(WidgetTester tester, int ms) async {
    for (var t = 0; t < ms; t += 100) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('タイトル画面', (tester) async {
    // タイトルの曲が、iPhone で読み込めて再生できるか
    final player = AudioPlayer();
    await player.play(AssetSource(Bgm.home.path));
    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect(player.state, PlayerState.playing);
    expect((await player.getDuration())!.inMilliseconds, greaterThan(25000));
    await player.dispose();

    await app.main();
    for (
      var i = 0;
      i < 100 && find.byType(FeaturedPokemon).evaluate().isEmpty;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await wait(tester, 3000); // 絵の読み込みを待つ
    await binding.takeScreenshot('h01_title');
    await wait(tester, 4000); // シルエットが動いたあと
    await binding.takeScreenshot('h02_title_later');

    // 主役のポケモンを押す（鳴き声）
    await tester.tap(find.byType(FeaturedPokemon));
    await wait(tester, 1500);

    // 鳴り続けている BGM を止めてから終わる
    await ProviderScope.containerOf(
      tester.element(find.byType(FeaturedPokemon)),
    ).read(soundServiceProvider).stopBgm();
    await tester.pumpWidget(const SizedBox());
    await wait(tester, 2000);
  });
}
