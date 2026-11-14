import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/poke_api_client.dart';
import '../../providers/data_providers.dart';
import '../../providers/sound_provider.dart';
import 'cached_image.dart';

/// 「しんかの なかまが ぜんぶ そろったよ！」のお祝い
/// families：そろった仲間（例：[[1, 2, 3], [25, 26, 172]]）
class FamilyCompleteDialog extends ConsumerStatefulWidget {
  final List<List<int>> families;

  const FamilyCompleteDialog({super.key, required this.families});

  @override
  ConsumerState<FamilyCompleteDialog> createState() =>
      _FamilyCompleteDialogState();
}

class _FamilyCompleteDialogState extends ConsumerState<FamilyCompleteDialog> {
  @override
  void initState() {
    super.initState();
    // お祝いの曲（結果画面の 8〜9問 と同じ、きらきらした曲）
    ref.read(soundServiceProvider).playJingle('se/result_great.wav');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFFFFFDE7),
      title: const Column(
        children: [
          Icon(Icons.emoji_events, color: Colors.amber, size: 64),
          Text(
            'コンプリート！',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.deepOrange,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'しんかの なかまが\nぜんぶ そろったよ！',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            for (final family in widget.families) ...[
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 4,
                runSpacing: 4,
                children: [for (final id in family) _Member(id: id)],
              ),
            ],
          ],
        ),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.orange),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('やったね！'),
        ),
      ],
    );
  }
}

/// 仲間1匹（絵と名前）
class _Member extends ConsumerWidget {
  final int id;
  const _Member({required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(pokemonProvider(id)).value?.name ?? '';
    return SizedBox(
      width: 72,
      child: Column(
        children: [
          SizedBox(
            height: 56,
            child: CachedImage(url: PokeApiClient.artworkUrl(id)),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              name,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
