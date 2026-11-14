/// クイズに使うポケモン1匹分のデータ
class Pokemon {
  final int id; // 全国図鑑番号
  final String name; // カタカナの名前
  final String? artworkUrl; // 公式イラストのURL
  final String? spriteUrl; // ドット絵のURL（無いポケモンもいるので null 可）

  const Pokemon({
    required this.id,
    required this.name,
    this.artworkUrl,
    this.spriteUrl,
  });

  /// 端末に保存するための JSON 形式（必要な項目だけ）
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'artworkUrl': artworkUrl,
    'spriteUrl': spriteUrl,
  };

  /// 保存した JSON から戻す
  factory Pokemon.fromJson(Map<String, dynamic> json) => Pokemon(
    id: json['id'] as int,
    name: json['name'] as String,
    artworkUrl: json['artworkUrl'] as String?,
    spriteUrl: json['spriteUrl'] as String?,
  );

  /// このポケモンの画像のURL（あるものだけ）
  List<String> get imageUrls => [?artworkUrl, ?spriteUrl];
}
