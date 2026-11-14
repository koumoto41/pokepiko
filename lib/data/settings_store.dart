import 'package:shared_preferences/shared_preferences.dart';

import '../models/generation.dart';
import '../models/quiz_settings.dart';

/// 前回の設定（モード・世代）を端末に保存する
class SettingsStore {
  final SharedPreferencesAsync _prefs = SharedPreferencesAsync();

  static const _modeKey = 'settings.mode';
  static const _generationsKey = 'settings.generations';
  static const _kindKey = 'settings.kind';
  static const _typeDirectionKey = 'settings.typeDirection';

  /// 保存した設定を読む（初めてのときや、読めない値のときはふつうの設定）
  Future<QuizSettings> read() async {
    const defaults = QuizSettings();
    final modeName = await _prefs.getString(_modeKey);
    final saved = await _prefs.getStringList(_generationsKey);
    final kindName = await _prefs.getString(_kindKey);
    final directionName = await _prefs.getString(_typeDirectionKey);

    // アプリを更新して世代やモードが変わっても困らないよう、知っている値だけ使う
    final validNumbers = {for (final g in Generation.all) g.number};
    final generations = {
      for (final s in saved ?? const <String>[])
        if (int.tryParse(s) case final n? when validNumbers.contains(n)) n,
    };

    return QuizSettings(
      mode: QuizMode.values.asNameMap()[modeName] ?? defaults.mode,
      generations: generations.isEmpty ? defaults.generations : generations,
      kind: QuizKind.values.asNameMap()[kindName] ?? defaults.kind,
      typeDirection:
          TypeDirection.values.asNameMap()[directionName] ??
          defaults.typeDirection,
    );
  }

  Future<void> write(QuizSettings settings) async {
    await _prefs.setString(_modeKey, settings.mode.name);
    await _prefs.setString(_kindKey, settings.kind.name);
    await _prefs.setString(_typeDirectionKey, settings.typeDirection.name);
    // shared_preferences は数字のリストを保存できないので、文字のリストにする
    await _prefs.setStringList(_generationsKey, [
      for (final n in settings.generations.toList()..sort()) '$n',
    ]);
  }
}
