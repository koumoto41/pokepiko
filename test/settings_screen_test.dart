import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pokepiko/providers/data_providers.dart';
import 'package:pokepiko/screens/settings_screen.dart';

import 'fakes.dart';

void main() {
  late FakePokemonRepository repo;

  // 全国図鑑の「ダウンロード」ボタン（えらんだ世代の段の下にあるので、いちばん最後）
  Finder downloadAllButton() => find.text('ダウンロード').last;

  // ダイアログの中にある文字（設定画面にも同じ文字のボタンがあるので区別する）
  Finder inDialog(String text) =>
      find.descendant(of: find.byType(AlertDialog), matching: find.text(text));

  Future<void> pumpSettings(WidgetTester tester) async {
    repo = FakePokemonRepository()..imagesFail = true;
    // 縦長の画面にして、ダウンロードの段まで見えるようにする
    tester.view.physicalSize = const Size(1200, 4000);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [pokemonRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pump();
  }

  testWidgets('「ぜんぶ ダウンロード」は確認してから、1025匹すべてを保存する', (tester) async {
    await pumpSettings(tester);
    expect(find.text('ほぞんずみ 0 / 1025 ひき'), findsOneWidget);

    await tester.tap(downloadAllButton());
    await tester.pumpAndSettle();
    expect(find.text('ぜんぶ ダウンロードしますか？'), findsOneWidget);

    // 確認ダイアログの「ダウンロード」を押す
    await tester.tap(inDialog('ダウンロード'));
    await tester.pumpAndSettle();
    expect(repo.downloadedIds?.length, 1025);
    expect(find.text('おわったよ'), findsOneWidget);

    await tester.tap(find.text('とじる'));
    await tester.pumpAndSettle();
    // 保存済みの数が更新されて、ボタンが消える
    expect(find.text('ダウンロード'), findsNothing);
    expect(find.text('ぜんぶ ほぞんずみ（オフラインで あそべる）'), findsWidgets);
  });

  testWidgets('確認で「やめる」を押すと、ダウンロードしない', (tester) async {
    await pumpSettings(tester);
    await tester.tap(downloadAllButton());
    await tester.pumpAndSettle();
    await tester.tap(inDialog('やめる'));
    await tester.pumpAndSettle();
    expect(repo.downloadedIds, isNull);
  });

  testWidgets('ダウンロード中に「やめる」でダイアログを閉じても、エラーにならない', (tester) async {
    await pumpSettings(tester);
    repo.downloadGate = Completer<void>(); // 終わらせずに止めておく

    await tester.tap(downloadAllButton());
    await tester.pumpAndSettle();
    await tester.tap(inDialog('ダウンロード'));
    await tester.pumpAndSettle(); // 確認ダイアログが閉じきるまで待つ
    expect(find.text('ダウンロードちゅう…'), findsOneWidget);

    await tester.tap(inDialog('やめる'));
    await tester.pumpAndSettle();
    expect(find.text('ダウンロードちゅう…'), findsNothing);

    // 閉じたあとにダウンロードが終わっても、表示が更新されるだけ
    repo.downloadGate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('ダウンロード'), findsNothing);
  });
}
