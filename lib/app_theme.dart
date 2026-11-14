import 'package:material_ui/material_ui.dart';

/// アプリで使う色（明るく、子どもが見分けやすい色）
abstract final class AppColors {
  static const cream = Color(0xFFFFF8E1); // 画面の地の色
  static const brown = Color(0xFF6D4C41); // 文字の色（黒よりやわらかい）
  static const correct = Color(0xFF43A047); // 正解の緑
  static const wrong = Color(0xFFE57373); // 不正解の赤（強すぎない）

  /// 4つの選択肢ボタンの色（色で区別できるように、ばらばらの色にする）
  static const choices = [
    Color(0xFFF06292), // ピンク
    Color(0xFF29B6F6), // みずいろ
    Color(0xFFAB47BC), // むらさき
    Color(0xFFFF9800), // オレンジ
  ];
}

/// アプリ全体のテーマ（色・文字・ボタンの形をまとめて決める）
/// ここで決めておくと、各画面で毎回スタイルを書かなくてよい
ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: Colors.orange,
    surface: AppColors.cream,
  );
  // 丸っこいボタンの形と、大きめの太字
  final buttonShape = WidgetStatePropertyAll<OutlinedBorder>(
    RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
  );
  const buttonText = WidgetStatePropertyAll(
    TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
  );

  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.cream,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent, // 後ろのグラデーションを見せる
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: AppColors.brown,
      ),
      iconTheme: IconThemeData(color: AppColors.brown, size: 32),
    ),
    textTheme: ThemeData.light().textTheme.apply(
      bodyColor: AppColors.brown,
      displayColor: AppColors.brown,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(shape: buttonShape, textStyle: buttonText),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        shape: buttonShape,
        textStyle: buttonText,
        side: const WidgetStatePropertyAll(
          BorderSide(color: Colors.orange, width: 3),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(shape: buttonShape, textStyle: buttonText),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
  );
}

/// 上から下へのグラデーションの背景（画面ごとに色を変えて使う）
class GradientBackground extends StatelessWidget {
  final List<Color> colors;
  final Widget child;

  const GradientBackground({
    super.key,
    required this.colors,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ),
      ),
      child: child,
    );
  }
}

/// 画面の大きさに合わせて、レイアウトを切りかえるための便利な関数
extension ScreenSize on BuildContext {
  /// iPhone SE など、縦が短い画面か（SE は 667、ほかの最近の iPhone は 800 以上）
  bool get isCompactHeight => MediaQuery.sizeOf(this).height < 700;
}
