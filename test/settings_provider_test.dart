import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokepiko/models/generation.dart';
import 'package:pokepiko/providers/settings_provider.dart';

void main() {
  late ProviderContainer container;
  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  SettingsController controller() => container.read(settingsProvider.notifier);
  Set<int> generations() => container.read(settingsProvider).generations;

  test('最初は第1世代（151ひき）', () {
    expect(generations(), {1});
    expect(container.read(settingsProvider).candidateIds.length, 151);
  });

  test('世代は複数えらべて、最後の1つは外せない', () {
    controller().toggleGeneration(2);
    expect(generations(), {1, 2});
    controller().toggleGeneration(1);
    expect(generations(), {2});
    controller().toggleGeneration(2); // 最後の1つなので外れない
    expect(generations(), {2});
  });

  test('「ぜんぶ」で全国図鑑すべて、もう一度押すと第1世代に戻る', () {
    controller().toggleAllGenerations();
    expect(generations().length, Generation.all.length);
    expect(container.read(settingsProvider).candidateIds.length, 1025);
    controller().toggleAllGenerations();
    expect(generations(), {1});
  });

  test('代表のポケモンは、その世代の図鑑番号の範囲に入っている', () {
    for (final g in Generation.all) {
      expect(g.mascotId, inInclusiveRange(g.firstId, g.lastId));
    }
  });
}
