import Foundation

public struct ObservationID: Hashable, Codable, Sendable {
    public let rawValue: UUID

    public init(_ rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }
}

public struct ConsentProfile: Hashable, Codable, Sendable {
    public enum TrainingPolicy: String, Codable, Sendable {
        case noTraining
        case researchOnly
        case ccBy
    }

    public let id: UUID
    public let name: String
    public let policy: TrainingPolicy

    public init(id: UUID = UUID(), name: String, policy: TrainingPolicy) {
        self.id = id
        self.name = name
        self.policy = policy
    }
}

public struct Observation: Hashable, Codable, Sendable {
    public let id: ObservationID
    public let createdAt: Date
    public let notes: String
    public let consentProfileID: UUID?

    public init(
        id: ObservationID = ObservationID(),
        createdAt: Date = Date(),
        notes: String,
        consentProfileID: UUID? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.notes = notes
        self.consentProfileID = consentProfileID
    }
}
