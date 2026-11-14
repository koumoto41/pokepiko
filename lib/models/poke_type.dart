import 'dart:ui' show Color;

/// ポケモンのタイプ（18種類）
/// 日本語名と色はアプリに持っておくので、オフラインでも使える
enum PokeType {
  normal('ノーマル', Color(0xFF9E9E8E)),
  fire('ほのお', Color(0xFFEF6C2B)),
  water('みず', Color(0xFF3D8BEA)),
  grass('くさ', Color(0xFF4CAF50)),
  electric('でんき', Color(0xFFF2C21B)),
  ice('こおり', Color(0xFF4FC3D9)),
  fighting('かくとう', Color(0xFFD35400)),
  poison('どく', Color(0xFF9C4DCC)),
  ground('じめん', Color(0xFFB7863B)),
  flying('ひこう', Color(0xFF7FA6EC)),
  psychic('エスパー', Color(0xFFEC5B8D)),
  bug('むし', Color(0xFF8DA82B)),
  rock('いわ', Color(0xFFAE9A5A)),
  ghost('ゴースト', Color(0xFF6A5ACD)),
  dragon('ドラゴン', Color(0xFF5468D4)),
  dark('あく', Color(0xFF5D4E46)),
  steel('はがね', Color(0xFF7E9AAE)),
  fairy('フェアリー', Color(0xFFE88BD8));

  final String label; // 画面に出す日本語名
  final Color color; // ボタンなどの色

  const PokeType(this.label, this.color);

  /// PokéAPI の名前（fire など）から変換する。知らない名前は null
  /// （API には stellar・unknown・shadow もあるが、ふつうのポケモンのタイプではないので使わない）
  static PokeType? fromApiName(String name) => values.asNameMap()[name];
}
