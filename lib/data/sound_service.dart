import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// BGM の種類（ファイルは assets/ からの場所）
enum Bgm {
  title('bgm/title.wav'), // タイトル・設定画面
  quiz('bgm/quiz.wav'), // クイズ画面
  zukan('bgm/zukan.wav'); // 図鑑（オルゴールのワルツ）

  final String path;
  const Bgm(this.path);
}

/// BGM と効果音を鳴らす係
/// BGM 用と効果音用でプレイヤーを分けて、同時に鳴らせるようにする
class SoundService {
  static const _bgmVolume = 0.35; // 効果音より小さめ

  final _bgmPlayer = AudioPlayer();
  final _sePlayer = AudioPlayer();
  final _jinglePlayer = AudioPlayer(); // 結果画面の曲（BGM とは別にする）
  Bgm? _current; // いま流している BGM

  /// BGM を流す（同じ曲が流れていれば、最初に戻さずそのまま）
  Future<void> playBgm(Bgm bgm) async {
    // 結果画面の曲が鳴っていたら止める（ほかの画面に移ったので）
    await stopJingle();
    if (_current == bgm) return;
    _current = bgm;
    await _safely(() async {
      await _bgmPlayer.stop();
      await _bgmPlayer.setReleaseMode(ReleaseMode.loop); // くり返し再生
      await _bgmPlayer.play(AssetSource(bgm.path), volume: _bgmVolume);
    });
  }

  Future<void> stopBgm() async {
    _current = null;
    await _safely(_bgmPlayer.stop);
  }

  /// アプリが裏に回ったとき・戻ってきたとき用
  Future<void> pauseBgm() => _safely(_bgmPlayer.pause);

  Future<void> resumeBgm() async {
    if (_current != null) await _safely(_bgmPlayer.resume);
  }

  /// 結果画面の曲を1回だけ鳴らす（くり返さない）
  Future<void> playJingle(String path) => _safely(() async {
    await _jinglePlayer.stop();
    await _jinglePlayer.setReleaseMode(ReleaseMode.stop);
    await _jinglePlayer.play(AssetSource(path));
  });

  Future<void> stopJingle() => _safely(_jinglePlayer.stop);

  Future<void> playCorrect() => _playSe('se/correct.wav');

  Future<void> playWrong() => _playSe('se/wrong.wav');

  Future<void> _playSe(String path) => _safely(() async {
    await _sePlayer.stop(); // 前の効果音が鳴っていたら止めてから
    await _sePlayer.play(AssetSource(path));
  });

  /// 音が鳴らせなくてもゲームは続けられるように、エラーはログに出すだけにする
  Future<void> _safely(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      debugPrint('音を鳴らせませんでした: $e');
    }
  }
}
