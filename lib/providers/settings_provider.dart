import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/generation.dart';
import '../models/quiz_settings.dart';

/// 設定を持つ Provider
/// クイズ画面を閉じても設定は残したいので、autoDispose にはしない
final settingsProvider = NotifierProvider<SettingsController, QuizSettings>(
  SettingsController.new,
);

class SettingsController extends Notifier<QuizSettings> {
  @override
  QuizSettings build() => const QuizSettings();

  void setMode(QuizMode mode) {
    state = state.copyWith(mode: mode);
  }

  /// 世代のオン・オフを切りかえる（最後の1つは外せない）
  void toggleGeneration(int number) {
    final next = {...state.generations};
    if (next.contains(number)) {
      if (next.length == 1) return;
      next.remove(number);
    } else {
      next.add(number);
    }
    state = state.copyWith(generations: next);
  }

  /// 「ぜんぶ」：全部えらばれていれば第1世代だけに戻し、そうでなければ全部えらぶ
  void toggleAllGenerations() {
    final allSelected = state.generations.length == Generation.all.length;
    state = state.copyWith(
      generations: allSelected
          ? {1}
          : {for (final g in Generation.all) g.number},
    );
  }
}
