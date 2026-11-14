import 'package:material_ui/material_ui.dart';

import '../../app_theme.dart';

/// 選択肢ボタンの見た目の状態
enum ChoiceLook {
  normal, // まだ答えていない
  correct, // 正解のボタン（答えたあと）
  wrong, // 間違えて選んだボタン
  faded, // それ以外（答えたあと、うすくする）
}

/// 子どもが押しやすい、大きくて丸い選択肢ボタン
/// 押しているあいだ少し小さくなって、「押した」ことが分かる
class ChoiceButton extends StatefulWidget {
  final String label;
  final Color color; // ふだんの色
  final ChoiceLook look;
  final VoidCallback? onPressed; // null だと押せない

  const ChoiceButton({
    super.key,
    required this.label,
    required this.color,
    this.look = ChoiceLook.normal,
    this.onPressed,
  });

  @override
  State<ChoiceButton> createState() => _ChoiceButtonState();
}

class _ChoiceButtonState extends State<ChoiceButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (widget.onPressed != null) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (widget.look) {
      ChoiceLook.normal => (widget.color, null),
      ChoiceLook.correct => (AppColors.correct, Icons.circle_outlined),
      ChoiceLook.wrong => (AppColors.wrong, Icons.close),
      ChoiceLook.faded => (widget.color, null),
    };

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: widget.look == ChoiceLook.faded ? 0.35 : 1,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 100),
        // 押している間は小さく、正解のボタンは少し大きく
        scale: _pressed
            ? 0.94
            : widget.look == ChoiceLook.correct
            ? 1.04
            : 1,
        child: GestureDetector(
          onTapDown: (_) => _setPressed(true),
          onTapUp: (_) => _setPressed(false),
          onTapCancel: () => _setPressed(false),
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 68,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(34),
              // 下に濃い影をつけて、ぷっくりしたボタンに見せる
              boxShadow: [
                BoxShadow(
                  color: Color.lerp(color, Colors.black, 0.3)!,
                  offset: Offset(0, _pressed ? 1 : 5),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: Colors.white, size: 32),
                  const SizedBox(width: 8),
                ],
                // 長い名前でもはみ出さないよう、入りきらなければ縮める
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      widget.label,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
