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
      action: isFinished ? "Finished" : "Started reading",
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
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatsHeader(context, totalBooks, totalPages, streak, finishedCount),
            const SizedBox(height: 24),
            if (readingGoal != null && readingGoal.targetBooks > 0) ...[
              _buildReadingGoal(context, readingGoal),
              const SizedBox(height: 24),
            ],
            _SectionHeader(icon: Icons.history_rounded, title: "Recent Activity"),
            const SizedBox(height: 12),
            if (activityItems.isEmpty)
              _buildEmptyActivity(context, theme)
            else
              _buildTimeline(context, activityItems),
            const SizedBox(height: 24),
            _SectionHeader(icon: Icons.calendar_month_rounded, title: "Monthly Heatmap"),
            const SizedBox(height: 12),
            _buildCalendar(context, streak, readingDates),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsHeader(
    BuildContext context,
    int totalBooks,
    int totalPages,
    int streak,
    int finishedCount,
  ) {
    return Row(
      children: [
        Expanded(child: _StatCard(
          title: "Books Read",
          value: "$finishedCount",
          icon: Icons.check_circle_rounded,
          iconColor: AppColors.finished,
        )),
        const SizedBox(width: 12),
        Expanded(child: _StatCard(
          title: "Pages Read",
          value: "$totalPages",
          icon: Icons.menu_book_rounded,
          iconColor: AppColors.reading,
        )),
        const SizedBox(width: 12),
        Expanded(child: _StatCard(
          title: "Day Streak",
          value: "$streak",
          icon: Icons.local_fire_department_rounded,
          iconColor: AppColors.streak,
        )),
      ],
    );
  }

  Widget _buildReadingGoal(BuildContext context, ReadingGoalModel goal) {
    final theme = Theme.of(context);
    final progress = goal.overallProgress.clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(icon: Icons.flag_rounded, title: "Reading Goal"),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.streak.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.flag_rounded,
                        color: AppColors.streak,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      "Reading Goal",
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 10,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    color: AppColors.streak,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "${goal.currentBooks} / ${goal.targetBooks} books",
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      "${(progress * 100).toInt()}%",
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeline(BuildContext context, List<_ActivityItem> items) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: List.generate(items.length, (index) {
            final item = items[index];
            final isLast = index == items.length - 1;
            return _TimelineItem(
              item: item,
              isLast: isLast,
              theme: theme,
            );
          }),
        ),
      ),
    );
  }

  Widget _buildEmptyActivity(BuildContext context, ThemeData theme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        child: Column(
          children: [
            Icon(
              Icons.history_rounded,
              size: 48,
              color: AppColors.textSecondary.withOpacity(0.4),
            ),
            const SizedBox(height: 12),
            Text(
              "No activity yet",
              style: theme.textTheme.titleSmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Start reading to see your activity here",
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendar(BuildContext context, int streak, Set<DateTime> readingDates) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final startWeekday = firstDay.weekday % 7;

    final dayCells = <Widget>[];
    for (int i = 0; i < startWeekday; i++) {
      dayCells.add(const SizedBox(width: 28, height: 28));
    }
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(now.year, now.month, day);
      final isToday = date == DateTime(now.year, now.month, now.day);
      final isFuture = date.isAfter(now);
      final isActive = readingDates.contains(date);

      Color cellColor;
      Color textColor;
      FontWeight fontWeight;

      if (isToday) {
        cellColor = AppColors.accent;
        textColor = Colors.white;
        fontWeight = FontWeight.bold;
      } else if (isFuture) {
        cellColor = Colors.transparent;
        textColor = AppColors.textSecondary.withOpacity(0.3);
        fontWeight = FontWeight.normal;
      } else if (isActive) {
        cellColor = AppColors.accent.withOpacity(0.3);
        textColor = AppColors.textPrimary;
        fontWeight = FontWeight.normal;
      } else {
        cellColor = AppColors.border;
        textColor = AppColors.textSecondary;
        fontWeight = FontWeight.normal;
      }

      dayCells.add(Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: cellColor,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Center(
          child: Text(
            "$day",
            style: TextStyle(
              fontSize: 10,
              fontWeight: fontWeight,
              color: textColor,
            ),
          ),
        ),
      ));
    }

    final rows = <Widget>[];
    for (int i = 0; i < dayCells.length; i += 7) {
      final end = i + 7 > dayCells.length ? dayCells.length : i + 7;
      final rowCells = dayCells.sublist(i, end);
      while (rowCells.length < 7) {
        rowCells.add(const SizedBox(width: 28, height: 28));
      }
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: rowCells,
          ),
        ),
      );
    }

    const weekdays = ["S", "M", "T", "W", "T", "F", "S"];
    final headerRow = Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: weekdays.map((d) => SizedBox(
        width: 28,
        child: Center(
          child: Text(
            d,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      )).toList(),
    );

    const monthNames = [
      "January", "February", "March", "April", "May", "June",
      "July", "August", "September", "October", "November", "December"
    ];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_month_rounded, size: 18, color: AppColors.accent),
                const SizedBox(width: 8),
                Text(
                  monthNames[now.month - 1],
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.streak.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.local_fire_department_rounded, size: 14, color: AppColors.streak),
                      const SizedBox(width: 4),
                      Text(
                        "$streak day${streak == 1 ? "" : "s"}",
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.streak,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            headerRow,
            const SizedBox(height: 8),
            ...rows,
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionHeader({
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.accent),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final _ActivityItem item;
  final bool isLast;
  final ThemeData theme;

  const _TimelineItem({
    required this.item,
    required this.isLast,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 48,
            child: Column(
              children: [
                const SizedBox(height: 14),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: item.iconColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: item.iconColor.withOpacity(0.3),
                      width: 3,
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: AppColors.border.withOpacity(0.4),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: 16, top: 8, bottom: isLast ? 8 : 4),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
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
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.textPrimary,
                            ),
                            children: [
                              TextSpan(
                                text: "${item.action} ",
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                              TextSpan(
                                text: item.bookTitle,
                                style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.accent),
                              ),
                            ],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              _formatRelativeTime(item.timestamp),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                            if (item.progress > 0) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppColors.accent.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  "${(item.progress * 100).toInt()}%",
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.accent,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
