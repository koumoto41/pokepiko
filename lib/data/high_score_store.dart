import 'package:shared_preferences/shared_preferences.dart';

import '../models/quiz_settings.dart';

/// ハイスコア（モードごとの最高正解数）を端末に保存する
/// shared_preferences: 数字や文字など小さな値を「名前 → 値」で保存できる
class HighScoreStore {
  final SharedPreferencesAsync _prefs = SharedPreferencesAsync();

  // 保存するときの名前（例: highScore.silhouette）
  String _key(QuizMode mode) => 'highScore.${mode.name}';

  /// まだ遊んでいないモードは 0
  Future<int> read(QuizMode mode) async => await _prefs.getInt(_key(mode)) ?? 0;

  Future<void> write(QuizMode mode, int score) =>
      _prefs.setInt(_key(mode), score);
}
