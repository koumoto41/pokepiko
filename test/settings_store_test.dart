import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokepiko/data/settings_store.dart';
import 'package:pokepiko/models/quiz_settings.dart';
import 'package:pokepiko/providers/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('はじめて起動したときは、第1世代・イラスト', () async {
    final settings = await SettingsStore().read();
    expect(settings.mode, QuizMode.illustration);
    expect(settings.generations, {1});
  });

  test('保存した設定を、そのまま読み戻せる', () async {
    await SettingsStore().write(
      const QuizSettings(mode: QuizMode.silhouette, generations: {9, 2, 5}),
    );
    final settings = await SettingsStore().read();
    expect(settings.mode, QuizMode.silhouette);
    expect(settings.generations, {2, 5, 9});
  });

  test('クイズの種類と、タイプクイズの向きも保存される', () async {
    await SettingsStore().write(
      const QuizSettings(
        kind: QuizKind.type,
        typeDirection: TypeDirection.typeToPokemon,
      ),
    );
    final settings = await SettingsStore().read();
    expect(settings.kind, QuizKind.type);
    expect(settings.typeDirection, TypeDirection.typeToPokemon);
    expect(settings.variant, QuizVariant.typeToPokemon);
  });

  test('タイプクイズ追加前に保存した設定は、なまえクイズとして読む', () async {
    final prefs = SharedPreferencesAsync();
    await prefs.setString('settings.mode', 'pixel'); // kind は保存されていない
    final settings = await SettingsStore().read();
    expect(settings.mode, QuizMode.pixel);
    expect(settings.kind, QuizKind.name);
  });

  test('知らない値が保存されていたら、ふつうの設定にもどす', () async {
    final prefs = SharedPreferencesAsync();
    await prefs.setString('settings.mode', 'nazo');
    await prefs.setStringList('settings.generations', ['0', '99', 'abc']);

    final settings = await SettingsStore().read();
    expect(settings.mode, QuizMode.illustration);
    expect(settings.generations, {1});
  });

  test('設定を変えると保存され、次に起動したときにその設定で始まる', () async {
    final first = ProviderContainer();
    addTearDown(first.dispose);
    first.read(settingsProvider.notifier)
      ..setMode(QuizMode.pixel)
      ..toggleGeneration(4);
    await pumpEventQueue(); // 保存が終わるのを待つ

    // アプリを起動し直したつもり（main.dart と同じ読み方）
    final saved = await SettingsStore().read();
    final second = ProviderContainer(
      overrides: [initialSettingsProvider.overrideWithValue(saved)],
    );
    addTearDown(second.dispose);
    final settings = second.read(settingsProvider);
    expect(settings.mode, QuizMode.pixel);
    expect(settings.generations, {1, 4});
  });
}
