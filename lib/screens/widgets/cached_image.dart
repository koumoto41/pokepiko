import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../providers/data_providers.dart';

/// 端末に保存した画像を表示する（無ければダウンロードして保存してから表示）
/// Image.network の代わりに使うと、2回目以降はオフラインでも表示できる
class CachedImage extends ConsumerStatefulWidget {
  final String url;
  final BoxFit fit;
  final FilterQuality filterQuality;
  final double? width;
  final double? height;
  final Widget error; // 読み込めなかったときに出すもの

  const CachedImage({
    super.key,
    required this.url,
    this.fit = BoxFit.contain,
    this.filterQuality = FilterQuality.medium,
    this.width,
    this.height,
    this.error = const Icon(Icons.help_outline, size: 80),
  });

  @override
  ConsumerState<CachedImage> createState() => _CachedImageState();
}

class _CachedImageState extends ConsumerState<CachedImage> {
  late Future<File> _file;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // 同じ場所で別のポケモンに変わったら、読み込み直す
  @override
  void didUpdateWidget(CachedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) _load();
  }

  void _load() {
    // build のたびに読み込まないよう、Future を State にとっておく
    _file = ref.read(pokemonRepositoryProvider).getImage(widget.url);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<File>(
      future: _file,
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: widget.error);
        final file = snapshot.data;
        if (file == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return Image.file(
          file,
          fit: widget.fit,
          filterQuality: widget.filterQuality,
          width: widget.width,
          height: widget.height,
          errorBuilder: (context, error, stack) => Center(child: widget.error),
        );
      },
    );
  }
}
