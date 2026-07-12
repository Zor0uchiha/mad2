import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:fl_chart/fl_chart.dart";
import "../../core/providers.dart";
import "../../core/constants/app_constants.dart";
import "../../data/models/book_model.dart";
import "../../data/models/reading_progress_model.dart";
import "../../data/models/review_model.dart";
import "../../data/repositories/local_repositories.dart";
import "../../data/repositories/reading_repositories.dart";

class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final books = ref.watch(booksProvider).getAllBooks();
    final totalBooks = books.length;
    final totalPages = books.fold<int>(0, (sum, b) => sum + b.currentPage);
    final totalTime = books.fold<int>(0, (sum, b) => sum + (b.currentPage * 2));

    return Scaffold(
      appBar: AppBar(title: const Text("Statistics")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(child: _StatCard(title: "Books Read", value: totalBooks.toString(), icon: Icons.menu_book_rounded)),
              const SizedBox(width: 12),
              Expanded(child: _StatCard(title: "Pages Read", value: totalPages.toString(), icon: Icons.article_rounded)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _StatCard(title: "Reading Time", value: "${totalTime}m", icon: Icons.timer_rounded)),
              const SizedBox(width: 12),
              Expanded(child: _StatCard(title: "Streak", value: "0 days", icon: Icons.local_fire_department_rounded)),
            ],
          ),
          const SizedBox(height: 24),
          Text("Monthly Reading", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _MonthlyChart(primary: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 24),
          Text("Favorite Genres", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          const Wrap(
            spacing: 8,
            children: [
              Chip(label: Text("Fiction")),
              Chip(label: Text("Non-Fiction")),
              Chip(label: Text("Science Fiction")),
            ],
          ),
          const SizedBox(height: 24),
          Text("Most Read Authors", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ListTile(title: Text(books.isNotEmpty ? books.first.author : "Unknown"), subtitle: Text("${books.where((b) => b.author == books.firstOrNull?.author).length} books")),
        ],
      ),
    );
  }
}

class _MonthlyChart extends StatelessWidget {
  final Color primary;
  const _MonthlyChart({required this.primary});

  @override
  Widget build(BuildContext context) {
    final months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    final values = List.generate(12, (i) => (i + 1) * 2.0);
    final max = values.reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          barGroups: List.generate(months.length, (i) {
            return BarChartGroupData(x: i, barRods: [BarChartRodData(toY: values[i], color: primary)]);
          }),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (value, meta) {
              final index = value.toInt();
              return Padding(padding: const EdgeInsets.only(top: 8), child: Text(index < months.length ? months[index] : "", style: const TextStyle(fontSize: 12)));
            })),
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  const _StatCard({required this.title, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(value, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
            Text(title, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
