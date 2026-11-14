import 'pokemon.dart';

/// 1問分のデータ（正解1匹＋選択肢4つ）
class Question {
  final Pokemon answer; // 正解
  final List<Pokemon> choices; // 選択肢（正解を含む4匹、シャッフル済み）

  const Question({required this.answer, required this.choices});
}
