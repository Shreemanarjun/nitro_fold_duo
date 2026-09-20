/// A tiny fixed corpus, so the demo has real content to split across the fold
/// rather than coloured boxes.
class Article {
  const Article({required this.title, required this.summary, required this.body});

  final String title;
  final String summary;
  final String body;
}

const articles = <Article>[
  Article(
    title: 'Reserved regions',
    summary: 'Where not to put your UI',
    body:
        'The system reports the parts of the display a layout has to work '
        'around: the fold when it is bent, and the camera. Each region comes '
        'with its frame in your own coordinate space, and that frame already '
        'includes the protective margin — inset by it again and you lose twice '
        'the room you needed to.',
  ),
  Article(
    title: 'The hinge',
    summary: 'Status, not angle',
    body:
        'The hinge reports a status and an angle. Branch on the status: no '
        'numeric range or zero convention is documented, the update rate is '
        'system policy, and asking for 135 degrees gets you 132.5 back. Use '
        'the angle for an effect, never for a layout threshold.',
  ),
  Article(
    title: 'The vertical bar',
    summary: 'Bars move to the side',
    body:
        'On the cover display, and on the inner display in landscape, the '
        'system reserves a strip along one edge and moves the status cluster, '
        'back button, toolbar and tab bar into it. The preferred edge is not a '
        'visibility flag, and the strip follows the hardware through every '
        'rotation — including the one that puts it on the left.',
  ),
  Article(
    title: 'A flat fold',
    summary: 'Not every crease divides',
    body:
        'Opened flat, the fold is still reported — but inactive. A crease you '
        'cannot see should not move a dialog or split a pane, which is why '
        'the active check matters more than the presence of a region.',
  ),
  Article(
    title: 'Display features',
    summary: 'What Flutter already knows',
    body:
        'Flutter has modelled a fold since DisplayFeature landed, but only '
        'Android fills it in. Publishing the reserved regions through '
        'MediaQuery.displayFeatures makes every dialog and popup that already '
        'avoids a hinge on a Fold behave the same here.',
  ),
];
