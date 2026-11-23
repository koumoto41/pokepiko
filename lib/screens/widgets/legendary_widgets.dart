import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/poke_api_client.dart';
import '../../models/legendary.dart';
import '../../models/pokemon.dart';
import '../../providers/sound_provider.dart';
import 'cached_image.dart';

/// 「でんせつ」（金色）・「まぼろし」（むらさき）の札
/// 伝説・幻でないポケモンには何も出さない
class SpecialBadge extends StatelessWidget {
  final int id;
  final double fontSize;

  const SpecialBadge({super.key, required this.id, this.fontSize = 14});

  @override
  Widget build(BuildContext context) {
    final (label, colors) = Legendary.isLegendary(id)
        ? ('でんせつ', const [Color(0xFFFFD54F), Color(0xFFF9A825)])
        : Legendary.isMythical(id)
        ? ('まぼろし', const [Color(0xFFF48FB1), Color(0xFFAB47BC)])
        : (null, const <Color>[]);
    if (label == null) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: fontSize * 0.6,
        vertical: fontSize * 0.15,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(fontSize),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, color: Colors.white, size: fontSize),
          const SizedBox(width: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// 伝説・幻をはじめて見つけたときの、特別なお祝い
/// 金色の光がくるくる回る背景に、ポケモンを大きく出して、ファンファーレを鳴らす
class LegendaryFoundDialog extends ConsumerStatefulWidget {
  final List<Pokemon> pokemons; // 見つけた伝説・幻（1匹以上）

  const LegendaryFoundDialog({super.key, required this.pokemons});

  @override
  ConsumerState<LegendaryFoundDialog> createState() =>
      _LegendaryFoundDialogState();
}

class _LegendaryFoundDialogState extends ConsumerState<LegendaryFoundDialog>
    with SingleTickerProviderStateMixin {
  // 光が1周するのに8秒（ずっとくり返す）
  late final _rays = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  );

  @override
  void initState() {
    super.initState();
    // 全問正解と同じ、特別なファンファーレ
    ref.read(soundServiceProvider).playJingle('se/result_perfect.wav');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 「動きを減らす」の設定のときは、光を回さない
    if (MediaQuery.disableAnimationsOf(context)) {
      _rays.stop();
    } else if (!_rays.isAnimating) {
      _rays.repeat();
    }
  }

  @override
  void dispose() {
    _rays.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final first = widget.pokemons.first;
    final legendary = Legendary.isLegendary(first.id);

    return Dialog(
      backgroundColor: const Color(0xFFFFF8E1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: const BorderSide(color: Color(0xFFF9A825), width: 4),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 中身は、入りきらない小さい画面ではスクロールできるようにする
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Text(
                      legendary ? 'でんせつの ポケモンを\nみつけた！' : 'まぼろしの ポケモンを\nみつけた！',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Colors.deepOrange,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // 回る光の上に、ポケモンを大きく
                    SizedBox(
                      width: 200,
                      height: 200,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned.fill(
                            child: AnimatedBuilder(
                              animation: _rays,
                              builder: (context, _) => CustomPaint(
                                painter: RaysPainter(_rays.value * 2 * pi),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 155,
                            height: 155,
                            child: CachedImage(
                              url:
                                  first.artworkUrl ??
                                  PokeApiClient.artworkUrl(first.id),
                            ),
                          ),
                        ],
                      ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        first.name,
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    SpecialBadge(id: first.id, fontSize: 18),
                    // 1回のゲームで2匹以上見つけたときは、ほかの子を横にスワイプできる1列で
                    // （でんせつクイズで全問正解すると10匹見つけることもある）
                    if (widget.pokemons.length > 1) ...[
                      const SizedBox(height: 8),
                      Text('ほかにも ${widget.pokemons.length - 1}ひき！'),
                      const SizedBox(height: 4),
                      SizedBox(
                        height: 56,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          shrinkWrap: true,
                          children: [
                            for (final p in widget.pokemons.skip(1))
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                ),
                                child: SizedBox.square(
                                  dimension: 56,
                                  child: CachedImage(
                                    url:
                                        p.artworkUrl ??
                                        PokeApiClient.artworkUrl(p.id),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // ボタンは、いつも下に見えるようにする
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFF9A825),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('やったね！'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 金色の光（放射状の線）を、angle だけ回して描く
class RaysPainter extends CustomPainter {
  final double angle;
  RaysPainter(this.angle);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    // まん中のやわらかい光
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFF59D),
            const Color(0xFFFFF59D).withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
    // 12本の光の帯
    const count = 12;
    final paint = Paint()
      ..color = const Color(0xFFFFC107).withValues(alpha: 0.35);
    for (var i = 0; i < count; i++) {
      final a = angle + i * 2 * pi / count;
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(
          center.dx + cos(a - 0.12) * radius,
          center.dy + sin(a - 0.12) * radius,
        )
        ..lineTo(
          center.dx + cos(a + 0.12) * radius,
          center.dy + sin(a + 0.12) * radius,
        )
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(RaysPainter old) => old.angle != angle;
}
