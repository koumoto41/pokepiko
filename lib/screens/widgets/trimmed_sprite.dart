import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../providers/data_providers.dart';

/// ドット絵を、まわりの透明な余白を切りとってから、場所いっぱいに大きく表示する
/// （PokéAPI のドット絵は 96×96 で、ポケモンは真ん中の一部にしかいないため、
///   そのまま拡大すると小さく見える）
/// 拡大してもぼかさず、カクカクのまま表示する
class TrimmedSprite extends ConsumerStatefulWidget {
  final String url;

  const TrimmedSprite({super.key, required this.url});

  @override
  ConsumerState<TrimmedSprite> createState() => _TrimmedSpriteState();
}

class _TrimmedSpriteState extends ConsumerState<TrimmedSprite> {
  late final Future<({ui.Image image, Rect area})> _sprite = _load();
  ui.Image? _image; // 使い終わったら片づけるため、とっておく

  /// 画像を読み、透明でない点が入っている範囲（ポケモンがいる四角）を調べる
  Future<({ui.Image image, Rect area})> _load() async {
    final file = await ref.read(pokemonRepositoryProvider).getImage(widget.url);
    final codec = await ui.instantiateImageCodec(await file.readAsBytes());
    final image = (await codec.getNextFrame()).image;
    _image = image;

    // 1点ずつ RGBA（赤・緑・青・不透明さ）の4つの数字で並んでいる
    final pixels = (await image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    ))!;
    var left = image.width, top = image.height, right = -1, bottom = -1;
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final alpha = pixels.getUint8((y * image.width + x) * 4 + 3);
        if (alpha > 8) {
          if (x < left) left = x;
          if (x > right) right = x;
          if (y < top) top = y;
          if (y > bottom) bottom = y;
        }
      }
    }
    // 全部透明だったら、切りとらずにそのまま
    final area = right < 0
        ? Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble())
        : Rect.fromLTRB(
            left.toDouble(),
            top.toDouble(),
            right + 1.0,
            bottom + 1.0,
          );
    return (image: image, area: area);
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _sprite,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Icon(Icons.help_outline, size: 80));
        }
        final sprite = snapshot.data;
        if (sprite == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return CustomPaint(
          size: Size.infinite,
          painter: _SpritePainter(sprite.image, sprite.area),
        );
      },
    );
  }
}

/// 切りとった範囲（area）を、縦横の比率を保ったまま、場所のまん中にいっぱいに描く
class _SpritePainter extends CustomPainter {
  final ui.Image image;
  final Rect area;

  _SpritePainter(this.image, this.area);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = (size.width / area.width) < (size.height / area.height)
        ? size.width / area.width
        : size.height / area.height;
    final w = area.width * scale;
    final h = area.height * scale;
    final dst = Rect.fromLTWH(
      (size.width - w) / 2,
      (size.height - h) / 2,
      w,
      h,
    );
    canvas.drawImageRect(
      image,
      area,
      dst,
      Paint()..filterQuality = FilterQuality.none, // ぼかさない
    );
  }

  @override
  bool shouldRepaint(_SpritePainter old) =>
      old.image != image || old.area != area;
}
