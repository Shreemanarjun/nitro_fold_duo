import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nitro_fold_duo_example/app.dart';
import 'package:patrol/patrol.dart';

/// The vertical bar's buttons are real UIKit controls inside a platform view,
/// so Flutter's own tester cannot reach them — every tap below goes through
/// XCUITest, the way a person would.
///
/// Buttons are addressed by the accessibility label iOS derives from their SF
/// Symbol ("Share" for `square.and.arrow.up`), or by the title we give an
/// overflow entry.
void main() {
  patrolTest('the bridge reports Duo geometry', ($) async {
    await $.pumpWidgetAndSettle(const DuoDemoApp());

    expect($('supported: true'), findsOneWidget);
    // Every pose the strip exists in reports a side; portrait reports none.
    expect($(const Key('barSide')), findsOneWidget);
  });

  patrolTest('a toolbar capsule button reaches Dart', ($) async {
    await $.pumpWidgetAndSettle(const DuoDemoApp());
    expect($('action: —'), findsOneWidget);

    await $.platformAutomator.tap(Selector(text: 'Share'));
    await $.pumpAndSettle();

    expect($('action: share'), findsOneWidget);
  });

  patrolTest('items that do not fit open in the overflow menu', ($) async {
    await $.pumpWidgetAndSettle(const DuoDemoApp());

    // The tail of the toolbar is in a UIMenu behind the overflow capsule.
    await $.platformAutomator.tap(Selector(text: 'More'));
    await $.platformAutomator.tap(Selector(text: 'Enhance'));
    await $.pumpAndSettle();

    expect($('action: enhance'), findsOneWidget);
  });

  patrolTest('the tab capsule switches the body', ($) async {
    await $.pumpWidgetAndSettle(const DuoDemoApp());
    expect($('Duo state'), findsOneWidget);

    await $.platformAutomator.tap(Selector(text: 'Split'));
    await $.pumpAndSettle();

    expect($('PRIMARY'), findsOneWidget);
    expect($('SECONDARY'), findsOneWidget);
  });

  patrolTest('the back capsule pops the pushed page', ($) async {
    await $.pumpWidgetAndSettle(const DuoDemoApp());

    await $.platformAutomator.tap(Selector(text: 'Open detail'));
    await $.pumpAndSettle();
    expect($(const Key('detailBody')), findsOneWidget);

    await $.platformAutomator.tap(Selector(text: 'Back'));
    await $.pumpAndSettle();

    expect($(const Key('detailBody')), findsNothing);
    expect($('Duo state'), findsOneWidget);
  });
}
