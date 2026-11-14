import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/settings_store.dart';
import '../models/generation.dart';
import '../models/quiz_settings.dart';

final settingsStoreProvider = Provider<SettingsStore>((ref) => SettingsStore());

/// アプリ起動時に読み込んだ、前回の設定
/// main.dart で、読み込んだ値に差し替えて（override して）使う
final initialSettingsProvider = Provider<QuizSettings>(
  (ref) => const QuizSettings(),
);

/// 設定を持つ Provider
/// クイズ画面を閉じても設定は残したいので、autoDispose にはしない
final settingsProvider = NotifierProvider<SettingsController, QuizSettings>(
  SettingsController.new,
);

class SettingsController extends Notifier<QuizSettings> {
  @override
  QuizSettings build() => ref.read(initialSettingsProvider);

  void setMode(QuizMode mode) {
    _update(state.copyWith(mode: mode));
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
    _update(state.copyWith(generations: next));
  }

  /// 「ぜんぶ」：全部えらばれていれば第1世代だけに戻し、そうでなければ全部えらぶ
  void toggleAllGenerations() {
    final allSelected = state.generations.length == Generation.all.length;
    _update(
      state.copyWith(
        generations: allSelected
            ? {1}
            : {for (final g in Generation.all) g.number},
      ),
    );
  }

  /// 設定を変えて、端末にも保存する（次にアプリを開いたとき用）
  void _update(QuizSettings next) {
    state = next;
    // 保存を待たずに画面はすぐ変える。保存に失敗しても遊ぶのには困らないので、ログだけ出す
    ref
        .read(settingsStoreProvider)
        .write(next)
        .catchError((Object e) => debugPrint('設定を保存できませんでした: $e'));
  }
}
