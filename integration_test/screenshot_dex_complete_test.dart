import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pokepiko/app_theme.dart';
import 'package:pokepiko/data/sound_service.dart';
import 'package:pokepiko/models/generation.dart';
import 'package:pokepiko/providers/sound_provider.dart';
import 'package:pokepiko/screens/dex_complete_screen.dart';

/// 図鑑かんせいの おめでとう画面のスクリーンショットを撮り、
/// タイプの相性の BGM とファンファーレが再生できるかを確かめる
/// （図鑑の記録は書きかえず、おめでとう画面だけを直接出す）
///
/// 動かし方:
///   flutter drive --driver=test_driver/integration_test.dart \
///     --target=integration_test/screenshot_dex_complete_test.dart -d <端末ID>
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> wait(WidgetTester tester, int ms) async {
    for (var t = 0; t < ms; t += 100) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// 音のファイルを再生できて、思ったくらいの長さか
  Future<void> expectPlayable(String path, Duration atLeast) async {
    final player = AudioPlayer();
    await player.play(AssetSource(path));
    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect(player.state, PlayerState.playing, reason: path);
    final duration = await player.getDuration();
    expect(duration, isNotNull, reason: path);
    expect(duration! >= atLeast, isTrue, reason: '$path: $duration');
    await player.dispose();
  }

  testWidgets('おめでとう画面と、新しい音', (tester) async {
    await SoundService.followSilentSwitch();
    await expectPlayable(Bgm.battle.path, const Duration(seconds: 22));
    await expectPlayable(DexCompleteScreen.jingle, const Duration(seconds: 12));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildAppTheme(),
          home: DexCompleteScreen(generations: [Generation.all.first]),
        ),
      ),
    );
    await wait(tester, 2500); // 絵の読み込みと、花火が上がるのを待つ
    await binding.takeScreenshot('d01_dex_complete');
    await wait(tester, 2000);
    await binding.takeScreenshot('d02_dex_complete_later');

    final container = ProviderScope.containerOf(
      tester.element(find.byType(DexCompleteScreen)),
    );
    await container.read(soundServiceProvider).stopJingle();
    await tester.pumpWidget(const SizedBox());
    await wait(tester, 9000); // 花火（8秒）が終わるのを待つ
  });
}
