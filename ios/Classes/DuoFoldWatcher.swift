import Combine
import Flutter
import Foundation
import UIKit

// Generated record types are plain value types that cross from the UIKit main
// thread to Dart's UI isolate.
extension DuoReservedRegion: @unchecked Sendable {}
extension DuoState: @unchecked Sendable {}

extension DuoReservedRegion: Equatable {
    public static func == (a: Self, b: Self) -> Bool {
        a.kind == b.kind && a.left == b.left && a.top == b.top
            && a.width == b.width && a.height == b.height
            && a.marginLeft == b.marginLeft && a.marginTop == b.marginTop
            && a.marginRight == b.marginRight && a.marginBottom == b.marginBottom
            && a.isActive == b.isActive
    }
}

extension DuoState: Equatable {
    public static func == (a: Self, b: Self) -> Bool {
        a.isSupported == b.isSupported && a.hingeStatus == b.hingeStatus
            && a.verticalBarEdge == b.verticalBarEdge
            && a.hingeAngle == b.hingeAngle && a.regions == b.regions
    }
}

extension DuoState {
    static let unavailable = DuoState(
        isSupported: false, hingeStatus: .unknown, verticalBarEdge: .unspecified,
        hingeAngle: nil, regions: [])
}

/// Hand-off between the UIKit main thread (writer) and Dart's UI isolate
/// (reader). `currentState()` is a synchronous FFI call from the UI isolate, so
/// it must never touch UIKit itself.
final class DuoStateBox: @unchecked Sendable {
    private let lock = NSLock()
    private var value = DuoState.unavailable

    /// `CurrentValueSubject` so a late Dart subscriber gets the state it missed.
    let subject = CurrentValueSubject<DuoState, Never>(.unavailable)

    var current: DuoState {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    func publish(_ next: DuoState) {
        lock.lock()
        let changed = value != next
        if changed { value = next }
        lock.unlock()
        if changed { subject.send(next) }
    }
}

/// Transparent, non-interactive overlay pinned to the Flutter view.
///
/// Reserved regions are reported in a *view's* coordinate space, so the probe
/// mirrors the Flutter view's bounds — meaning its region frames are already in
/// Flutter logical pixels relative to Flutter's origin. It also exists to
/// observe layout: UIKit has no reserved-regions-did-change callback, so a
/// layout pass is the signal that the geometry may have moved.
private final class DuoProbeView: UIView {
    var onGeometryChange: (() -> Void)?

    override func layoutSubviews() {
        super.layoutSubviews()
        onGeometryChange?()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        onGeometryChange?()
    }

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        onGeometryChange?()
    }
}

/// Watches iPhone Duo fold/camera geometry and hinge state for the Flutter view.
///
/// Requires the iOS 27.1 SDK to build; the APIs are runtime-guarded so the
/// plugin still runs on older systems (reporting `isSupported == false`).
@MainActor
final class DuoFoldWatcher {
    static var shared: DuoFoldWatcher?

    private let box: DuoStateBox
    private var probe: DuoProbeView?
    private var hingeAngle: Double?
    private var hingeStatus: DuoHingeStatus = .unknown
    private var traitRegistration: (any UITraitChangeRegistration)?

    init(box: DuoStateBox) {
        self.box = box
        NotificationCenter.default.addObserver(
            self, selector: #selector(attach),
            name: UIWindow.didBecomeKeyNotification, object: nil)
        attach()
    }

    @objc private func attach() {
        guard probe?.window == nil, let host = Self.flutterView() else { return }
        probe?.removeFromSuperview()

        let probe = DuoProbeView(frame: host.bounds)
        probe.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        probe.isUserInteractionEnabled = false
        probe.backgroundColor = .clear
        probe.onGeometryChange = { [weak self] in self?.recompute() }
        host.addSubview(probe)

        // Layout already covers a rotation, but the vertical-bar edge is a
        // trait: register for it directly so an edge change can never be
        // missed. Older systems fall back to the layout signal.
        if #available(iOS 27.1, *) {
            traitRegistration = probe.registerForTraitChanges(
                UITraitCollection.systemTraitsAffectingVerticalBarEdge
            ) { [weak self] (_: DuoProbeView, _) in self?.recompute() }
        }

        if #available(iOS 27.1, *) {
            probe.addInteraction(UIHingeInteraction { [weak self] _, update in
                guard let self else { return }
                // A nil hinge means no hinge is available in this hierarchy —
                // reset rather than holding the last angle.
                if let hinge = update.hinge {
                    self.hingeAngle = Double(hinge.angle)
                    self.hingeStatus =
                        DuoHingeStatus(rawValue: Int64(hinge.status.rawValue)) ?? .unknown
                } else {
                    self.hingeAngle = nil
                    self.hingeStatus = .unknown
                }
                self.recompute()
            })
        }

        self.probe = probe
        recompute()
    }

    private func recompute() {
        guard let probe, probe.window != nil else {
            box.publish(.unavailable)
            return
        }

        var regions: [DuoReservedRegion] = []
        var supported = false
        var barEdge = DuoVerticalBarEdge.unspecified

        if #available(iOS 27.1, *) {
            supported = true
            barEdge =
                DuoVerticalBarEdge(
                    rawValue: Int64(probe.traitCollection.verticalBarEdge.rawValue))
                ?? .unspecified
            let kinds: [(UIView.ReservedRegion.Kind, DuoRegionKind)] = [
                (.division, .division),
                (.occlusion, .occlusion),
            ]
            for (nativeKind, kind) in kinds {
                // Ask for everything and forward `isActive`: the runtime's
                // default filtering is not consistently documented, and an
                // inactive region is still useful for planning a layout.
                for region in probe.reservedRegions(kind: nativeKind, options: .includeInactive) {
                    regions.append(
                        DuoReservedRegion(
                            kind: kind,
                            left: region.frame.minX,
                            top: region.frame.minY,
                            width: region.frame.width,
                            height: region.frame.height,
                            marginLeft: region.margins.left,
                            marginTop: region.margins.top,
                            marginRight: region.margins.right,
                            marginBottom: region.margins.bottom,
                            isActive: region.isActive))
                }
            }
        }

        box.publish(
            DuoState(
                isSupported: supported, hingeStatus: hingeStatus,
                verticalBarEdge: barEdge, hingeAngle: hingeAngle, regions: regions))
    }

    /// The `FlutterViewController`'s view, so region frames land in Flutter's
    /// coordinate space. Falls back to the window's root view.
    private static func flutterView() -> UIView? {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
        guard
            let root = (windows.first(where: \.isKeyWindow) ?? windows.first)?
                .rootViewController
        else { return nil }
        return firstFlutterView(in: root) ?? root.viewIfLoaded
    }

    private static func firstFlutterView(in controller: UIViewController) -> UIView? {
        if let flutter = controller as? FlutterViewController { return flutter.viewIfLoaded }
        for child in controller.children {
            if let view = firstFlutterView(in: child) { return view }
        }
        if let presented = controller.presentedViewController {
            return firstFlutterView(in: presented)
        }
        return nil
    }
}
