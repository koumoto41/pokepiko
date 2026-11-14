import 'package:shared_preferences/shared_preferences.dart';

import '../models/quiz_settings.dart';

/// ハイスコア（クイズの種類 × 画像の見せかた ごとの最高正解数）を端末に保存する
/// shared_preferences: 数字や文字など小さな値を「名前 → 値」で保存できる
class HighScoreStore {
  final SharedPreferencesAsync _prefs = SharedPreferencesAsync();

  // 保存するときの名前
  // なまえクイズは、タイプクイズを追加する前と同じ名前（例: highScore.silhouette）にして、
  // それまでのハイスコアを引き継ぐ
  String _key(QuizVariant variant, QuizMode mode) => switch (variant) {
    QuizVariant.name => 'highScore.${mode.name}',
    _ => 'highScore.${variant.name}.${mode.name}',
  };

  /// まだ遊んでいない組み合わせは 0
  Future<int> read(QuizVariant variant, QuizMode mode) async =>
      await _prefs.getInt(_key(variant, mode)) ?? 0;

  Future<void> write(QuizVariant variant, QuizMode mode, int score) =>
      _prefs.setInt(_key(variant, mode), score);
}
