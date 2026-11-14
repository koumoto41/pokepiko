import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/poke_api_client.dart';
import '../../providers/data_providers.dart';
import 'cached_image.dart';

/// タイトル画面の「ポケピコ」のロゴ（白いふちどりと影で、ゲームのロゴらしく）
class TitleLogo extends StatelessWidget {
  final double fontSize;

  const TitleLogo({super.key, required this.fontSize});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w900,
      letterSpacing: 2,
    );
    // 同じ文字を2回重ねる：下は太い白のふちどり、上はオレンジ〜赤のグラデーション
    return Stack(
      children: [
        Text(
          'ポケピコ',
          style: style.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = fontSize * 0.16
              ..strokeJoin = StrokeJoin.round
              ..color = Colors.white,
            shadows: const [
              Shadow(
                color: Colors.black26,
                offset: Offset(0, 4),
                blurRadius: 6,
              ),
            ],
          ),
        ),
        // ShaderMask：文字の形の中だけに、グラデーションを塗る
        ShaderMask(
          shaderCallback: (rect) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFA000), Color(0xFFE53935)],
          ).createShader(rect),
          child: Text('ポケピコ', style: style.copyWith(color: Colors.white)),
        ),
      ],
    );
  }
}

/// 主役のポケモン：ふわふわ上下に動き、押すとぴょんと跳ねる
/// （押したときに別のポケモンに変えるのは、使う側が onTap で id を変える）
class FeaturedPokemon extends ConsumerStatefulWidget {
  final int id;
  final double size;
  final VoidCallback? onTap;

  const FeaturedPokemon({
    super.key,
    required this.id,
    required this.size,
    this.onTap,
  });

  @override
  ConsumerState<FeaturedPokemon> createState() => _FeaturedPokemonState();
}

class _FeaturedPokemonState extends ConsumerState<FeaturedPokemon>
    with SingleTickerProviderStateMixin {
  // 1.6秒で上に行って、1.6秒で下に戻る（くり返し）
  late final _bob = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  bool _jump = false; // 押したときに、ぴょんとはねる

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 「動きを減らす」の設定のときは、動かさない
    if (MediaQuery.disableAnimationsOf(context)) {
      _bob.stop();
    } else if (!_bob.isAnimating) {
      _bob.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _bob.dispose();
    super.dispose();
  }

  void _onTap() {
    setState(() => _jump = true);
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _jump = false);
    });
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final name = ref.watch(pokemonProvider(widget.id)).value?.name;

    return GestureDetector(
      onTap: _onTap,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: _bob,
          builder: (context, child) => Transform.translate(
            offset: Offset(
              0,
              -8 * Curves.easeInOut.transform(_bob.value) - (_jump ? 16 : 0),
            ),
            child: child,
          ),
          // AnimatedSwitcher：id が変わったら、前のポケモンが小さくなって消え、
          // 新しいポケモンが大きくなって出てくる（ポンと入れかわる）
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, animation) => ScaleTransition(
              scale: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutBack,
              ),
              child: child,
            ),
            child: Column(
              key: ValueKey(widget.id),
              children: [
                Expanded(
                  child: CachedImage(
                    url: PokeApiClient.artworkUrl(widget.id),
                    error: const Icon(
                      Icons.catching_pokemon,
                      size: 72,
                      color: Colors.red,
                    ),
                  ),
                ),
                // 名前のふだ
                if (name != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
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

/// 背景：いろいろなポケモンのシルエットが、うっすらと下から上へ漂う
class FloatingSilhouettes extends StatefulWidget {
  final List<int> ids; // 使うポケモンの図鑑番号

  const FloatingSilhouettes({super.key, required this.ids});

  @override
  State<FloatingSilhouettes> createState() => _FloatingSilhouettesState();
}

class _FloatingSilhouettesState extends State<FloatingSilhouettes>
    with SingleTickerProviderStateMixin {
  static const _count = 8;
  static const _period = Duration(seconds: 40); // 1周（下から上まで）の時間

  late final _controller = AnimationController(vsync: this, duration: _period);

  // シルエットごとの横の位置・大きさ・ずれ（はじめに決めておく）
  final _random = Random();
  late final _items = [
    for (var i = 0; i < _count; i++)
      (
        x: (i + 0.5) / _count + (_random.nextDouble() - 0.5) * 0.08,
        offset: i / _count, // 縦の位置のずれ（みんな同じ高さにならないように）
        size: 70 + _random.nextDouble() * 50,
        sway: _random.nextDouble() * pi * 2,
      ),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.ids.isEmpty) return const SizedBox.shrink();
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, box) => AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => Stack(
            children: [
              for (final (i, item) in _items.indexed)
                _silhouette(
                  widget.ids[i % widget.ids.length],
                  item,
                  box.biggest,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _silhouette(
    int id,
    ({double x, double offset, double size, double sway}) item,
    Size area,
  ) {
    // 0〜1 で下から上へ。1をこえたら下にもどる（ずっとくり返す）
    final p = (_controller.value + item.offset) % 1.0;
    final y = area.height + item.size - p * (area.height + item.size * 2);
    final x =
        item.x * area.width + sin(p * pi * 4 + item.sway) * 18 - item.size / 2;
    return Positioned(
      left: x,
      top: y,
      width: item.size,
      height: item.size,
      child: Opacity(
        opacity: 0.09,
        // srcIn：絵の形のまま、色だけ黒にする（シルエット）
        child: ColorFiltered(
          colorFilter: const ColorFilter.mode(Colors.black, BlendMode.srcIn),
          child: CachedImage(
            url: PokeApiClient.artworkUrl(id),
            error: const SizedBox(),
          ),
        ),
      ),
    );
  }
}
