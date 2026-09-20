// Drives the simulator's hinge and checks what the app reports back.
//
// The bar's buttons are native and out of reach of XCUITest, but the fold
// itself is testable end to end: `hinge` sets the angle on the host, the app
// reports what iOS tells it, and Marionette reads that back out of the live
// widget tree. This covers the rows of Apple's validation matrix that need a
// real pose change — closed, both partial angles, flat, and a round trip.
//
//   dart run tool/fold_check.dart --instance duo
//
// Prerequisites: a booted foldable simulator, the example running on it in
// debug mode, and that app registered with `marionette register <name> <uri>`.
import 'dart:io';

const _hingeSkill = '.claude/skills/hinge/scripts/hinge';

/// The two displays, by the size each reports. Either orientation counts: the
/// device keeps whatever rotation it was in.
const _coverDisplay = {466, 678};
const _innerDisplay = {951, 669};

/// What the app must report at a given hinge angle.
class Pose {
  const Pose(
    this.angle, {
    required this.status,
    required this.activeDivision,
    required this.display,
  });

  final int angle;
  final String status;

  /// A flat fold is not an active division, and a closed device has none.
  final bool activeDivision;

  /// Which display the app should be on: [_coverDisplay] or [_innerDisplay].
  final Set<int> display;
}

const _poses = [
  Pose(0, status: 'closed', activeDivision: false, display: _coverDisplay),
  Pose(
    90,
    status: 'partiallyOpen',
    activeDivision: true,
    display: _innerDisplay,
  ),
  Pose(
    135,
    status: 'partiallyOpen',
    activeDivision: true,
    display: _innerDisplay,
  ),
  Pose(180, status: 'fullyOpen', activeDivision: false, display: _innerDisplay),
  // Back to closed: the app must recover the cover-display layout, not keep
  // the inner one it was last laid out for.
  Pose(0, status: 'closed', activeDivision: false, display: _coverDisplay),
];

String _arg(List<String> args, String name, String fallback) {
  final index = args.indexOf('--$name');
  return index >= 0 && index + 1 < args.length ? args[index + 1] : fallback;
}

Future<void> main(List<String> args) async {
  final instance = _arg(args, 'instance', 'duo');
  final device = _arg(args, 'device', 'booted');
  final hinge = _arg(args, 'hinge', '../$_hingeSkill');

  var failures = 0;
  for (final pose in _poses) {
    final set = await Process.run(hinge, ['-d', device, '${pose.angle}']);
    if (set.exitCode != 0) {
      stderr.writeln('hinge ${pose.angle} failed: ${set.stderr}');
      exit(1);
    }
    // The display transition and the app's relayout both need a moment.
    await Future<void>.delayed(const Duration(seconds: 3));

    final read = await Process.run('marionette', [
      '-i',
      instance,
      'get-interactive-elements',
    ]);
    final tree = read.stdout as String;

    // Read the status line, which every tab shows.
    final status = RegExp(r'hinge: (\w+)').firstMatch(tree)?.group(1);
    final screen = RegExp(r'screen: (\d+)×(\d+)').firstMatch(tree);
    final width = int.tryParse(screen?.group(1) ?? '');
    final height = int.tryParse(screen?.group(2) ?? '');
    // The status line names the active division, or says there is none.
    final hasActiveDivision = !tree.contains('no division') &&
        RegExp(r'division \d').hasMatch(tree);

    // The strip the system reserves in this pose, read the way the plugin
    // reads it: a side-only inset with no top inset.
    final padding = RegExp(
      r'viewPad ([\d.]+)/([\d.]+)/([\d.]+)/',
    ).firstMatch(tree);
    final left = double.tryParse(padding?.group(1) ?? '') ?? 0;
    final top = double.tryParse(padding?.group(2) ?? '') ?? 0;
    final right = double.tryParse(padding?.group(3) ?? '') ?? 0;
    final strip = top != 0 ? 0.0 : (left > 0 ? left : right);

    final body = double.tryParse(
      RegExp(
            r'Key: "statusLine".*?"width":([\d.]+)',
          ).firstMatch(tree)?.group(1) ??
          '',
    );

    final problems = [
      if (status != pose.status) 'status $status, wanted ${pose.status}',
      if (width == null || height == null)
        'no screen size reported'
      // Sets compare by identity in Dart, so check the contents.
      else if (!pose.display.containsAll({width, height}))
        'display ${width}x$height, wanted ${pose.display.join('x')}',
      if (hasActiveDivision != pose.activeDivision)
        'active division $hasActiveDivision, wanted ${pose.activeDivision}',
      // Whatever the pose, the body must clear the strip exactly.
      if (width != null && body != null && body != width - strip)
        'body $body, wanted ${width - strip} (screen $width less strip $strip)',
    ];

    if (problems.isEmpty) {
      stdout.writeln(
        'ok    ${pose.angle}° → $status, ${width}x$height, '
        'body ${body}pt clear of a ${strip}pt strip, '
        'active division ${pose.activeDivision}',
      );
    } else {
      failures++;
      stdout.writeln('FAIL  ${pose.angle}° → ${problems.join('; ')}');
    }
  }

  stdout.writeln(
    failures == 0
        ? '\nAll ${_poses.length} poses behaved.'
        : '\n$failures of ${_poses.length} poses were wrong.',
  );
  exit(failures == 0 ? 0 : 1);
}
