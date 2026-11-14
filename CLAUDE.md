# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## プロジェクト概要

ポケピコ：5歳児と保護者向けの、iOS 専用 Flutter クイズアプリ（個人用・App Store には出さない）。
データは PokéAPI（https://pokeapi.co）から取り、自前のサーバーは使わない。主に iPhone SE（第3世代、375×667pt）で遊ぶ。

## ユーザーとのやりとり

- 回答・説明は日本語で書く。ユーザーは Flutter を勉強中なので、コードのコメントは日本語で要点だけ入れる。
- ターミナルで実行してもらうコマンドは、1行に1つずつ、そのままコピペできる形で書く。
- `main` で直接作業しない。機能ごとにブランチを作る。コミット・push はユーザーに頼まれたときだけ。
- `gh` は入っていない。プルリクエストは、push 後に出る URL からユーザーがブラウザで作る（タイトルと説明文を用意して渡す）。
- ユーザーが IDE や GitHub でブランチを切りかえたり、PR をマージしたりすることがある。ファイルが急に古い内容に戻ったら、まず `git branch --show-current` と `git reflog` で状況を確かめ、勝手に戻さずユーザーに確認する。

## コマンド

```
flutter analyze                       # 解析（警告ゼロを保つ）
dart format lib test integration_test # 整形
flutter test                          # 全テスト（数秒で終わる）
flutter test test/quiz_controller_test.dart                       # 1ファイルだけ
flutter test test/quiz_controller_test.dart --plain-name "時間切れ" # 名前で1件だけ
flutter build ios --simulator --debug # シミュレーター向けビルドの確認
```

シミュレーター（Xcode 27 では Simulator.app が廃止され DeviceHub.app になった。`open -a Simulator` は使えない）：

```
xcrun simctl boot "iPhone 18 Pro"
open -a /Applications/Xcode.app/Contents/Applications/DeviceHub.app
flutter run
```

iPhone SE（第3世代）のシミュレーターは ID `B0AA6DCC-29B3-4D75-BE70-111FF69E85A0`。

### 実機サイズのスクリーンショットで確認する

`flutter test` のフォントは本物ではないので、見た目の確認はシミュレーターで自動操作して撮る：

```
SCREENSHOT_DIR=<保存先> flutter drive --driver=test_driver/integration_test.dart --target=integration_test/screenshot_test.dart -d B0AA6DCC-29B3-4D75-BE70-111FF69E85A0
```

- `screenshot_test.dart`（なまえクイズ）と `screenshot_type_quiz_test.dart`（タイプクイズ）がある。本物の PokéAPI を使う。
- 初回ビルドは数分かかるので、バックグラウンドで実行してログをファイルに残す。
- `flutter drive` は終了時にシミュレーターからアプリを削除する。ただし shared_preferences の保存データ（設定・ハイスコア・図鑑の記録など）は、次の実行に残ることがある。まっさらな状態を前提にしたテストを書かない。
- 画面の切りかわりアニメーション中のタップは無視されるので、遷移のあとは `wait` を入れてから押す。

## アーキテクチャ

状態管理は Riverpod（`flutter_riverpod` 3.x、コード生成なし、手書きの `Notifier` / `AsyncNotifier`）。
`lib/` は「models（データの形）→ data（取得・保存）→ providers（状態）→ screens（表示）」の層に分かれ、画面は状態を表示してタップを渡すだけにする。

### import

`package:flutter/material.dart` は非推奨（Flutter 3.47 以降）。代わりに `package:material_ui/material_ui.dart` を使う。

### クイズの種類

`QuizSettings`（`lib/models/quiz_settings.dart`）の組み合わせで遊ぶクイズが決まる：

- `QuizKind`（なまえ／タイプ）＋ `TypeDirection`（ポケモン→タイプ／タイプ→ポケモン）→ `QuizVariant`（3種類）
- `QuizMode`：画像の見せかた（イラスト／ドット／シルエット）。どのクイズでも使う
- `generations`：出題する世代（`Generation.all` に図鑑番号の範囲を固定で持つ）

`Question`（`lib/models/question.dart`）は、3種類のクイズを1つの形で表す。選択肢は `pokemonChoices` か `typeChoices` のどちらかで、正解は `correctIndex`、回答は「何番目の選択肢か」（`QuizController.answer(int)`）で受け取る。

### 出題の流れ（`lib/providers/quiz_controller.dart`）

- `quizControllerProvider` は autoDispose。クイズ画面を閉じると状態が捨てられ、開くたびに新しいゲームになる。設定は `build` で1回だけ `ref.read` する。
- 10問・1問30秒・回答の1秒後に次へ。考えている間に次の問題を先に作っておく（`_nextQuestion`）。
- `_gameId` で古いゲームの非同期処理を無視する（`retry` → `invalidateSelf` のときに2ゲームが同時に進まないように）。
- ポケモン選びは `_pickPokemon` に集約している。オンラインなら画像をその場で保存し、通信に失敗したらそのゲーム中は `_offline = true` にして、保存済みのポケモンだけで出題する。
- タイプクイズでは、正解が1つだけになるように選ぶ：2タイプのポケモンはタイプを片方だけ選択肢に入れる。タイプ→ポケモンでは、はずれにそのタイプを持たないポケモンを選ぶ。

### データ取得とキャッシュ（`lib/data/`）

- `PokeApiClient`：名前は `/pokemon-species/{id}` の `ja-hrkt`。API は言語コードの大文字小文字を変えたことがあるので、小文字にそろえて比べる。画像 URL とタイプは `/pokemon/{id}`。タイプは `PokeType`（18種類、`stellar` などは除外）に変換する。
- `CacheStore`：Application Support の `cache/pokemon/{id}.json` と `cache/images/` に保存する（OS に消されない場所）。書き込みは一時ファイルから rename。
- `PokemonRepository`：保存済みならそれを使い、無ければ API から取って保存する。同じものを同時に頼まれたら、1回のダウンロードを使い回す。
- 保存する JSON の形を変えるときは、古いデータを読めるようにする。今は `Pokemon.fromJson` が `types` の無い古いデータで `FormatException` を投げ、`readPokemon` が null を返して取り直す（画像は取り直さない）。
- 画像は必ず `CachedImage`（`lib/screens/widgets/cached_image.dart`）で表示する。`Image.network` を使うとオフラインで表示できない。

### 保存する設定・記録（shared_preferences の `SharedPreferencesAsync`）

- `SettingsStore`：前回の設定。`main()` で `runApp` の前に読み、`initialSettingsProvider` を override して渡す。知らない値は既定値に戻す。
- `HighScoreStore`：`(QuizVariant, QuizMode)` ごとの最高正解数。なまえクイズは、タイプクイズ追加前と同じキー `highScore.<mode>` を使って記録を引き継いでいる。キーを変えるときは、以前のキーも読めるようにする。

### 画面と音

- 画面遷移：タイトル → 設定 → クイズ → 結果。ルートには `RouteNames` の名前をつける。BGM は各画面ではなく `BgmNavigatorObserver` が、一番上のルート名から切りかえる（ダイアログは無視）。新しい画面を追加したら名前と BGM の対応を足す。
- 効果音・BGM は `tool/make_sounds.py` で合成したオリジナル音源（`assets/`）。アプリアイコンは `tool/make_icon.py` で描いた 1024px を `sips` で各サイズに縮小したもの。公式の素材は使わない。
- 色・ボタンの形は `lib/app_theme.dart` にまとめている。
- iPhone SE 対応：縦が短い画面では `context.isCompactHeight` でボタンや余白を小さくする。文字の拡大は 1.2 倍までに制限している（`main.dart` の `builder`）。画面を変えたら SE サイズで切れていないか確かめる。
- 子ども向けなので、画面の文言はひらがな中心にする。ポケモン名はカタカナ。

## テスト

- `test/flutter_test_config.dart` が全テストで shared_preferences をメモリ上のものに差し替える。
- 通信・ファイルを使うものは Provider を override して偽物に差し替える（`test/fakes.dart` の `FakePokemonRepository`。図鑑番号から決まった名前・タイプを作り、`online` / `saved` / `savedImages` でオフラインを再現できる）。
- タイマーを含むテストは `testWidgets` の中で書くと時間がにせものになり、`tester.pump(Duration)` で30秒も一瞬で進められる。テストの最後に `container.dispose()` してタイマーを止める。
- `test/screens_layout_test.dart` は iPhone SE と大きい iPhone の2サイズで、各画面がはみ出さないことを確かめる。
