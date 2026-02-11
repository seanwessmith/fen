import Foundation
import HeronModels

public enum DataStoreError: Error {
    case notFound
}

public protocol ObservationStore: Sendable {
    func save(_ observation: Observation) async throws
    func fetch(id: ObservationID) async throws -> Observation?
    func list(limit: Int) async throws -> [Observation]
}
