/// 世代ごとの全国図鑑番号の範囲
/// アプリに固定で持っておくので、オフラインでも世代を選べる
class Generation {
  final int number; // 第何世代か
  final int firstId; // 最初の図鑑番号
  final int lastId; // 最後の図鑑番号
  final String region; // 地方の名前（保護者向けの目安）
  final int mascotId; // 設定画面のタイルに出す、代表のポケモンの図鑑番号

  const Generation(
    this.number,
    this.firstId,
    this.lastId,
    this.region,
    this.mascotId,
  );

  /// この世代の図鑑番号をすべて並べたもの
  Iterable<int> get ids sync* {
    for (var id = firstId; id <= lastId; id++) {
      yield id;
    }
  }

  int get count => lastId - firstId + 1;

  /// 全国図鑑すべての図鑑番号
  static List<int> get allIds => [for (final g in all) ...g.ids];

  static const all = [
    Generation(1, 1, 151, 'カントー', 25), // ピカチュウ
    Generation(2, 152, 251, 'ジョウト', 158), // ワニノコ
    Generation(3, 252, 386, 'ホウエン', 255), // アチャモ
    Generation(4, 387, 493, 'シンオウ', 393), // ポッチャマ
    Generation(5, 494, 649, 'イッシュ', 495), // ツタージャ
    Generation(6, 650, 721, 'カロス', 656), // ケロマツ
    Generation(7, 722, 809, 'アローラ', 722), // モクロー
    Generation(8, 810, 905, 'ガラル', 813), // ヒバニー
    Generation(9, 906, 1025, 'パルデア', 906), // ニャオハ
  ];
}
