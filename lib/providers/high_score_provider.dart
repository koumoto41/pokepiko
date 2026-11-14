import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/high_score_store.dart';
import '../models/quiz_settings.dart';

final highScoreStoreProvider = Provider<HighScoreStore>(
  (ref) => HighScoreStore(),
);

/// ハイスコアの区分（クイズの種類と、画像の見せかたの組み合わせ）
/// レコード型 (A, B) は、2つの値をひとまとめにして Map のキーにできる
typedef ScoreKey = (QuizVariant, QuizMode);

/// 区分ごとのハイスコア
/// AsyncNotifier: 端末から読み込むのに時間がかかる（非同期の）状態を持つ Notifier
final highScoresProvider =
    AsyncNotifierProvider<HighScoresController, Map<ScoreKey, int>>(
      HighScoresController.new,
    );

class HighScoresController extends AsyncNotifier<Map<ScoreKey, int>> {
  @override
  Future<Map<ScoreKey, int>> build() async {
    final store = ref.watch(highScoreStoreProvider);
    return {
      for (final variant in QuizVariant.values)
        for (final mode in QuizMode.values)
          (variant, mode): await store.read(variant, mode),
    };
  }

  /// ゲームの結果を記録する。ハイスコアを更新したら true
  Future<bool> submit(QuizVariant variant, QuizMode mode, int score) async {
    final scores = await future; // 読み込みが終わるのを待つ
    if (score <= (scores[(variant, mode)] ?? 0)) return false;

    await ref.read(highScoreStoreProvider).write(variant, mode, score);
    state = AsyncData({...scores, (variant, mode): score});
    return true;
  }
}
