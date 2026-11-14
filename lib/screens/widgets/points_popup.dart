import 'package:material_ui/material_ui.dart';

import '../../models/score.dart';

/// 正解したときに、取った点数を「+250」のように出す（上にあがりながら消える）
/// 2問以上つづけて正解しているときは「3れんぞく！」も出す
class PointsPopup extends StatefulWidget {
  final Score points; // この問題で取った点数
  final int streak; // 何問つづけて正解したか

  const PointsPopup({super.key, required this.points, required this.streak});

  @override
  State<PointsPopup> createState() => _PointsPopupState();
}

class _PointsPopupState extends State<PointsPopup>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: Alignment.topCenter,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final t = _controller.value;
            return Transform.translate(
              offset: Offset(0, 16 - 24 * Curves.easeOut.transform(t)),
              child: Opacity(
                // はじめはすぐ見えて、最後の3割で消える
                opacity: t < 0.7 ? 1 : (1 - t) / 0.3,
                child: child,
              ),
            );
          },
          // 正解の〇や星の上に重なっても読めるよう、白い札の上に出す
          child: Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 6),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '+${widget.points.total}',
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    color: Colors.deepOrange,
                    height: 1.1,
                  ),
                ),
                if (widget.streak >= 2)
                  Text(
                    '${widget.streak}れんぞく！',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.pink,
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
