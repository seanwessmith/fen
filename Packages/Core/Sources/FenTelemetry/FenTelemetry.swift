import Foundation

public struct TelemetryEvent: Sendable, Hashable {
    public let name: String
    public let metadata: [String: String]

    public init(name: String, metadata: [String: String] = [:]) {
        self.name = name
        self.metadata = metadata
    }
}

public protocol TelemetryClient: Sendable {
    func record(_ event: TelemetryEvent)
}
