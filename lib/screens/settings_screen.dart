import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../app_theme.dart';
import '../data/poke_api_client.dart';
import '../models/generation.dart';
import '../models/quiz_settings.dart';
import '../providers/data_providers.dart';
import '../providers/settings_provider.dart';
import 'quiz_screen.dart';
import 'route_names.dart';
import 'widgets/cached_image.dart';

/// 設定画面：出題する世代（複数可）とモードを選んで「スタート」
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  // モードごとのアイコンと色（文字が読めなくても選べるように）
  static const _modeIcons = {
    QuizMode.illustration: Icons.image,
    QuizMode.pixel: Icons.grid_on,
    QuizMode.silhouette: Icons.help,
  };
  static const _kindIcons = {
    QuizKind.name: Icons.badge,
    QuizKind.type: Icons.local_fire_department,
    QuizKind.legendary: Icons.auto_awesome,
  };
  static const _kindColors = {
    QuizKind.name: Colors.teal,
    QuizKind.type: Colors.deepPurple,
    QuizKind.legendary: Color(0xFFF9A825), // 金色
  };
  static const _modeColors = {
    QuizMode.illustration: Colors.orange,
    QuizMode.pixel: Colors.green,
    QuizMode.silhouette: Colors.indigo,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsProvider.notifier);
    final allSelected = settings.generations.length == Generation.all.length;
    final legendaryQuiz = settings.kind == QuizKind.legendary;

    return GradientBackground(
      colors: const [Color(0xFFC8E6C9), AppColors.cream], // 若草色 → クリーム色
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('せってい')),
        body: SafeArea(
          child: Column(
            children: [
              // 画面が小さくても全部見られるように、ここだけスクロールできる
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Row(
                      children: [
                        const Expanded(child: _SectionTitle('せだい')),
                        FilterChip(
                          label: const Text(
                            'ぜんぶ',
                            style: TextStyle(fontSize: 18),
                          ),
                          selected: allSelected,
                          onSelected: (_) => controller.toggleAllGenerations(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // 世代を3列のタイルで並べる
                    // でんせつクイズは世代に関係なく出すので、うすくして押せないようにする
                    IgnorePointer(
                      ignoring: legendaryQuiz,
                      child: Opacity(
                        opacity: legendaryQuiz ? 0.35 : 1,
                        child: GridView.count(
                          crossAxisCount: 3,
                          shrinkWrap: true, // ListView の中に入れるため
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          // 横長のタイル（左に絵、右に数字）。縦の幅を節約して、SE でもモードまで見えるように
                          childAspectRatio: 1.6,
                          children: [
                            for (final g in Generation.all)
                              _GenerationTile(
                                generation: g,
                                selected: settings.generations.contains(
                                  g.number,
                                ),
                                onTap: () =>
                                    controller.toggleGeneration(g.number),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      legendaryQuiz
                          ? 'でんせつクイズは ぜんぶの せだいから でるよ'
                                '（${settings.candidateIds.length} ひき）'
                          : '${settings.candidateIds.length} ひきから しゅつだい',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    const _SectionTitle('モード'),
                    const SizedBox(height: 8),
                    // クイズの種類
                    _OptionRow<QuizKind>(
                      values: QuizKind.values,
                      selected: settings.kind,
                      label: (k) => '${k.label}クイズ',
                      icon: (k) => _kindIcons[k]!,
                      color: (k) => _kindColors[k]!,
                      onSelect: controller.setKind,
                    ),
                    // タイプクイズのときだけ、問題の向きを選ぶ
                    if (settings.kind == QuizKind.type) ...[
                      const SizedBox(height: 8),
                      _OptionRow<TypeDirection>(
                        values: TypeDirection.values,
                        selected: settings.typeDirection,
                        label: (d) => d.label,
                        color: (_) => Colors.deepPurple,
                        onSelect: controller.setTypeDirection,
                      ),
                    ],
                    const SizedBox(height: 8),
                    // 画像の見せかた
                    _OptionRow<QuizMode>(
                      values: QuizMode.values,
                      selected: settings.mode,
                      label: (m) => m.label,
                      icon: (m) => _modeIcons[m]!,
                      color: (m) => _modeColors[m]!,
                      onSelect: controller.setMode,
                    ),
                    const SizedBox(height: 6),
                    // シルエットで正解すると図鑑に入ることを、ここでも知らせる
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.menu_book,
                          size: 20,
                          color: settings.mode == QuizMode.silhouette
                              ? Colors.orange
                              : Colors.black38,
                        ),
                        const SizedBox(width: 4),
                        // 小さい画面でもはみ出さないよう、入りきらなければ縮める
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              settings.mode == QuizMode.silhouette
                                  ? 'せいかいすると ずかんに はいるよ！'
                                  : 'シルエットで せいかいすると ずかんに はいるよ',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                    // ダウンロードは保護者向けなので、いちばん下に置く
                    const SizedBox(height: 24),
                    _DownloadSection(ids: settings.candidateIds),
                  ],
                ),
              ),
              // スタートボタンは常に画面の下に見えるようにする
              Padding(
                padding: EdgeInsets.all(context.isCompactHeight ? 12 : 16),
                child: SizedBox(
                  width: double.infinity,
                  height: context.isCompactHeight ? 64 : 72,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(36),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        settings: const RouteSettings(name: RouteNames.quiz),
                        builder: (_) => const QuizScreen(),
                      ),
                    ),
                    child: const Text('スタート！', style: TextStyle(fontSize: 32)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
    );
  }
}

/// 世代のタイル（数字を大きく、地方名を小さく）
class _GenerationTile extends StatelessWidget {
  final Generation generation;
  final bool selected;
  final VoidCallback onTap;

  const _GenerationTile({
    required this.generation,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _SelectTile(
      selected: selected,
      color: Colors.blue,
      onTap: onTap,
      padding: const EdgeInsets.all(6),
      child: Row(
        children: [
          // 代表のポケモン（えらばれていないときは うすく表示）
          Expanded(
            flex: 5,
            child: Opacity(
              opacity: selected ? 1.0 : 0.4,
              child: CachedImage(
                url: PokeApiClient.artworkUrl(generation.mascotId),
                // 読み込めないとき（オフラインなど）は絵なしで数字だけ
                error: const SizedBox(),
              ),
            ),
          ),
          // 数字と地方名（入りきらなければ縮める）
          Expanded(
            flex: 4,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                children: [
                  Text(
                    '${generation.number}',
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(generation.region, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// えらばれていると色がつく、押しやすいタイル
class _SelectTile extends StatelessWidget {
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  final Widget child;
  final EdgeInsets padding;

  const _SelectTile({
    required this.selected,
    required this.color,
    required this.onTap,
    required this.child,
    this.padding = const EdgeInsets.symmetric(vertical: 12),
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color : Colors.grey.shade200,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: padding,
          // 中の文字・アイコンの色を、えらばれているかどうかでまとめて変える
          child: IconTheme(
            data: IconThemeData(
              color: selected ? Colors.white : Colors.black54,
            ),
            child: DefaultTextStyle.merge(
              style: TextStyle(color: selected ? Colors.white : Colors.black54),
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
  }
}

/// 保存済みの数と、まとめてダウンロードするボタン（保護者向け）
/// 上の段：えらんでいる世代、下の段：全国図鑑すべて
class _DownloadSection extends ConsumerWidget {
  final List<int> ids; // 選んでいる世代の図鑑番号

  const _DownloadSection({required this.ids});

  // 全国図鑑すべてを保存したときの、だいたいの容量（公式イラスト1枚 約140KB × 1025匹）
  static const _allSizeLabel = '約150MB';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 読み込み中は 0 として表示
    final cached = ref.watch(cachedIdsProvider).value ?? const <int>{};
    final allIds = Generation.allIds;
    // 全世代をえらんでいるときは、下の段だけ出す（同じ内容が2つ並ばないように）
    final showSelected = ids.length != allIds.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            if (showSelected) ...[
              _DownloadRow(
                label: 'えらんだ せだい',
                ids: ids,
                cached: cached,
                onDownload: () => _startDownload(context, ids),
              ),
              const Divider(),
            ],
            _DownloadRow(
              label: 'ぜんこく ずかん',
              ids: allIds,
              cached: cached,
              onDownload: () => _confirmDownloadAll(context, allIds),
            ),
          ],
        ),
      ),
    );
  }

  void _startDownload(BuildContext context, List<int> ids) {
    showDialog<void>(
      context: context,
      barrierDismissible: false, // 外側を押しても閉じない
      builder: (_) => _DownloadDialog(ids: ids),
    );
  }

  /// 全部は容量も時間もかかるので、確認してから始める
  Future<void> _confirmDownloadAll(BuildContext context, List<int> ids) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ぜんぶ ダウンロードしますか？'),
        content: Text(
          '全国図鑑 ${ids.length}匹ぶんの名前と画像を保存します。\n'
          '・容量：$_allSizeLabel くらい\n'
          '・時間：数分〜10分ほど\n'
          'Wi-Fi につないだ状態でおすすめします。\n'
          '保存済みのポケモンはとばすので、途中でやめても続きからできます。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('やめる'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('ダウンロード'),
          ),
        ],
      ),
    );
    // await のあいだに画面が閉じられていたら何もしない
    if (ok == true && context.mounted) _startDownload(context, ids);
  }
}

/// 「○○：ほぞんずみ X / Y ひき [ダウンロード]」の1行
class _DownloadRow extends StatelessWidget {
  final String label;
  final List<int> ids;
  final Set<int> cached;
  final VoidCallback onDownload;

  const _DownloadRow({
    required this.label,
    required this.ids,
    required this.cached,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final savedCount = ids.where(cached.contains).length;
    final allSaved = savedCount == ids.length;

    return Row(
      children: [
        Icon(
          allSaved ? Icons.offline_pin : Icons.cloud_download,
          color: allSaved ? Colors.green : Colors.grey,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(
                allSaved
                    ? 'ぜんぶ ほぞんずみ（オフラインで あそべる）'
                    : 'ほぞんずみ $savedCount / ${ids.length} ひき',
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
        if (!allSaved)
          // 保護者向けのボタンなので、テーマの大きい文字ではなく小さめにする
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            onPressed: onDownload,
            child: const Text('ダウンロード'),
          ),
      ],
    );
  }
}

/// ダウンロードの進み具合を出すダイアログ
class _DownloadDialog extends ConsumerStatefulWidget {
  final List<int> ids;
  const _DownloadDialog({required this.ids});

  @override
  ConsumerState<_DownloadDialog> createState() => _DownloadDialogState();
}

class _DownloadDialogState extends ConsumerState<_DownloadDialog> {
  int _done = 0;
  int? _failed; // null のあいだはダウンロード中
  bool _cancelled = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    // 「やめる」でダイアログを閉じたあとも最後に表示を更新できるよう、
    // ref ではなく Provider の入れ物（container）を先にとっておく
    // （閉じたあとの画面の ref は使えないため）
    final container = ProviderScope.containerOf(context, listen: false);
    final failed = await container
        .read(pokemonRepositoryProvider)
        .downloadAll(
          widget.ids,
          onProgress: (done, _) {
            if (mounted) setState(() => _done = done);
          },
          isCancelled: () => _cancelled,
        );
    // 保存済みの数を読み直して、設定画面の表示を更新する
    container.invalidate(cachedIdsProvider);
    if (mounted) setState(() => _failed = failed);
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.ids.length;
    final finished = _failed != null;

    return AlertDialog(
      title: Text(finished ? 'おわったよ' : 'ダウンロードちゅう…'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LinearProgressIndicator(value: total == 0 ? null : _done / total),
          const SizedBox(height: 12),
          Text('$_done / $total ひき'),
          if (finished && _failed! > 0)
            Text('$_failed ひき しっぱい（もういちど おすと やりなおせます）'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            if (finished) {
              Navigator.of(context).pop();
            } else {
              // やめる：いまダウンロード中の分が終わったら止まる
              setState(() => _cancelled = true);
              Navigator.of(context).pop();
            }
          },
          child: Text(finished ? 'とじる' : 'やめる'),
        ),
      ],
    );
  }
}

/// 1つだけ選べるタイルを横に並べた段（モードの選択で使う）
/// `T`：選ぶものの型（QuizKind など）。同じ部品をいろいろな選択に使い回せる
class _OptionRow<T> extends StatelessWidget {
  final List<T> values;
  final T selected;
  final String Function(T) label;
  final IconData Function(T)? icon;
  final Color Function(T) color;
  final void Function(T) onSelect;

  const _OptionRow({
    required this.values,
    required this.selected,
    required this.label,
    required this.color,
    required this.onSelect,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final (i, v) in values.indexed) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _SelectTile(
              selected: v == selected,
              color: color(v),
              onTap: () => onSelect(v),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
              // アイコンと文字を横に並べて、低いタイルにする（SE でも場所をとらない）
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon!(v), size: 26),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      label(v),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
