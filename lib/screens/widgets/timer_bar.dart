import 'package:material_ui/material_ui.dart';

/// 残り時間をバーと数字で見せる（数字が読めない子どもにも、バーの長さと色で伝わる）
class TimerBar extends StatelessWidget {
  final int remainingSeconds;
  final int totalSeconds;

  const TimerBar({
    super.key,
    required this.remainingSeconds,
    required this.totalSeconds,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = remainingSeconds / totalSeconds;
    // 残りが少なくなるほど 緑 → オレンジ → 赤
    final color = ratio > 0.5
        ? Colors.green
        : ratio > 0.2
        ? Colors.orange
        : Colors.red;

    return Row(
      children: [
        const Icon(Icons.timer, size: 32),
        const SizedBox(width: 8),
        Expanded(
          // 1秒ごとに値が変わるので、その間をなめらかにアニメーションさせる
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: ratio),
            duration: const Duration(seconds: 1),
            builder: (context, value, _) => ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 16,
                color: color,
                backgroundColor: Colors.grey.shade300,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 48,
          child: Text(
            '$remainingSeconds',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
