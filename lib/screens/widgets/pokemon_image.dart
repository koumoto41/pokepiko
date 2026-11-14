import 'package:material_ui/material_ui.dart';

import '../../models/pokemon.dart';
import '../../models/quiz_settings.dart';
import 'cached_image.dart';

/// モードに合わせてポケモンの画像を1枚表示する
/// - イラスト / シルエット: 公式イラスト（シルエットは黒く塗りつぶす）
/// - ドット: ドット絵
class PokemonImage extends StatelessWidget {
  final Pokemon pokemon;
  final QuizMode mode;
  final bool revealed; // true: 答えたあと（シルエットでもカラーで見せる）

  const PokemonImage({
    super.key,
    required this.pokemon,
    required this.mode,
    this.revealed = false,
  });

  @override
  Widget build(BuildContext context) {
    final pixelArt = mode == QuizMode.pixel && pokemon.spriteUrl != null;
    // 使う画像のURL（片方が無いポケモンもいるので、もう片方で代用する）
    final url = pixelArt
        ? pokemon.spriteUrl
        : (pokemon.artworkUrl ?? pokemon.spriteUrl);
    if (url == null) return const Icon(Icons.help_outline, size: 120);

    Widget image = CachedImage(
      url: url,
      // ドット絵は小さい画像を拡大するので、ぼかさずにカクカクのまま表示する
      filterQuality: pixelArt ? FilterQuality.none : FilterQuality.medium,
      // ドット絵も画面いっぱいに大きく見せる
      width: double.infinity,
      height: double.infinity,
      error: const Icon(Icons.help_outline, size: 120),
    );

    if (mode == QuizMode.silhouette && !revealed) {
      // srcIn: 画像の「形」はそのまま、色だけ黒に置きかえる（透明な背景は透明のまま）
      image = ColorFiltered(
        colorFilter: const ColorFilter.mode(Colors.black, BlendMode.srcIn),
        child: image,
      );
    }
    return image;
  }
}
