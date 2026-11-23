import 'package:material_ui/material_ui.dart';

import '../../app_theme.dart';
import '../../models/pokemon.dart';
import '../../models/quiz_settings.dart';
import 'choice_button.dart';
import 'pokemon_image.dart';
import 'type_badge.dart';

/// 絵で選ぶ選択肢（タイプ→ポケモン・あいしょうのクイズで使う）
/// 答えたあとは、ふちの色で正解・不正解を見せて、名前も出す
class ImageChoice extends StatefulWidget {
  final Pokemon pokemon;
  final QuizMode mode;
  final ChoiceLook look;
  final bool showTypes; // 絵の下にタイプを出すか（あいしょうクイズ）
  final VoidCallback? onPressed; // null だと押せない

  const ImageChoice({
    super.key,
    required this.pokemon,
    required this.mode,
    this.look = ChoiceLook.normal,
    this.showTypes = false,
    this.onPressed,
  });

  @override
  State<ImageChoice> createState() => _ImageChoiceState();
}

class _ImageChoiceState extends State<ImageChoice> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (widget.onPressed != null) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final answered = widget.look != ChoiceLook.normal;
    final borderColor = switch (widget.look) {
      ChoiceLook.correct => AppColors.correct,
      ChoiceLook.wrong => AppColors.wrong,
      _ => Colors.white,
    };

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: widget.look == ChoiceLook.faded ? 0.4 : 1,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 100),
        scale: _pressed ? 0.94 : 1,
        child: GestureDetector(
          onTapDown: (_) => _setPressed(true),
          onTapUp: (_) => _setPressed(false),
          onTapCancel: () => _setPressed(false),
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor, width: 5),
              boxShadow: const [
                BoxShadow(color: Colors.black12, offset: Offset(0, 4)),
              ],
            ),
            child: Column(
              children: [
                Expanded(
                  // シルエットモードでも、答えたらカラーで答え合わせ
                  child: PokemonImage(
                    pokemon: widget.pokemon,
                    mode: widget.mode,
                    revealed: answered,
                  ),
                ),
                // 答えたあとに名前を出す（答える前は絵だけで選ぶ）
                if (answered)
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      widget.pokemon.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                if (widget.showTypes) ...[
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: TypeBadges(
                      types: widget.pokemon.types,
                      fontSize: 16,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
