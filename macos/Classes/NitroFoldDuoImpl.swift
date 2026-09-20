import Combine
import Foundation

/// Native implementation of HybridNitroFoldDuoProtocol on macOS.
/// macOS has no fold or hinge, so the Duo state is permanently unsupported.
public class NitroFoldDuoImpl: NSObject, HybridNitroFoldDuoProtocol {

    private static let unavailable = DuoState(
        isSupported: false, hingeStatus: .unknown, verticalBarEdge: .unspecified,
        hingeAngle: nil, regions: [],
        cornerInsets: DuoInsets(left: 0, top: 0, right: 0, bottom: 0))


    public func currentState() -> DuoState {
        return Self.unavailable
    }

    public var stateChanges: AnyPublisher<DuoState, Never> {
        return Just(Self.unavailable).eraseToAnyPublisher()
    }

    // The Liquid Glass capsule is an iPhone Duo control; macOS has no strip.
    public func updateGlassCapsule(
        viewId: Int64, symbols: [String], titles: [String], selectedIndex: Int64,
        tint: Int64, isDark: Bool
    ) {}

    public func updateGlassSurface(
        viewId: Int64, cornerRadius: Double, tint: Int64, isDark: Bool
    ) {}

    public func setGlassCapsuleMenu(
        viewId: Int64, buttonIndex: Int64, titles: [String], symbols: [String]
    ) {}

    public var glassCapsulePresses: AnyPublisher<DuoBarPress, Never> {
        return Empty<DuoBarPress, Never>(completeImmediately: false).eraseToAnyPublisher()
    }
}
