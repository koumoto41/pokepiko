import 'poke_type.dart';

/// クイズに使うポケモン1匹分のデータ
class Pokemon {
  final int id; // 全国図鑑番号
  final String name; // カタカナの名前
  final String? artworkUrl; // 公式イラストのURL
  final String? spriteUrl; // ドット絵のURL（無いポケモンもいるので null 可）
  final List<PokeType> types; // タイプ（1つか2つ）

  const Pokemon({
    required this.id,
    required this.name,
    this.artworkUrl,
    this.spriteUrl,
    this.types = const [],
  });

  /// 端末に保存するための JSON 形式（必要な項目だけ）
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'artworkUrl': artworkUrl,
    'spriteUrl': spriteUrl,
    'types': [for (final t in types) t.name],
  };

  /// 保存した JSON から戻す
  factory Pokemon.fromJson(Map<String, dynamic> json) {
    // タイプクイズを追加する前に保存したデータには types が無い。
    // そのときは「壊れたデータ」として扱い、API から取り直してもらう（画像は取り直さない）
    final types = json['types'];
    if (types is! List) {
      throw const FormatException('types がない古いデータ');
    }
    return Pokemon(
      id: json['id'] as int,
      name: json['name'] as String,
      artworkUrl: json['artworkUrl'] as String?,
      spriteUrl: json['spriteUrl'] as String?,
      types: [
        // ?: 知らないタイプ（null）は入れない
        for (final t in types) ?PokeType.fromApiName(t as String),
      ],
    );
  }

  /// このポケモンの画像のURL（あるものだけ）
  List<String> get imageUrls => [?artworkUrl, ?spriteUrl];
}
