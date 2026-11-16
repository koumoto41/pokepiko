import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pokepiko/data/sound_service.dart';
import 'package:pokepiko/main.dart' as app;
import 'package:pokepiko/providers/data_providers.dart';
import 'package:pokepiko/providers/sound_provider.dart';

/// マナーモードに従う音の設定（ambient）にしたあとも、マナーモードでなければ
/// BGM と鳴き声がふつうに再生できるかを確かめる
/// （シミュレーターにはマナーモードのスイッチがないので、鳴らない側は実機で確かめる）
///
/// 動かし方:
///   flutter drive --driver=test_driver/integration_test.dart \
///     --target=integration_test/audio_session_test.dart -d <端末ID>
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('マナーモードに従う設定でも、音を再生できる', (tester) async {
    await app.main(); // ここで SoundService.followSilentSwitch() が呼ばれる
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // BGM（audioplayers）
    final player = AudioPlayer();
    await player.play(AssetSource(Bgm.home.path));
    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect(player.state, PlayerState.playing);
    await player.dispose();

    // 鳴き声（flutter_soloud。音の設定はアプリに任せている）
    final container = ProviderScope.containerOf(
      tester.element(find.text('はじめる')),
    );
    final cry = await container.read(pokemonRepositoryProvider).getCry(25);
    await SoLoud.instance.init();
    final source = await SoLoud.instance.loadFile(cry!.path);
    final handle = SoLoud.instance.play(source);
    expect(SoLoud.instance.getIsValidVoiceHandle(handle), isTrue);

    await container.read(soundServiceProvider).stopBgm();
    await tester.pumpWidget(const SizedBox());
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  });
}
