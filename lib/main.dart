import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'app_theme.dart';
import 'data/settings_store.dart';
import 'models/quiz_settings.dart';
import 'providers/settings_provider.dart';
import 'providers/sound_provider.dart';
import 'screens/title_screen.dart';

Future<void> main() async {
  // runApp より前に端末の保存領域を使うときは、先にこれを呼ぶ決まり
  WidgetsFlutterBinding.ensureInitialized();
  // 前回の設定を読んでから画面を出す（最初から前回の世代・モードになっている）
  // 読めなかったときは、ふつうの設定で起動する（アプリが開かなくなるのを防ぐ）
  final settings = await SettingsStore().read().catchError(
    (Object e) => const QuizSettings(),
  );

  // ProviderScope: Riverpod の Provider を使うために、アプリ全体を包む
  runApp(
    ProviderScope(
      overrides: [initialSettingsProvider.overrideWithValue(settings)],
      child: const PokepikoApp(),
    ),
  );
}

class PokepikoApp extends ConsumerStatefulWidget {
  const PokepikoApp({super.key});

  @override
  ConsumerState<PokepikoApp> createState() => _PokepikoAppState();
}

class _PokepikoAppState extends ConsumerState<PokepikoApp> {
  late final BgmNavigatorObserver _bgmObserver;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    final sound = ref.read(soundServiceProvider);
    // 画面が切りかわったら BGM も切りかえる
    _bgmObserver = BgmNavigatorObserver(sound);
    // ホームボタンなどでアプリが裏に回ったら BGM を止め、戻ったら再開する
    _lifecycle = AppLifecycleListener(
      onHide: sound.pauseBgm,
      onShow: sound.resumeBgm,
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ポケピコ',
      theme: buildAppTheme(), // 色・文字・ボタンの形は app_theme.dart でまとめて決める
      navigatorObservers: [_bgmObserver],
      // 画面の流れ：タイトル → 設定 → クイズ → 結果
      home: const TitleScreen(),
    );
  }
}
