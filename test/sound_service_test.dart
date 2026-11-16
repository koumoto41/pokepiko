import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokepiko/data/sound_service.dart';

void main() {
  test('iPhone では、マナーモードで鳴らない設定（ambient）にする', () {
    // iPhone のつもりで設定を作る
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    final ios = SoundService.silentSwitchAwareContext.iOS;
    // playback（何もしないときの設定）だと、マナーモードでも鳴ってしまう
    expect(ios.category, AVAudioSessionCategory.ambient);
    // mixWithOthers などのオプションはつけない（ambient では使えない組み合わせがある）
    expect(ios.options, isEmpty);
  });
}
