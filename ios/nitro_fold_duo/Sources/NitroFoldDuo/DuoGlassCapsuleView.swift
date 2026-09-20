import Combine
import Flutter
import UIKit

extension DuoBarPress: @unchecked Sendable {}

/// Carries capsule button presses from the UIKit main thread to Dart's UI
/// isolate over the Nitro stream — no per-view method channel.
final class DuoCapsuleBus: @unchecked Sendable {
    static let shared = DuoCapsuleBus()
    let presses = PassthroughSubject<DuoBarPress, Never>()
    private init() {}
}

/// Live capsules, keyed by the platform view id Flutter hands to
/// `onPlatformViewCreated`. Dart addresses a capsule by that id.
@MainActor
enum DuoGlassCapsuleRegistry {
    private static var views: [Int64: DuoGlassCapsuleView] = [:]

    static func add(_ view: DuoGlassCapsuleView, id: Int64) { views[id] = view }
    static func remove(id: Int64) { views.removeValue(forKey: id) }

    static func apply(
        id: Int64, symbols: [String], selectedIndex: Int, tint: Int, isDark: Bool
    ) {
        views[id]?.apply(
            symbols: symbols, selectedIndex: selectedIndex, tint: tint, isDark: isDark)
    }

    static func setMenu(
        id: Int64, buttonIndex: Int, titles: [String], symbols: [String]
    ) {
        views[id]?.setMenu(buttonIndex: buttonIndex, titles: titles, symbols: symbols)
    }
}

/// A vertical Liquid Glass capsule holding a column of icon buttons.
///
/// This is the building block of the iPhone Duo vertical bar, where the system
/// shows each group of toolbar items — and the tab bar — as one glass capsule.
/// The strip's *layout* is composed in Flutter: iOS only lays out
/// container-managed bars vertically, never a hand-built `UINavigationBar`. The
/// capsule material itself is the real thing.
final class DuoGlassCapsuleFactory: NSObject, FlutterPlatformViewFactory {
    func create(
        withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?
    ) -> FlutterPlatformView {
        DuoGlassCapsuleView(frame: frame, viewId: viewId)
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        FlutterStandardMessageCodec.sharedInstance()
    }
}

private final class CapsuleContainer: UIView {
    var onLayout: (() -> Void)?

    override func layoutSubviews() {
        super.layoutSubviews()
        onLayout?()
    }
}

final class DuoGlassCapsuleView: NSObject, FlutterPlatformView {
    private let container = CapsuleContainer()
    private let effectView = UIVisualEffectView()
    private let selection = UIView()
    private let stack = UIStackView()
    private let viewId: Int64

    private var symbols: [String] = []
    private var buttons: [UIButton] = []
    private var selectedIndex: Int?
    private var tint: UIColor?

    init(frame: CGRect, viewId: Int64) {
        self.viewId = viewId
        super.init()

        container.frame = frame
        container.backgroundColor = .clear

        if #available(iOS 26.0, *) {
            let glass = UIGlassEffect()
            glass.isInteractive = true
            effectView.effect = glass
        } else {
            effectView.effect = UIBlurEffect(style: .systemThinMaterial)
        }
        effectView.clipsToBounds = true
        effectView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(effectView)

        selection.backgroundColor = UIColor.label.withAlphaComponent(0.1)
        selection.isUserInteractionEnabled = false
        selection.isHidden = true
        effectView.contentView.addSubview(selection)

        stack.axis = .vertical
        stack.distribution = .fillEqually
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        effectView.contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            effectView.topAnchor.constraint(equalTo: container.topAnchor),
            effectView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            effectView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            effectView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.topAnchor.constraint(equalTo: effectView.contentView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: effectView.contentView.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: effectView.contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: effectView.contentView.trailingAnchor),
        ])

        container.onLayout = { [weak self] in self?.layoutChrome() }
        MainActor.assumeIsolated { DuoGlassCapsuleRegistry.add(self, id: viewId) }
    }

    deinit {
        let id = viewId
        Task { @MainActor in DuoGlassCapsuleRegistry.remove(id: id) }
    }

    func view() -> UIView { container }

    @MainActor
    func apply(symbols next: [String], selectedIndex index: Int, tint argb: Int, isDark: Bool) {
        container.overrideUserInterfaceStyle = isDark ? .dark : .light
        tint = argb == 0 ? nil : Self.color(argb: argb)
        selectedIndex = index < 0 ? nil : index

        if next != symbols {
            symbols = next
            rebuildButtons()  // drops any menu with the old buttons
        }
        for (i, button) in buttons.enumerated() {
            button.tintColor = tint ?? .label
            button.isSelected = i == selectedIndex
        }
        layoutChrome()
    }

    private func rebuildButtons() {
        buttons.forEach { $0.removeFromSuperview() }
        buttons = symbols.enumerated().map { index, symbol in
            let button = UIButton(type: .system)
            button.setImage(
                UIImage(
                    systemName: symbol,
                    withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .regular)),
                for: .normal)
            button.tag = index
            button.addTarget(self, action: #selector(pressed(_:)), for: .touchUpInside)
            stack.addArrangedSubview(button)
            return button
        }
    }

    /// The real system overflow menu: toolbar items that do not fit the strip
    /// are handed to `UIMenu` rather than drawn as extra capsules.
    @MainActor
    func setMenu(buttonIndex: Int, titles: [String], symbols: [String]) {
        guard buttons.indices.contains(buttonIndex) else { return }
        let button = buttons[buttonIndex]

        guard !titles.isEmpty else {
            button.menu = nil
            button.showsMenuAsPrimaryAction = false
            return
        }

        let id = viewId
        button.menu = UIMenu(
            children: titles.enumerated().map { entry, title in
                UIAction(
                    title: title,
                    image: symbols.indices.contains(entry)
                        ? UIImage(systemName: symbols[entry]) : nil
                ) { _ in
                    DuoCapsuleBus.shared.presses.send(
                        DuoBarPress(
                            viewId: id, index: Int64(buttonIndex),
                            menuIndex: Int64(entry)))
                }
            })
        button.showsMenuAsPrimaryAction = true
    }

    @objc private func pressed(_ sender: UIButton) {
        // A menu button opens its menu; it never reports a plain press.
        guard !sender.showsMenuAsPrimaryAction else { return }
        DuoCapsuleBus.shared.presses.send(
            DuoBarPress(viewId: viewId, index: Int64(sender.tag), menuIndex: -1))
    }

    /// Capsule corners, and the selection pill behind the selected tab.
    private func layoutChrome() {
        let radius = min(container.bounds.width, container.bounds.height) / 2
        effectView.layer.cornerRadius = radius
        effectView.layer.cornerCurve = .continuous

        guard let selectedIndex, buttons.indices.contains(selectedIndex) else {
            selection.isHidden = true
            return
        }
        selection.isHidden = false
        selection.frame = buttons[selectedIndex].frame.insetBy(dx: 4, dy: 4)
        selection.layer.cornerRadius = min(selection.bounds.width, selection.bounds.height) / 2
        selection.layer.cornerCurve = .continuous
    }

    private static func color(argb: Int) -> UIColor {
        UIColor(
            red: CGFloat((argb >> 16) & 0xFF) / 255,
            green: CGFloat((argb >> 8) & 0xFF) / 255,
            blue: CGFloat(argb & 0xFF) / 255,
            alpha: CGFloat((argb >> 24) & 0xFF) / 255)
    }
}
