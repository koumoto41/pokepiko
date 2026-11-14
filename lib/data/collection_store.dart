import 'package:shared_preferences/shared_preferences.dart';

/// 図鑑の「みつけた」ポケモン（クイズで正解したポケモン）の図鑑番号を、端末に保存する
class CollectionStore {
  final SharedPreferencesAsync _prefs = SharedPreferencesAsync();

  static const _key = 'collection.found';

  Future<Set<int>> read() async => {
    for (final s in await _prefs.getStringList(_key) ?? const <String>[])
      ?int.tryParse(s), // ?: 数字に変換できない（null の）ものは入れない
  };

  // shared_preferences は数字のリストを保存できないので、文字のリストにする
  Future<void> write(Set<int> ids) => _prefs.setStringList(_key, [
    for (final id in ids.toList()..sort()) '$id',
  ]);
}
