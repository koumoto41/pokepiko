/// 図鑑の「くわしいページ」に出すデータ（名前・画像・タイプは Pokemon のほうにある）
class DexEntry {
  final int id; // 全国図鑑番号
  final String? genusKana; // 分類（ひらがな・カタカナ版）例：ねずみポケモン
  final String? genusKanji; // 分類（漢字版）
  final String? flavorKana; // 図鑑の説明文（ひらがな版）。無いポケモンもいる
  final String? flavorKanji; // 図鑑の説明文（漢字版）
  final int heightDm; // 高さ（API の単位はデシメートル）
  final int weightHg; // 重さ（API の単位はヘクトグラム）
  final String? cryUrl; // 鳴き声の音声ファイルの URL

  /// 進化のつながり。段階ごとの図鑑番号（例：[[172], [25], [26]]）
  /// イーブイのように枝分かれすると、1つの段階に何匹も入る
  final List<List<int>> evolution;

  const DexEntry({
    required this.id,
    this.genusKana,
    this.genusKanji,
    this.flavorKana,
    this.flavorKanji,
    required this.heightDm,
    required this.weightHg,
    this.cryUrl,
    this.evolution = const [],
  });

  /// 表示用の高さ・重さ（例：0.4 m、6.0 kg）
  String get heightText => '${(heightDm / 10).toStringAsFixed(1)} m';
  String get weightText => '${(weightHg / 10).toStringAsFixed(1)} kg';

  Map<String, dynamic> toJson() => {
    'id': id,
    'genusKana': genusKana,
    'genusKanji': genusKanji,
    'flavorKana': flavorKana,
    'flavorKanji': flavorKanji,
    'heightDm': heightDm,
    'weightHg': weightHg,
    'cryUrl': cryUrl,
    'evolution': evolution,
  };

  factory DexEntry.fromJson(Map<String, dynamic> json) => DexEntry(
    id: json['id'] as int,
    genusKana: json['genusKana'] as String?,
    genusKanji: json['genusKanji'] as String?,
    flavorKana: json['flavorKana'] as String?,
    flavorKanji: json['flavorKanji'] as String?,
    heightDm: json['heightDm'] as int,
    weightHg: json['weightHg'] as int,
    cryUrl: json['cryUrl'] as String?,
    evolution: [
      for (final stage in json['evolution'] as List<dynamic>)
        [for (final id in stage as List<dynamic>) id as int],
    ],
  );
}
