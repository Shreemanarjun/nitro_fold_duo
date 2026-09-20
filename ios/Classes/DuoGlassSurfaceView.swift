import Flutter
import UIKit

/// A Liquid Glass panel: the same material as the bar's capsules, without the
/// buttons.
///
/// iOS puts real material behind chrome that content scrolls under — the
/// leading-edge title on Duo, for one — so a Flutter blur approximating it
/// reads wrong next to the system's own. This is the real effect.
final class DuoGlassSurfaceFactory: NSObject, FlutterPlatformViewFactory {
    func create(
        withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?
    ) -> FlutterPlatformView {
        DuoGlassSurfaceView(frame: frame, viewId: viewId)
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        FlutterStandardMessageCodec.sharedInstance()
    }
}

@MainActor
enum DuoGlassSurfaceRegistry {
    private static var views: [Int64: DuoGlassSurfaceView] = [:]

    static func add(_ view: DuoGlassSurfaceView, id: Int64) { views[id] = view }
    static func remove(id: Int64) { views.removeValue(forKey: id) }

    static func apply(id: Int64, cornerRadius: Double, tint: Int, isDark: Bool) {
        views[id]?.apply(cornerRadius: cornerRadius, tint: tint, isDark: isDark)
    }
}

final class DuoGlassSurfaceView: NSObject, FlutterPlatformView {
    private let effectView = UIVisualEffectView()
    private let viewId: Int64

    init(frame: CGRect, viewId: Int64) {
        self.viewId = viewId
        super.init()

        effectView.frame = frame
        effectView.clipsToBounds = true
        // Purely decorative: the Flutter content above it takes the touches.
        effectView.isUserInteractionEnabled = false
        applyEffect(tint: nil)

        MainActor.assumeIsolated { DuoGlassSurfaceRegistry.add(self, id: viewId) }
    }

    deinit {
        let id = viewId
        Task { @MainActor in DuoGlassSurfaceRegistry.remove(id: id) }
    }

    func view() -> UIView { effectView }

    @MainActor
    func apply(cornerRadius: Double, tint argb: Int, isDark: Bool) {
        effectView.overrideUserInterfaceStyle = isDark ? .dark : .light
        effectView.layer.cornerRadius = CGFloat(cornerRadius)
        effectView.layer.cornerCurve = .continuous
        applyEffect(tint: argb == 0 ? nil : Self.color(argb: argb))
    }

    private func applyEffect(tint: UIColor?) {
        if #available(iOS 26.0, *) {
            let glass = UIGlassEffect()
            glass.tintColor = tint
            effectView.effect = glass
        } else {
            effectView.effect = UIBlurEffect(style: .systemThinMaterial)
        }
    }

    private static func color(argb: Int) -> UIColor {
        UIColor(
            red: CGFloat((argb >> 16) & 0xFF) / 255,
            green: CGFloat((argb >> 8) & 0xFF) / 255,
            blue: CGFloat(argb & 0xFF) / 255,
            alpha: CGFloat((argb >> 24) & 0xFF) / 255)
    }
}
