import Foundation

/// Native implementation of HybridNitroFoldDuoProtocol on macOS.
public class NitroFoldDuoImpl: NSObject, HybridNitroFoldDuoProtocol {

    public func add(a: Double, b: Double) -> Double {
        return a + b
    }

    public func getGreeting(name: String) async throws -> String {
        return "Hello, \(name) from macOS!"
    }
}
