import "dart:ui" as ui;
import "dart:typed_data";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter/rendering.dart";
import "../../core/providers.dart";
import "../../core/constants/app_constants.dart";
import "../../core/theme/app_colors.dart";
import "../../data/services/share_service.dart";
import "../../data/models/book_model.dart";
import "../../data/repositories/local_repositories.dart";

enum ShareCardType { currentlyReading, finishedBooks, stats, streak }

class ShareScreen extends ConsumerStatefulWidget {
  const ShareScreen({super.key});

  @override
  ConsumerState<ShareScreen> createState() => _ShareScreenState();
}

class _ShareScreenState extends ConsumerState<ShareScreen> {
  final GlobalKey _cardKey = GlobalKey();
  ShareCardType _cardType = ShareCardType.currentlyReading;
  bool _darkCard = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final books = ref.watch(allBooksProvider).asData?.value ?? [];

    final currentlyReading = books.where((b) => b.progress > 0 && b.progress < 1.0).toList();
    final finishedBooks = books.where((b) => b.progress >= 1.0).toList();
    final totalBooks = books.length;
    final totalPages = books.fold<int>(0, (sum, b) => sum + b.currentPage);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Share Card"),
        actions: [
          IconButton(
            icon: Icon(_darkCard ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
            onPressed: () => setState(() => _darkCard = !_darkCard),
            tooltip: "Toggle theme",
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text("Share your reading journey", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _CardTypeChip(
                label: "Currently Reading",
                icon: Icons.menu_book_rounded,
                selected: _cardType == ShareCardType.currentlyReading,
                onTap: () => setState(() => _cardType = ShareCardType.currentlyReading),
              ),
              _CardTypeChip(
                label: "Finished Books",
                icon: Icons.check_circle_rounded,
                selected: _cardType == ShareCardType.finishedBooks,
                onTap: () => setState(() => _cardType = ShareCardType.finishedBooks),
              ),
              _CardTypeChip(
                label: "Stats",
                icon: Icons.bar_chart_rounded,
                selected: _cardType == ShareCardType.stats,
                onTap: () => setState(() => _cardType = ShareCardType.stats),
              ),
              _CardTypeChip(
                label: "Streak",
                icon: Icons.local_fire_department_rounded,
                selected: _cardType == ShareCardType.streak,
                onTap: () => setState(() => _cardType = ShareCardType.streak),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Center(
            child: RepaintBoundary(
              key: _cardKey,
              child: _buildCard(
                cardType: _cardType,
                dark: _darkCard,
                currentlyReading: currentlyReading,
                finishedBooks: finishedBooks,
                totalBooks: totalBooks,
                totalPages: totalPages,
                colorScheme: colorScheme,
                textTheme: theme.textTheme,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: FilledButton.icon(
              onPressed: _shareCard,
              icon: const Icon(Icons.share_rounded),
              label: const Text("Share Card"),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
          ),
          if (_cardType == ShareCardType.currentlyReading && currentlyReading.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text("Currently Reading", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...currentlyReading.take(3).map((book) => ListTile(
                  leading: Container(
                    width: 32,
                    height: 44,
                    decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(4)),
                    child: const Icon(Icons.menu_book_rounded, size: 20),
                  ),
                  title: Text(book.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(book.author, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: Text("${(book.progress * 100).toInt()}%", style: theme.textTheme.labelSmall),
                )),
          ],
        ],
      ),
    );
  }

  Widget _buildCard({
    required ShareCardType cardType,
    required bool dark,
    required List<BookModel> currentlyReading,
    required List<BookModel> finishedBooks,
    required int totalBooks,
    required int totalPages,
    required ColorScheme colorScheme,
    required TextTheme textTheme,
  }) {
    final bgColor = dark ? const Color(0xFF1C1B1F) : const Color(0xFFFFFBFE);
    final fgColor = dark ? const Color(0xFFE6E1E5) : const Color(0xFF1C1B1F);
    final accentColor = dark ? const Color(0xFF90CAF9) : const Color(0xFF1A73E8);

    return Container(
      width: 320,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: accentColor.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                child: Image.asset("assets/images/logo2.png", width: 24, height: 24, color: accentColor),
              ),
              const Spacer(),
              Text("Libora", style: TextStyle(color: fgColor.withOpacity(0.5), fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 20),
          switch (cardType) {
            ShareCardType.currentlyReading => _buildCurrentlyReadingCard(fgColor, accentColor, currentlyReading),
            ShareCardType.finishedBooks => _buildFinishedCard(fgColor, accentColor, finishedBooks),
            ShareCardType.stats => _buildStatsCard(fgColor, accentColor, totalBooks, totalPages),
            ShareCardType.streak => _buildStreakCard(fgColor, accentColor),
          },
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset("assets/images/logo2.png", width: 16, height: 16, color: accentColor),
                const SizedBox(width: 6),
                Text("Libora", style: TextStyle(color: accentColor, fontSize: 14, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentlyReadingCard(Color fgColor, Color accentColor, List<BookModel> currentlyReading) {
    if (currentlyReading.isEmpty) {
      return Text("No books currently being read", style: TextStyle(color: fgColor.withOpacity(0.6), fontSize: 16));
    }
    final book = currentlyReading.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Currently Reading", style: TextStyle(color: accentColor, fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 1)),
        const SizedBox(height: 12),
        Text(book.title, style: TextStyle(color: fgColor, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(book.author, style: TextStyle(color: fgColor.withOpacity(0.7), fontSize: 16)),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: book.progress,
            backgroundColor: fgColor.withOpacity(0.1),
            color: accentColor,
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 6),
        Text("${(book.progress * 100).toInt()}% complete", style: TextStyle(color: fgColor.withOpacity(0.5), fontSize: 12)),
      ],
    );
  }

  Widget _buildFinishedCard(Color fgColor, Color accentColor, List<BookModel> finishedBooks) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Books Finished", style: TextStyle(color: accentColor, fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 1)),
        const SizedBox(height: 12),
        Text("${finishedBooks.length}", style: TextStyle(color: fgColor, fontSize: 48, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text("book${finishedBooks.length == 1 ? "" : "s"} completed", style: TextStyle(color: fgColor.withOpacity(0.7), fontSize: 16)),
        if (finishedBooks.isNotEmpty) ...[
          const SizedBox(height: 12),
          ...finishedBooks.take(3).map((book) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_rounded, size: 16, color: AppColors.finished),
                    const SizedBox(width: 8),
                    Expanded(child: Text(book.title, style: TextStyle(color: fgColor.withOpacity(0.8), fontSize: 14))),
                  ],
                ),
              )),
        ],
      ],
    );
  }

  Widget _buildStatsCard(Color fgColor, Color accentColor, int totalBooks, int totalPages) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Reading Stats", style: TextStyle(color: accentColor, fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 1)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("$totalBooks", style: TextStyle(color: fgColor, fontSize: 32, fontWeight: FontWeight.bold)),
                  Text("Books", style: TextStyle(color: fgColor.withOpacity(0.6), fontSize: 14)),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("$totalPages", style: TextStyle(color: fgColor, fontSize: 32, fontWeight: FontWeight.bold)),
                  Text("Pages", style: TextStyle(color: fgColor.withOpacity(0.6), fontSize: 14)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStreakCard(Color fgColor, Color accentColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Reading Streak", style: TextStyle(color: accentColor, fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 1)),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(Icons.local_fire_department_rounded, color: AppColors.streak, size: 40),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("0 days", style: TextStyle(color: fgColor, fontSize: 36, fontWeight: FontWeight.bold)),
                Text("Keep reading every day!", style: TextStyle(color: fgColor.withOpacity(0.7), fontSize: 14)),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _shareCard() async {
    try {
      final boundary = _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      await ShareService.shareImage(_cardKey, text: "My reading on Libora");
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to share: $e")),
        );
      }
    }
  }
}

class _CardTypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _CardTypeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}
