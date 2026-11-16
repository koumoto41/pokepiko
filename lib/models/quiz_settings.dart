import 'generation.dart';
import 'legendary.dart';

/// 画像の見せかた
enum QuizMode {
  illustration('イラスト'), // 公式イラスト
  pixel('ドット'), // ドット絵
  silhouette('シルエット'); // 公式イラストを黒く塗りつぶす

  final String label; // 画面に出す名前
  const QuizMode(this.label);
}

/// クイズの種類
enum QuizKind {
  name('なまえ'), // ポケモンの名前を当てる
  type('タイプ'), // ポケモンのタイプを当てる
  legendary('でんせつ'); // 伝説・幻だけの、名前を当てるクイズ

  final String label;
  const QuizKind(this.label);
}

/// タイプクイズの向き
enum TypeDirection {
  pokemonToType('ポケモン→タイプ'), // ポケモンを見て、タイプを選ぶ
  typeToPokemon('タイプ→ポケモン'); // タイプを見て、ポケモンを選ぶ

  final String label;
  const TypeDirection(this.label);
}

/// 実際に遊ぶクイズ（種類と向きの組み合わせ）。ハイスコアもこれごとに記録する
enum QuizVariant {
  name('なまえ'),
  pokemonToType('ポケモン→タイプ'),
  typeToPokemon('タイプ→ポケモン'),
  legendary('でんせつ');

  final String label;
  const QuizVariant(this.label);
}

/// ゲームの設定
class QuizSettings {
  final QuizMode mode;
  final Set<int> generations; // 出題する世代の番号（1〜9、複数えらべる）
  final QuizKind kind;
  final TypeDirection typeDirection; // タイプクイズのときだけ使う
  final bool dexKanji; // 図鑑の説明文を漢字で出すか（false ならひらがな）

  const QuizSettings({
    this.mode = QuizMode.illustration,
    this.generations = const {1},
    this.kind = QuizKind.name,
    this.typeDirection = TypeDirection.pokemonToType,
    this.dexKanji = false,
  });

  QuizSettings copyWith({
    QuizMode? mode,
    Set<int>? generations,
    QuizKind? kind,
    TypeDirection? typeDirection,
    bool? dexKanji,
  }) {
    return QuizSettings(
      mode: mode ?? this.mode,
      generations: generations ?? this.generations,
      kind: kind ?? this.kind,
      typeDirection: typeDirection ?? this.typeDirection,
      dexKanji: dexKanji ?? this.dexKanji,
    );
  }

  /// いまの設定で遊ぶクイズ
  QuizVariant get variant => switch (kind) {
    QuizKind.name => QuizVariant.name,
    QuizKind.legendary => QuizVariant.legendary,
    QuizKind.type => switch (typeDirection) {
      TypeDirection.pokemonToType => QuizVariant.pokemonToType,
      TypeDirection.typeToPokemon => QuizVariant.typeToPokemon,
    },
  };

  /// 出題の候補になる図鑑番号
  /// でんせつクイズは、世代の選択に関係なく、全世代の伝説・幻から出す
  /// （第1世代だけだと5匹しかいなくて、10問のクイズが作れないため）
  List<int> get candidateIds => kind == QuizKind.legendary
      ? Legendary.all
      : [
          for (final g in Generation.all)
            if (generations.contains(g.number)) ...g.ids,
        ];
}
