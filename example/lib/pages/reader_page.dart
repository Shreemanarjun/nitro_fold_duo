import 'package:flutter/material.dart';
import 'package:nitro_fold_duo/nitro_fold_duo.dart';

import '../data/articles.dart';
import '../widgets/article_list.dart';

/// The two-pane reader.
///
/// [DuoSplit] puts the list and the article on opposite sides of the fold and
/// leaves the crease itself empty. Unfolded, the same widget stacks them — it
/// is the layout in both poses, not something swapped in when the phone bends.
class ReaderPage extends StatelessWidget {
  const ReaderPage({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return DuoSplit(
      primary: Material(
        color: Theme.of(context).colorScheme.surface,
        child: ArticleList(selected: selected, onSelected: onSelected),
      ),
      secondary: Material(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        child: ArticleDetail(index: selected),
      ),
    );
  }
}

/// Shows what `DuoDisplayFeatures` buys: a dialog routed around the crease.
///
/// Flutter's own `DisplayFeatureSubScreen` does this whenever the platform
/// reports a fold — which on iOS it never does, until the regions are
/// published into `MediaQuery`.
Future<void> showFoldAwareDialog(BuildContext context) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    key: const Key('foldDialog'),
    title: const Text('Clear of the crease'),
    content: Text(
      'Flutter places this with DisplayFeatureSubScreen, which keeps it out '
      'of the fold. It only knows where the fold is because the reserved '
      'regions were published into MediaQuery — '
      '${articles.length} articles, one hinge.',
    ),
    actions: [
      TextButton(
        key: const Key('foldDialogClose'),
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Close'),
      ),
    ],
  ),
);
