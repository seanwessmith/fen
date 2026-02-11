import Foundation
import HeronModels

public struct MediaAssetID: Hashable, Codable, Sendable {
    public let rawValue: UUID

    public init(_ rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }
}

public struct MediaAsset: Hashable, Codable, Sendable {
    public let id: MediaAssetID
    public let observationID: ObservationID
    public let localURL: URL
    public let createdAt: Date

    public init(
        id: MediaAssetID = MediaAssetID(),
        observationID: ObservationID,
        localURL: URL,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.observationID = observationID
        self.localURL = localURL
        self.createdAt = createdAt
    }
}
