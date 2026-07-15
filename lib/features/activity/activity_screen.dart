import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "../../core/providers.dart";
import "../../core/theme/app_colors.dart";
import "../../data/models/book_model.dart";
import "../../data/services/storage_service.dart";
import "../../data/models/reading_goal_model.dart";

final _streakProvider = FutureProvider<int>((ref) async {
  final box = await StorageService.openUserProfileBox();
  final user = box.values.isNotEmpty ? box.values.first : null;
  return user?.readingStreak ?? 0;
});

final _readingGoalProvider = FutureProvider<ReadingGoalModel?>((ref) async {
  final box = await StorageService.openReadingGoalsBox();
  final goals = box.values.toList();
  if (goals.isEmpty) return null;
  goals.sort((a, b) => b.endDate.compareTo(a.endDate));
  return goals.first;
});

final _readingDatesProvider = FutureProvider<Set<DateTime>>((ref) async {
  final box = await StorageService.openReadingProgressBox();
  final dates = <DateTime>{};
  for (final progress in box.values) {
    final d = progress.lastReadAt;
    dates.add(DateTime(d.year, d.month, d.day));
  }
  return dates;
});

class _ActivityItem {
  final String bookTitle;
  final String action;
  final IconData icon;
  final Color iconColor;
  final DateTime timestamp;
  final double progress;

  const _ActivityItem({
    required this.bookTitle,
    required this.action,
    required this.icon,
    required this.iconColor,
    required this.timestamp,
    required this.progress,
  });
}

List<_ActivityItem> _buildActivityItems(List<BookModel> books) {
  final items = <_ActivityItem>[];
  for (final book in books) {
    items.add(_ActivityItem(
      bookTitle: book.title,
      action: "Added to library",
      icon: Icons.add_circle_outline_rounded,
      iconColor: AppColors.wantToRead,
      timestamp: book.createdAt,
      progress: 0,
    ));
  }
  for (final book in books.where((b) => b.progress > 0)) {
    final ts = book.lastOpenedAt ?? book.updatedAt;
    final isFinished = book.progress >= 1;
    items.add(_ActivityItem(
      bookTitle: book.title,
      action: isFinished ? "Finished reading" : "Reading update",
      icon: isFinished ? Icons.check_circle_rounded : Icons.menu_book_rounded,
      iconColor: isFinished ? AppColors.finished : AppColors.reading,
      timestamp: ts,
      progress: book.progress,
    ));
  }
  items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
  return items;
}

String _formatRelativeTime(DateTime date) {
  final now = DateTime.now();
  final diff = now.difference(date);
  if (diff.inMinutes < 1) return "Just now";
  if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
  if (diff.inHours < 24) return "${diff.inHours}h ago";
  if (diff.inDays < 7) return "${diff.inDays}d ago";
  if (diff.inDays < 30) return "${(diff.inDays / 7).floor()}w ago";
  return "${(diff.inDays / 30).floor()}mo ago";
}

class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final books = ref.watch(allBooksProvider).asData?.value ?? [];
    final totalBooks = ref.watch(totalBooksProvider).asData?.value ?? 0;
    final totalPages = ref.watch(totalPagesReadProvider).asData?.value ?? 0;
    final streak = ref.watch(_streakProvider).asData?.value ?? 0;
    final readingGoal = ref.watch(_readingGoalProvider).asData?.value;
    final readingDates = ref.watch(_readingDatesProvider).asData?.value ?? {};
    final activityItems = _buildActivityItems(books);
    final finishedCount = books.where((b) => b.progress >= 1).length;

    return Scaffold(
      appBar: AppBar(title: const Text("Activity")),
      body: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _buildStatsRow(totalBooks, totalPages, streak, finishedCount, theme, colorScheme),
            const SizedBox(height: 20),
            if (readingGoal != null && readingGoal.targetBooks > 0) ...[
              _buildReadingGoal(context, readingGoal, colorScheme),
              const SizedBox(height: 20),
            ],
            _sectionHeader("Activity Timeline"),
            const SizedBox(height: 12),
            if (activityItems.isEmpty)
              _buildEmptyActivity(theme, colorScheme)
            else
              ...activityItems.take(20).map((item) => _TimelineItem(item: item, theme: theme)),
            const SizedBox(height: 20),
            _sectionHeader("Reading Heatmap"),
            const SizedBox(height: 12),
            _buildHeatmap(context, streak, readingDates, colorScheme),
          ],
        ),
      ),
    );
  }

  Future<void> _refresh(WidgetRef ref) async {
    await Future.wait([
      ref.refresh(allBooksProvider.future),
      ref.refresh(totalBooksProvider.future),
      ref.refresh(totalPagesReadProvider.future),
    ]);
  }

  Widget _sectionHeader(String title) {
    return Row(
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildStatsRow(int totalBooks, int totalPages, int streak, int finishedCount, ThemeData theme, ColorScheme colorScheme) {
    return Row(
      children: [
        _StatPill(value: "$finishedCount", label: "Finished", icon: Icons.check_circle_rounded, color: AppColors.finished),
        const SizedBox(width: 8),
        _StatPill(value: "$totalPages", label: "Pages", icon: Icons.menu_book_rounded, color: AppColors.reading),
        const SizedBox(width: 8),
        _StatPill(value: "$streak", label: "Day Streak", icon: Icons.local_fire_department_rounded, color: AppColors.streak),
      ],
    );
  }

  Widget _buildReadingGoal(BuildContext context, ReadingGoalModel goal, ColorScheme colorScheme) {
    final theme = Theme.of(context);
    final progress = goal.overallProgress.clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: AppColors.streak.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.flag_rounded, color: AppColors.streak, size: 16),
              ),
              const SizedBox(width: 10),
              Text("Reading Goal", style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              const Spacer(),
              Text("${(progress * 100).toInt()}%", style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.accent, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: colorScheme.surfaceContainerHighest,
              color: AppColors.streak,
            ),
          ),
          const SizedBox(height: 8),
          Text("${goal.currentBooks} / ${goal.targetBooks} books", style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildEmptyActivity(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(Icons.history_rounded, size: 48, color: colorScheme.onSurfaceVariant.withOpacity(0.3)),
          const SizedBox(height: 12),
          Text("No Activity Yet", style: theme.textTheme.titleSmall?.copyWith(color: colorScheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text("Start reading to see your activity here", style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant.withOpacity(0.6))),
        ],
      ),
    );
  }

  Widget _buildHeatmap(BuildContext context, int streak, Set<DateTime> readingDates, ColorScheme colorScheme) {
    final now = DateTime.now();

    final cells = <Widget>[];
    for (int w = 0; w < 26; w++) {
      for (int d = 0; d < 7; d++) {
        final dayOffset = (25 - w) * 7 + (6 - d);
        final date = now.subtract(Duration(days: dayOffset));
        final isActive = readingDates.contains(DateTime(date.year, date.month, date.day));
        cells.add(
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: isActive ? AppColors.accent : colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_month_rounded, size: 16, color: AppColors.accent),
              const SizedBox(width: 6),
              Text("Last 6 months", style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: AppColors.streak.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.local_fire_department_rounded, size: 12, color: AppColors.streak),
                    const SizedBox(width: 3),
                    Text("$streak day${streak == 1 ? "" : "s"}", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.streak)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 2,
            runSpacing: 2,
            children: cells,
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const _StatPill({required this.value, required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 4),
            Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: color)),
            Text(label, style: theme.textTheme.labelSmall?.copyWith(color: color.withOpacity(0.7), fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final _ActivityItem item;
  final ThemeData theme;

  const _TimelineItem({required this.item, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: item.iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(item.icon, color: item.iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: theme.textTheme.bodyMedium,
                    children: [
                      TextSpan(text: item.action, style: const TextStyle(fontWeight: FontWeight.w500)),
                      TextSpan(text: " ${item.bookTitle}", style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.accent)),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(_formatRelativeTime(item.timestamp), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontSize: 11)),
                    if (item.progress > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                        child: Text("${(item.progress * 100).toInt()}%", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.accent)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
