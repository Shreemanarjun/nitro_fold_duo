import 'package:flutter/material.dart';

import '../data/articles.dart';

/// The list half of the two-pane layout.
class ArticleList extends StatelessWidget {
  const ArticleList({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      key: const Key('articleList'),
      itemCount: articles.length,
      itemBuilder: (context, index) {
        final article = articles[index];
        return ListTile(
          key: Key('article_$index'),
          selected: index == selected,
          selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
          title: Text(article.title),
          subtitle: Text(article.summary),
          onTap: () => onSelected(index),
        );
      },
    );
  }
}

/// The detail half.
class ArticleDetail extends StatelessWidget {
  const ArticleDetail({super.key, required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final article = articles[index];
    return SingleChildScrollView(
      key: const Key('articleDetail'),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            article.title,
            key: const Key('detailTitle'),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Text(article.body, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}
