import 'poke_type.dart';
import 'pokemon.dart';
import 'quiz_settings.dart';

/// 1問分のデータ
/// クイズの種類によって、選択肢が「ポケモン」か「タイプ」かが変わる
/// - なまえクイズ    ：pokemon を見せて、pokemonChoices（名前）から選ぶ
/// - ポケモン→タイプ ：pokemon を見せて、typeChoices から選ぶ
/// - タイプ→ポケモン ：askedType を見せて、pokemonChoices（絵）から選ぶ
/// - あいしょう      ：pokemonChoices（2匹の絵）から、相性で勝つほうを選ぶ
class Question {
  final QuizVariant variant;

  /// 主役のポケモン（なまえ・ポケモン→タイプでは見せるポケモン、
  /// タイプ→ポケモン・あいしょうでは正解のポケモン）。結果画面の「おぼえてね！」にも出す
  final Pokemon pokemon;

  final List<Pokemon> pokemonChoices; // 選択肢がポケモンのとき（4匹。あいしょうは2匹）
  final List<PokeType> typeChoices; // 選択肢がタイプのとき（4つ）
  final PokeType? askedType; // タイプ→ポケモンで聞くタイプ
  final (PokeType, PokeType)? reason; // あいしょうで勝つ理由（例：みず は ほのお に つよい）
  final int correctIndex; // 選択肢のうち、正解の位置（0〜3）

  const Question({
    required this.variant,
    required this.pokemon,
    required this.correctIndex,
    this.pokemonChoices = const [],
    this.typeChoices = const [],
    this.askedType,
    this.reason,
  });

  /// 選択肢の数
  int get choiceCount =>
      typeChoices.isNotEmpty ? typeChoices.length : pokemonChoices.length;
}
