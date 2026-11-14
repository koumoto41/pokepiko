import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

/// ポケモンの鳴き声を鳴らす係
/// PokéAPI の鳴き声は OGG 形式で、iPhone の標準の音声機能（audioplayers が使うもの）では
/// 再生できない。そのため、OGG を再生できる flutter_soloud を使う
class CryPlayer {
  final SoLoud _soloud = SoLoud.instance;
  Future<void>? _init; // 音声エンジンの準備（最初に鳴らすときに1回だけ）
  final _sources = <String, AudioSource>{}; // 1回読み込んだ音は使い回す

  Future<void> play(File file) async {
    try {
      await (_init ??= _soloud.init());
      final source = _sources[file.path] ??= await _soloud.loadFile(file.path);
      _soloud.play(source);
    } catch (e) {
      // 鳴らせなくても図鑑は見られるので、ログに出すだけにする
      debugPrint('鳴き声を鳴らせませんでした: $e');
    }
  }
}
