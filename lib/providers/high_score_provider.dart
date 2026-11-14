import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/high_score_store.dart';
import '../models/quiz_settings.dart';

final highScoreStoreProvider = Provider<HighScoreStore>(
  (ref) => HighScoreStore(),
);

/// モードごとのハイスコア
/// AsyncNotifier: 端末から読み込むのに時間がかかる（非同期の）状態を持つ Notifier
final highScoresProvider =
    AsyncNotifierProvider<HighScoresController, Map<QuizMode, int>>(
      HighScoresController.new,
    );

class HighScoresController extends AsyncNotifier<Map<QuizMode, int>> {
  @override
  Future<Map<QuizMode, int>> build() async {
    final store = ref.watch(highScoreStoreProvider);
    return {for (final mode in QuizMode.values) mode: await store.read(mode)};
  }

  /// ゲームの結果を記録する。ハイスコアを更新したら true
  Future<bool> submit(QuizMode mode, int score) async {
    final scores = await future; // 読み込みが終わるのを待つ
    if (score <= (scores[mode] ?? 0)) return false;

    await ref.read(highScoreStoreProvider).write(mode, score);
    state = AsyncData({...scores, mode: score});
    return true;
  }
}
