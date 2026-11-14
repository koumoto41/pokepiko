import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../data/sound_service.dart';
import '../screens/route_names.dart';

final soundServiceProvider = Provider<SoundService>((ref) => SoundService());

/// 画面が切りかわるたびに、いちばん上の画面に合った BGM にする
/// （各画面に書くと「戻る」で前の画面に戻ったときに鳴らし忘れるので、ここでまとめて見る）
class BgmNavigatorObserver extends NavigatorObserver {
  final SoundService sound;
  BgmNavigatorObserver(this.sound);

  static const _bgmByRoute = {
    RouteNames.title: Bgm.title,
    RouteNames.settings: Bgm.title,
    RouteNames.quiz: Bgm.quiz,
    // 結果画面は BGM なし
  };

  void _update(Route<dynamic>? top) {
    // ダイアログ（ダウンロードの進み具合など）は画面ではないので無視
    if (top is! PageRoute) return;
    final bgm = _bgmByRoute[top.settings.name];
    bgm == null ? sound.stopBgm() : sound.playBgm(bgm);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _update(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _update(previousRoute);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _update(newRoute);
}
