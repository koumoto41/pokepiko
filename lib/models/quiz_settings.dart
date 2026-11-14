import 'generation.dart';

/// 出題のしかた
enum QuizMode {
  illustration('イラスト'), // 公式イラスト
  pixel('ドット'), // ドット絵
  silhouette('シルエット'); // 公式イラストを黒く塗りつぶす

  final String label; // 画面に出す名前
  const QuizMode(this.label);
}

/// ゲームの設定
class QuizSettings {
  final QuizMode mode;
  final Set<int> generations; // 出題する世代の番号（1〜9、複数えらべる）

  const QuizSettings({
    this.mode = QuizMode.illustration,
    this.generations = const {1},
  });

  QuizSettings copyWith({QuizMode? mode, Set<int>? generations}) {
    return QuizSettings(
      mode: mode ?? this.mode,
      generations: generations ?? this.generations,
    );
  }

  /// 選んだ世代に含まれる図鑑番号をすべて並べたもの（出題の候補）
  List<int> get candidateIds => [
    for (final g in Generation.all)
      if (generations.contains(g.number)) ...g.ids,
  ];
}
