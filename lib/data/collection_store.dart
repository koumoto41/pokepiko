import 'package:shared_preferences/shared_preferences.dart';

/// 図鑑の「みつけた」ポケモン（シルエットのクイズで正解したポケモン）の図鑑番号を、端末に保存する
class CollectionStore {
  final SharedPreferencesAsync _prefs = SharedPreferencesAsync();

  static const _key = 'collection.silhouette';

  // 以前は、どのクイズで正解しても図鑑に入っていた（保存名 collection.found）。
  // 「シルエットで正解したときだけ」に変えたので、以前の記録は消して、からっぽから集め直す
  static const _oldKey = 'collection.found';

  Future<Set<int>> read() async {
    await _prefs.remove(_oldKey);
    return {
      for (final s in await _prefs.getStringList(_key) ?? const <String>[])
        ?int.tryParse(s), // ?: 数字に変換できない（null の）ものは入れない
    };
  }

  static const _announcedKey = 'collection.announcedFamilies';

  /// 「しんかの なかまが そろった」とお知らせ済みの仲間（例："1,2,3"）
  Future<Set<String>> readAnnouncedFamilies() async => {
    ...?await _prefs.getStringList(_announcedKey),
  };

  Future<void> writeAnnouncedFamilies(Set<String> keys) =>
      _prefs.setStringList(_announcedKey, keys.toList()..sort());

  // shared_preferences は数字のリストを保存できないので、文字のリストにする
  Future<void> write(Set<int> ids) => _prefs.setStringList(_key, [
    for (final id in ids.toList()..sort()) '$id',
  ]);
}
