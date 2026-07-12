import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class RatingDisplay extends StatelessWidget {
  final double rating;
  final double size;
  final bool showValue;
  final int? count;

  const RatingDisplay({
    super.key,
    required this.rating,
    this.size = 20,
    this.showValue = true,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fullStars = rating.floor();
    final hasHalfStar = rating - fullStars >= 0.5;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(5, (i) {
          if (i < fullStars) {
            return Icon(Icons.star_rounded, size: size, color: AppColors.rating);
          } else if (i == fullStars && hasHalfStar) {
            return Icon(Icons.star_half_rounded, size: size, color: AppColors.rating);
          } else {
            return Icon(Icons.star_outline_rounded, size: size, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3));
          }
        }),
        if (showValue) ...[
          const SizedBox(width: 4),
          Text(
            rating.toStringAsFixed(1),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.rating,
            ),
          ),
        ],
        if (count != null) ...[
          const SizedBox(width: 4),
          Text(
            '($count)',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}
