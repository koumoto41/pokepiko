import 'package:shared_preferences/shared_preferences.dart';

import '../models/quiz_settings.dart';

/// ハイスコア（クイズの種類 × 画像の見せかた ごとの最高点）を端末に保存する
/// shared_preferences: 数字や文字など小さな値を「名前 → 値」で保存できる
class HighScoreStore {
  final SharedPreferencesAsync _prefs = SharedPreferencesAsync();

  // 保存するときの名前（例: score.name.silhouette）
  // 以前は正解数（0〜10）を highScore.〜 に保存していた。点数とは比べられないので、
  // 名前を変えて 0点から集め直す（以前の記録は読まない）
  String _key(QuizVariant variant, QuizMode mode) =>
      'score.${variant.name}.${mode.name}';

  /// まだ遊んでいない組み合わせは 0
  Future<int> read(QuizVariant variant, QuizMode mode) async =>
      await _prefs.getInt(_key(variant, mode)) ?? 0;

  Future<void> write(QuizVariant variant, QuizMode mode, int score) =>
      _prefs.setInt(_key(variant, mode), score);
}
