import 'package:flutter/material.dart';

class GeneratedCover extends StatelessWidget {
  final String title;
  final String? author;
  final double fontSize;
  final double iconSize;

  const GeneratedCover({
    super.key,
    required this.title,
    this.author,
    this.fontSize = 12,
    this.iconSize = 20,
  });

  static const List<List<Color>> _palette = [
    [Color(0xFFE53935), Color(0xFF7C4DFF)],
    [Color(0xFF1A73E8), Color(0xFF00BCD4)],
    [Color(0xFF34A853), Color(0xFF00E676)],
    [Color(0xFFFF6D00), Color(0xFFFFB300)],
    [Color(0xFF7C4DFF), Color(0xFFFF6B6B)],
    [Color(0xFF00897B), Color(0xFF4DB6AC)],
    [Color(0xFF5E35B1), Color(0xFF3949AB)],
    [Color(0xFFD81B60), Color(0xFFFFB300)],
  ];

  List<Color> get _colors {
    final seed = (title.hashCode % _palette.length).abs();
    return _palette[seed];
  }

  @override
  Widget build(BuildContext context) {
    final colors = _colors;
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_stories_rounded, color: Colors.white.withOpacity(0.85), size: iconSize),
          const SizedBox(height: 8),
          Text(
            title,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: fontSize,
              height: 1.2,
            ),
          ),
          if (author != null && author!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              author!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: fontSize - 2),
            ),
          ],
        ],
      ),
    );
  }
}