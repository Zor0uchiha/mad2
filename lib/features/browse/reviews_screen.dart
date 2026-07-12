import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "../../core/providers.dart";
import "../../core/constants/app_constants.dart";
import "../../data/models/review_model.dart";

class ReviewsScreen extends ConsumerWidget {
  final String bookId;
  const ReviewsScreen({required this.bookId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewsBox = ref.watch(reviewsProvider);
    final reviews = (reviewsBox as dynamic).values.where((r) => (r as ReviewModel).bookId == bookId).toList();

    return Scaffold(
      appBar: AppBar(title: const Text("Reviews")),
      body: reviews.isEmpty
          ? const Center(child: Text("No reviews yet."))
          : ListView.builder(
              itemCount: reviews.length,
              itemBuilder: (context, index) {
                final review = reviews[index];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(review.userName, style: Theme.of(context).textTheme.titleSmall),
                            const Spacer(),
                            Text("${review.rating} / 5", style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(review.text, style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(onPressed: () {}, icon: const Icon(Icons.rate_review_rounded), label: const Text("Write Review")),
    );
  }
}
