import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "../../core/providers.dart";
import "../../core/theme/app_colors.dart";
import "../../data/models/book_model.dart";
import "../../data/models/reading_goal_model.dart";
import "../../data/services/storage_service.dart";

final _statisticsGoalProvider = FutureProvider<ReadingGoalModel?>((ref) async {
  final box = await StorageService.openReadingGoalsBox();
  final goals = box.values.toList();
  if (goals.isEmpty) return null;
  goals.sort((a, b) => b.endDate.compareTo(a.endDate));
  return goals.first;
});

final _statisticsStreakProvider = FutureProvider<int>((ref) async {
  final box = await StorageService.openUserProfileBox();
  final user = box.values.isNotEmpty ? box.values.first : null;
  return user?.readingStreak ?? 0;
});

class _StatsData {
  final int totalBooks;
  final int totalPages;
  final int currentlyReading;
  final int streak;
  final ReadingGoalModel? goal;

  const _StatsData({
    required this.totalBooks,
    required this.totalPages,
    required this.currentlyReading,
    required this.streak,
    required this.goal,
  });
}

final _statsDataProvider = FutureProvider<_StatsData>((ref) async {
  final books = await ref.watch(allBooksProvider.future);
  final totalPages = await ref.watch(totalPagesReadProvider.future);
  final streak = await ref.watch(_statisticsStreakProvider.future);
  final goal = await ref.watch(_statisticsGoalProvider.future);

  return _StatsData(
    totalBooks: books.length,
    totalPages: totalPages,
    currentlyReading: books.where((b) => b.progress > 0 && b.progress < 1).length,
    streak: streak,
    goal: goal,
  );
});

class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  String _formatNumber(int n) {
    if (n >= 1000) return "${(n / 1000).toStringAsFixed(1)}k";
    return n.toString();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final statsAsync = ref.watch(_statsDataProvider);

    return Scaffold(
      appBar: AppBar(title: const Text("Statistics")),
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, size: 48, color: AppColors.textSecondary.withOpacity(0.4)),
              const SizedBox(height: 12),
              Text("Something went wrong", style: theme.textTheme.titleSmall?.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.invalidate(_statsDataProvider),
                child: const Text("Retry"),
              ),
            ],
          ),
        ),
        data: (stats) {
          final hasNoBooks = stats.totalBooks == 0;

          if (hasNoBooks) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bar_chart_rounded, size: 64, color: AppColors.accent.withOpacity(0.4)),
                  const SizedBox(height: 16),
                  Text("No statistics yet", style: theme.textTheme.titleMedium?.copyWith(color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  Text("Add books to see your reading stats", style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      title: "Total Books",
                      value: _formatNumber(stats.totalBooks),
                      icon: Icons.menu_book_rounded,
                      color: AppColors.finished,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      title: "Pages Read",
                      value: _formatNumber(stats.totalPages),
                      icon: Icons.article_rounded,
                      color: AppColors.reading,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      title: "Reading",
                      value: _formatNumber(stats.currentlyReading),
                      icon: Icons.timer_rounded,
                      color: AppColors.wantToRead,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _SectionHeader(icon: Icons.flag_rounded, title: "Reading Goal"),
              const SizedBox(height: 12),
              _ReadingGoalCard(goal: stats.goal),
              const SizedBox(height: 24),
              _SectionHeader(icon: Icons.calendar_month_rounded, title: "Monthly Activity"),
              const SizedBox(height: 12),
              _buildHeatmap(context, stats.streak),
              const SizedBox(height: 24),
              _SectionHeader(icon: Icons.local_fire_department_rounded, title: "Reading Streak"),
              const SizedBox(height: 12),
              _buildStreakCard(context, stats.streak),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeatmap(BuildContext context, int streak) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final days = List.generate(28, (i) => now.subtract(Duration(days: 27 - i)));

    return Card(
      color: AppColors.cardDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                  "Reading Activity",
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
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
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.streak),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: days.map((day) {
                final isActive = day.day % 3 == 0 && day.isBefore(now);
                final isToday = day.day == now.day && day.month == now.month && day.year == now.year;
                return Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isToday
                        ? AppColors.accent
                        : isActive
                            ? AppColors.accent.withOpacity(0.3)
                            : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: Text(
                      "${day.day}",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                        color: isToday ? Colors.white : AppColors.textSecondary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreakCard(BuildContext context, int streak) {
    return Card(
      color: AppColors.cardDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.streak.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.local_fire_department_rounded, color: AppColors.streak, size: 32),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "$streak day${streak == 1 ? "" : "s"}",
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Current reading streak",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                ),
              ],
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

  const _SectionHeader({required this.icon, required this.title});

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

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: AppColors.cardDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
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

class _ReadingGoalCard extends StatelessWidget {
  final ReadingGoalModel? goal;

  const _ReadingGoalCard({required this.goal});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (goal == null || goal!.targetBooks == 0) {
      return Card(
        color: AppColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.flag_rounded, color: AppColors.accent, size: 22),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("No goal set", style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text("Add a reading goal to track progress", style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                ],
              ),
            ],
          ),
        ),
      );
    }

    final progress = goal!.overallProgress.clamp(0.0, 1.0);
    return Card(
      color: AppColors.cardDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                  child: Icon(Icons.flag_rounded, color: AppColors.streak, size: 22),
                ),
                const SizedBox(width: 12),
                Text(
                  "Reading Goal",
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
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
                  "${goal!.currentBooks} / ${goal!.targetBooks} books",
                  style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                ),
                Text(
                  "${(progress * 100).toInt()}%",
                  style: theme.textTheme.labelMedium?.copyWith(color: AppColors.accent, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
