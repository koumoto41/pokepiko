import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../app_theme.dart';
import '../data/poke_api_client.dart';
import '../data/sound_service.dart';
import '../models/generation.dart';
import '../providers/collection_provider.dart';
import '../providers/sound_provider.dart';
import 'route_names.dart';
import 'widgets/cached_image.dart';
import 'widgets/celebration.dart';
import 'widgets/legendary_widgets.dart';

/// 図鑑かんせいの おめでとう画面
/// ある世代のポケモンを ぜんぶ みつけたときに、いちばん豪華なファンファーレと花火でお祝いする
class DexCompleteScreen extends ConsumerStatefulWidget {
  final List<Generation> generations; // うまった世代（ふつうは1つ）

  const DexCompleteScreen({super.key, required this.generations});

  static const jingle = 'se/dex_complete.wav';

  /// この画面を開くときの画面遷移（BGM を止めるために名前をつける）
  static Route<void> route(List<Generation> generations) => MaterialPageRoute(
    settings: const RouteSettings(name: RouteNames.dexComplete),
    builder: (_) => DexCompleteScreen(generations: generations),
  );

  @override
  ConsumerState<DexCompleteScreen> createState() => _DexCompleteScreenState();
}

class _DexCompleteScreenState extends ConsumerState<DexCompleteScreen>
    with SingleTickerProviderStateMixin {
  // 光が1周するのに8秒（ずっとくり返す）
  late final _rays = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  );
  late final SoundService _sound; // dispose では ref が使えないので、先に取り出しておく

  @override
  void initState() {
    super.initState();
    _sound = ref.read(soundServiceProvider)
      ..playJingle(DexCompleteScreen.jingle);
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
    _sound.stopJingle(); // 画面を閉じたら、ファンファーレも止める
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final found = ref.watch(collectionProvider).value ?? const <int>{};
    // 全国図鑑（全世代）がうまったら、特別な言葉にする
    final allComplete = Generation.allIds.every(found.contains);
    final generations = widget.generations;
    final title = allComplete
        ? 'ぜんこく ずかん\nかんせい！'
        : '${generations.map((g) => g.region).join('・')} ずかん\nかんせい！';
    final count = allComplete
        ? Generation.all.last.lastId
        : generations.fold(0, (sum, g) => sum + g.count);
    final compact = context.isCompactHeight;

    return GradientBackground(
      colors: const [Color(0xFFFFE082), Color(0xFFFFF8E1)], // 金色 → クリーム色
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'おめでとう！',
                        style: TextStyle(
                          fontSize: compact ? 44 : 56,
                          fontWeight: FontWeight.w900,
                          color: Colors.deepOrange,
                          shadows: const [
                            Shadow(color: Colors.white, blurRadius: 8),
                          ],
                        ),
                      ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: compact ? 28 : 34,
                          fontWeight: FontWeight.bold,
                          color: AppColors.brown,
                        ),
                      ),
                    ),
                    // 回る光の上に、その世代の代表のポケモンとトロフィー
                    Expanded(
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
                          FractionallySizedBox(
                            widthFactor: 0.7,
                            heightFactor: 0.7,
                            child: CachedImage(
                              url: PokeApiClient.artworkUrl(
                                generations.first.mascotId,
                              ),
                            ),
                          ),
                          Align(
                            alignment: Alignment.bottomRight,
                            child: Icon(
                              Icons.emoji_events,
                              color: const Color(0xFFF9A825),
                              size: compact ? 72 : 96,
                              shadows: const [
                                Shadow(color: Colors.black26, blurRadius: 6),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '$count ひき ぜんぶ みつけたよ！',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(height: compact ? 12 : 20),
                    SizedBox(
                      width: double.infinity,
                      height: compact ? 64 : 72,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFF9A825),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(36),
                          ),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text(
                          'やったね！',
                          style: TextStyle(fontSize: 30),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // 花火と風船（タップは下のボタンに届く）
          const Positioned.fill(child: Celebration()),
        ],
      ),
    );
  }
}
