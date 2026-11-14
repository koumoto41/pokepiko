/// 点数（ハイスコアに使う）の計算
///
/// 1問ごと：
/// - せいかい：正解で 100点
/// - はやさ  ：残り秒数 × 10点（最大 300点）
/// - れんぞく：2問以上つづけて正解すると (連続数 − 1) × 20点（最大 100点）
/// ゲームの最後：全問正解なら パーフェクト 500点
/// 間違い・時間切れは 0点で、連続も切れる
class Score {
  static const correctPoints = 100;
  static const pointsPerSecond = 10;
  static const maxSpeedPoints = 300;
  static const pointsPerCombo = 20;
  static const maxComboPoints = 100;
  static const perfectPoints = 500;

  final int correct; // せいかい の合計
  final int speed; // はやさ の合計
  final int combo; // れんぞく の合計
  final int perfect; // パーフェクト（0 か 500）

  const Score({
    this.correct = 0,
    this.speed = 0,
    this.combo = 0,
    this.perfect = 0,
  });

  int get total => correct + speed + combo + perfect;

  /// 正解した1問ぶんの点数（remainingSeconds：答えたときの残り秒数、streak：これで何問連続か）
  static Score forAnswer({required int remainingSeconds, required int streak}) {
    final speed = remainingSeconds * pointsPerSecond;
    final combo = (streak - 1) * pointsPerCombo;
    return Score(
      correct: correctPoints,
      speed: speed.clamp(0, maxSpeedPoints),
      combo: combo.clamp(0, maxComboPoints),
    );
  }

  /// 2つの点数を足す
  Score operator +(Score other) => Score(
    correct: correct + other.correct,
    speed: speed + other.speed,
    combo: combo + other.combo,
    perfect: perfect + other.perfect,
  );
}
