import 'package:material_ui/material_ui.dart';

import '../../models/poke_type.dart';

/// タイプを、そのタイプの色の丸いラベルで見せる（例：赤地に白で「ほのお」）
class TypeBadge extends StatelessWidget {
  final PokeType type;
  final double fontSize;

  const TypeBadge({super.key, required this.type, this.fontSize = 16});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: fontSize * 0.8,
        vertical: fontSize * 0.25,
      ),
      decoration: BoxDecoration(
        color: type.color,
        borderRadius: BorderRadius.circular(fontSize),
      ),
      child: Text(
        type.label,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// ポケモンが持っているタイプを並べて見せる（1つか2つ）
class TypeBadges extends StatelessWidget {
  final List<PokeType> types;
  final double fontSize;

  const TypeBadges({super.key, required this.types, this.fontSize = 14});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 4,
      runSpacing: 4,
      children: [for (final t in types) TypeBadge(type: t, fontSize: fontSize)],
    );
  }
}
