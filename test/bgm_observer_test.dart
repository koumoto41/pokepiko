import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pokepiko/data/sound_service.dart';
import 'package:pokepiko/providers/sound_provider.dart';
import 'package:pokepiko/screens/route_names.dart';

/// 実際には鳴らさず、何を頼まれたかだけ覚える偽の音係
class FakeSoundService implements SoundService {
  Bgm? playing; // いま流れているはずの BGM
  String? jingle; // いま鳴っているはずの結果画面の曲
  final jingles = <String>[]; // これまでに鳴らした結果画面の曲

  @override
  Future<void> playBgm(Bgm bgm) async {
    jingle = null; // 本物と同じく、BGM を流すときは結果画面の曲を止める
    playing = bgm;
  }

  @override
  Future<void> playJingle(String path) async {
    jingle = path;
    jingles.add(path);
  }

  @override
  Future<void> stopJingle() async => jingle = null;

  @override
  Future<void> stopBgm() async => playing = null;

  @override
  Future<void> pauseBgm() async {}

  @override
  Future<void> resumeBgm() async {}

  @override
  Future<void> playCorrect() async {}

  @override
  Future<void> playWrong() async {}
}

void main() {
  late FakeSoundService sound;
  late NavigatorState navigator;

  // 本物の画面の代わりに、名前だけつけた空の画面を使う
  Route<void> page(String name) => MaterialPageRoute(
    settings: RouteSettings(name: name),
    builder: (_) => Text(name),
  );

  Future<void> pumpApp(WidgetTester tester) async {
    sound = FakeSoundService();
    final key = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: key,
        navigatorObservers: [BgmNavigatorObserver(sound)],
        home: const Text('title'),
      ),
    );
    navigator = key.currentState!;
  }

  testWidgets('画面に合わせて BGM が切りかわる', (tester) async {
    await pumpApp(tester);
    expect(sound.playing, Bgm.title); // タイトル

    navigator.push(page(RouteNames.settings));
    await tester.pumpAndSettle();
    expect(sound.playing, Bgm.title); // 設定もタイトルと同じ曲

    navigator.push(page(RouteNames.quiz));
    await tester.pumpAndSettle();
    expect(sound.playing, Bgm.quiz);

    // 図鑑は専用の曲
    navigator.push(page(RouteNames.zukan));
    await tester.pumpAndSettle();
    expect(sound.playing, Bgm.zukan);
    navigator.push(page(RouteNames.zukanDetail));
    await tester.pumpAndSettle();
    expect(sound.playing, Bgm.zukan);
    navigator
      ..pop()
      ..pop();
    await tester.pumpAndSettle();
    expect(sound.playing, Bgm.quiz);

    navigator.pushReplacement(page(RouteNames.result));
    await tester.pumpAndSettle();
    expect(sound.playing, isNull); // 結果画面は BGM なし

    // 結果画面で曲が鳴っているところで……
    await sound.playJingle('se/result_great.wav');
    // 結果 →「せってい」で設定に戻ると、タイトルの曲がまた流れて、結果画面の曲は止まる
    navigator.pop();
    await tester.pumpAndSettle();
    expect(sound.playing, Bgm.title);
    expect(sound.jingle, isNull);
  });

  testWidgets('ダイアログを開いても BGM は変わらない', (tester) async {
    await pumpApp(tester);
    navigator.push(page(RouteNames.quiz));
    await tester.pumpAndSettle();

    showDialog<void>(
      context: navigator.context,
      builder: (_) => const AlertDialog(content: Text('dialog')),
    );
    await tester.pumpAndSettle();
    expect(sound.playing, Bgm.quiz);

    navigator.pop(); // ダイアログを閉じる
    await tester.pumpAndSettle();
    expect(sound.playing, Bgm.quiz);
  });
}
