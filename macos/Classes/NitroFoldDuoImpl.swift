import Combine
import Foundation

/// Native implementation of HybridNitroFoldDuoProtocol on macOS.
/// macOS has no fold or hinge, so the Duo state is permanently unsupported.
public class NitroFoldDuoImpl: NSObject, HybridNitroFoldDuoProtocol {

    private static let unavailable = DuoState(
        isSupported: false, hingeStatus: .unknown, hingeAngle: nil, regions: [])

    public func add(a: Double, b: Double) -> Double {
        return a + b
    }

    public func getGreeting(name: String) async throws -> String {
        return "Hello, \(name) from macOS!"
    }

    public func currentState() -> DuoState {
        return Self.unavailable
    }

    public var stateChanges: AnyPublisher<DuoState, Never> {
        return Just(Self.unavailable).eraseToAnyPublisher()
    }
}
