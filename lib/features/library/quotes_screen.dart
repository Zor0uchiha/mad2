import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/constants/app_constants.dart';
import '../../core/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/quote_model.dart';

class QuotesScreen extends ConsumerWidget {
  const QuotesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final quotes = ref.watch(allQuotesProvider).asData?.value ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text("My Saved Lines & Quotes")),
      body: quotes.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.format_quote,
                    size: 64,
                    color: AppColors.accent.withOpacity(0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "No quotes saved yet",
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      "While reading, use the Highlight & Quote tool to save your favourite lines.",
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: () async => ref.refresh(allQuotesProvider.future),
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: quotes.length,
                itemBuilder: (context, i) => _QuoteCard(quote: quotes[i]),
              ),
            ),
    );
  }
}

class _QuoteCard extends ConsumerWidget {
  final QuoteModel quote;

  const _QuoteCard({required this.quote});

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: quote.text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Copied to clipboard")),
      );
    }
  }

  Future<void> _share(BuildContext context) async {
    final text = quote.text.isNotEmpty
        ? '"${quote.text}"'
        : "Highlight on page ${quote.pageIndex} of ${quote.bookTitle}";
    await Share.share(
      "$text\n\n— ${quote.bookTitle} · ${quote.bookAuthor}",
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => context.push(
          "${AppConstants.routeReader}/${quote.bookId}",
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.border_color,
                  color: Colors.amber,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      quote.text.isEmpty
                          ? "(line highlighted)"
                          : quote.text,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "${quote.bookTitle} · ${quote.bookAuthor} · Page ${quote.pageIndex}",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    onPressed: () => _copy(context),
                  ),
                  IconButton(
                    icon: const Icon(Icons.share_rounded, size: 18),
                    onPressed: () => _share(context),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: Colors.red,
                    ),
                    onPressed: () async {
                      await ref
                          .read(quoteRepositoryProvider)
                          .deleteQuote(quote.id);
                      ref.invalidate(allQuotesProvider);
                      ref.invalidate(quotesForBookProvider);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
