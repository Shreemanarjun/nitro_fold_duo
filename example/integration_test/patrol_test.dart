import 'package:flutter/material.dart';
import 'package:nitro_fold_duo_example/app.dart';
import 'package:nitro_fold_duo_example/data/articles.dart';
import 'package:patrol/patrol.dart';

/// XCUITest cannot deliver a touch to a UIKit control hosted inside a Flutter
/// platform view: taps by accessibility element and by raw coordinate both
/// report success and produce nothing, while real HID input works. The bar's
/// buttons are exactly such controls, so the tests that press them are kept
/// but skipped — they are ready for the day that is fixed.
///
/// Verified by hand on an iPhone Duo (iOS 27.1) instead: each capsule button,
/// the overflow `UIMenu`, the tab capsule and the back control all reach Dart.
void main() {
  patrolTest('the bridge reports Duo geometry', ($) async {
    await $.pumpWidgetAndSettle(const DuoDemoApp());

    // The status line sits under every tab, so this does not depend on which
    // one is up. A posture at all means the reserved regions came back from
    // the bridge; without it the state would be `unknown`.
    await $(RegExp('hinge: (closed|partiallyOpen|fullyOpen)'))
        .waitUntilVisible();
  });

  patrolTest('a Flutter control in the body reaches Dart', ($) async {
    await $.pumpWidgetAndSettle(const DuoDemoApp());

    await $(const Key('article_1')).tap();

    // Scoped to the detail pane: the list shows the same title on its own side
    // of the fold, and matching that would prove nothing.
    await $(const Key('articleDetail')).$(articles[1].title).waitUntilVisible();
  });

  patrolTest('a toolbar capsule button reaches Dart', skip: true, ($) async {
    await $.pumpWidgetAndSettle(const DuoDemoApp());

    await $.platform.tap(Selector(text: 'Fold-aware dialog'));

    await $(const Key('foldDialog')).waitUntilVisible();
  });

  patrolTest('items that do not fit open in the overflow menu', skip: true, (
    $,
  ) async {
    await $.pumpWidgetAndSettle(const DuoDemoApp());

    // The tail of the toolbar is in a UIMenu behind the overflow capsule.
    await $.platform.tap(Selector(text: 'More'));

    await $.platform.mobile.waitUntilVisible(Selector(text: 'Enhance'));
  });

  patrolTest('the tab capsule switches the body', skip: true, ($) async {
    await $.pumpWidgetAndSettle(const DuoDemoApp());

    await $.platform.tap(Selector(text: 'State'));

    await $('Duo state').waitUntilVisible();
  });

  patrolTest('the back capsule pops the pushed page', skip: true, ($) async {
    await $.pumpWidgetAndSettle(const DuoDemoApp());

    await $.platform.tap(Selector(text: 'Open detail'));
    await $(const Key('detailBody')).waitUntilVisible();

    await $.platform.tap(Selector(text: 'Back'));

    await $(const Key('articleList')).waitUntilVisible();
  });
}
