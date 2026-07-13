import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:fl_chart/fl_chart.dart";
import "../../core/providers.dart";
import "../../core/constants/app_constants.dart";
import "../../core/theme/app_colors.dart";
import "../../data/models/book_model.dart";
import "../../data/models/reading_progress_model.dart";
import "../../data/models/reading_goal_model.dart";
import "../../data/repositories/local_repositories.dart";
import "../../data/repositories/reading_repositories.dart";

final _allStatsProvider = Provider.autoDispose<_StatsData>((ref) {
  final books = ref.watch(allBooksProvider).asData?.value ?? [];
  final totalBooks = books.length;
  final totalPages = books.fold<int>(0, (sum, b) => sum + b.currentPage);
  final finishedBooks = books.where((b) => b.progress >= 1.0).length;
  final currentlyReading = books.where((b) => b.progress > 0 && b.progress < 1.0).length;

  final tagCount = <String, int>{};
  for (final book in books) {
    for (final tag in book.tags) {
      tagCount[tag] = (tagCount[tag] ?? 0) + 1;
    }
  }
  final favoriteGenres = tagCount.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

  final authorCount = <String, int>{};
  for (final book in books) {
    authorCount[book.author] = (authorCount[book.author] ?? 0) + 1;
  }
  final topAuthors = authorCount.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

  return _StatsData(
    totalBooks: totalBooks,
    totalPages: totalPages,
    finishedBooks: finishedBooks,
    currentlyReading: currentlyReading,
    readingStreak: 0,
    favoriteGenres: favoriteGenres,
    topAuthors: topAuthors,
    monthlyReading: _generateMonthlyData(books),
  );
});

List<double> _generateMonthlyData(List<BookModel> books) {
  final data = List.filled(12, 0.0);
  for (final book in books) {
    if (book.lastOpenedAt != null) {
      final month = book.lastOpenedAt!.month - 1;
      if (month >= 0 && month < 12) {
        data[month] += 1;
      }
    }
  }
  return data;
}

class _StatsData {
  final int totalBooks;
  final int totalPages;
  final int finishedBooks;
  final int currentlyReading;
  final int readingStreak;
  final List<MapEntry<String, int>> favoriteGenres;
  final List<MapEntry<String, int>> topAuthors;
  final List<double> monthlyReading;

  const _StatsData({
    required this.totalBooks,
    required this.totalPages,
    required this.finishedBooks,
    required this.currentlyReading,
    required this.readingStreak,
    required this.favoriteGenres,
    required this.topAuthors,
    required this.monthlyReading,
  });
}

class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final stats = ref.watch(_allStatsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text("Statistics")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(child: _StatCard(title: "Books Read", value: stats.finishedBooks.toString(), icon: Icons.menu_book_rounded, color: AppColors.finished)),
              const SizedBox(width: 12),
              Expanded(child: _StatCard(title: "Pages Read", value: _formatNumber(stats.totalPages), icon: Icons.article_rounded, color: colorScheme.primary)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _StatCard(title: "Currently Reading", value: stats.currentlyReading.toString(), icon: Icons.timer_rounded, color: AppColors.reading)),
              const SizedBox(width: 12),
              Expanded(child: _StatCard(title: "Streak", value: "${stats.readingStreak} days", icon: Icons.local_fire_department_rounded, color: AppColors.streak)),
            ],
          ),
          const SizedBox(height: 24),
          Text("Monthly Reading", style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 24, 8, 8),
              child: SizedBox(
                height: 200,
                child: _MonthlyChart(data: stats.monthlyReading, color: colorScheme.primary),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Text("Reading Goal", style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.edit_rounded, size: 18),
                label: const Text("Set Goal"),
                onPressed: () => _showGoalDialog(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _ReadingGoalProgress(
            current: stats.totalBooks,
            goal: 52,
            color: colorScheme.primary,
          ),
          const SizedBox(height: 24),
          Text("Favorite Genres", style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          stats.favoriteGenres.isNotEmpty
              ? Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: stats.favoriteGenres.take(8).map((entry) {
                    return Chip(
                      label: Text("${entry.key} (${entry.value})"),
                      avatar: Icon(Icons.tag_rounded, size: 16),
                    );
                  }).toList(),
                )
              : _EmptyPlaceholder(message: "No genres yet"),
          const SizedBox(height: 24),
          Text("Most Read Authors", style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          stats.topAuthors.isNotEmpty
              ? Column(
                  children: stats.topAuthors.take(5).map((entry) {
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: colorScheme.primaryContainer,
                        child: Text(entry.key[0].toUpperCase(), style: TextStyle(color: colorScheme.onPrimaryContainer)),
                      ),
                      title: Text(entry.key),
                      trailing: Text("${entry.value} book${entry.value == 1 ? "" : "s"}", style: theme.textTheme.bodyMedium),
                    );
                  }).toList(),
                )
              : _EmptyPlaceholder(message: "No authors yet"),
        ],
      ),
    );
  }

  String _formatNumber(int n) {
    if (n >= 1000) return "${(n / 1000).toStringAsFixed(1)}k";
    return n.toString();
  }

  void _showGoalDialog(BuildContext context) {
    final controller = TextEditingController(text: "52");
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Set Reading Goal"),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: "Books per year", suffixText: "books"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text("Save")),
        ],
      ),
    );
  }
}

class _MonthlyChart extends StatelessWidget {
  final List<double> data;
  final Color color;

  const _MonthlyChart({required this.data, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    final maxY = data.reduce((a, b) => a > b ? a : b);

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: (maxY + 2).ceilToDouble(),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                "${months[group.x.toInt()]}: ${rod.toY.toInt()}",
                TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= months.length) return const SizedBox.shrink();
                final isSelected = data[index] > 0;
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    months[index],
                    style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                if (value == 0) return const SizedBox.shrink();
                return Text("${value.toInt()}", style: const TextStyle(fontSize: 11));
              },
            ),
          ),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 1,
          getDrawingHorizontalLine: (value) {
            return FlLine(color: theme.colorScheme.outlineVariant.withOpacity(0.3), strokeWidth: 0.5);
          },
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(data.length, (i) {
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: data[i],
                color: data[i] > 0 ? color : theme.colorScheme.surfaceContainerHighest,
                width: 16,
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4)),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _ReadingGoalProgress extends StatelessWidget {
  final int current;
  final int goal;
  final Color color;

  const _ReadingGoalProgress({required this.current, required this.goal, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = (current / goal).clamp(0.0, 1.0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text("$current", style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: color)),
                Text(" / $goal books", style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                const Spacer(),
                Text("${(progress * 100).toInt()}%", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                color: color,
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "${goal - current} more books to reach your goal",
              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
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
  final Color color;

  const _StatCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 12),
            Text(value, style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
            Text(title, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _EmptyPlaceholder extends StatelessWidget {
  final String message;
  const _EmptyPlaceholder({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ),
    );
  }
}
