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

public protocol MediaStore: Sendable {
    func save(_ asset: MediaAsset) async throws
    func fetch(id: MediaAssetID) async throws -> MediaAsset?
    func list(observationID: ObservationID?) async throws -> [MediaAsset]
}

public actor FileMediaStore: MediaStore {
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(filename: String = "media-assets.json", directory: URL? = nil) {
        let baseDirectory = directory ?? Self.defaultStorageDirectory()
        self.fileURL = baseDirectory.appendingPathComponent(filename, isDirectory: false)
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    public func save(_ asset: MediaAsset) async throws {
        var assets = try loadAll()

        if let index = assets.firstIndex(where: { $0.id == asset.id }) {
            assets[index] = asset
        } else {
            assets.append(asset)
        }

        try persist(assets)
    }

    public func fetch(id: MediaAssetID) async throws -> MediaAsset? {
        try loadAll().first(where: { $0.id == id })
    }

    public func list(observationID: ObservationID? = nil) async throws -> [MediaAsset] {
        let assets = try loadAll().sorted(by: { $0.createdAt > $1.createdAt })

        guard let observationID else {
            return assets
        }

        return assets.filter { $0.observationID == observationID }
    }

    private func loadAll() throws -> [MediaAsset] {
        let manager = FileManager.default
        guard manager.fileExists(atPath: fileURL.path) else { return [] }

        let data = try Data(contentsOf: fileURL)
        return try decoder.decode([MediaAsset].self, from: data)
    }

    private func persist(_ assets: [MediaAsset]) throws {
        let manager = FileManager.default
        let directoryURL = fileURL.deletingLastPathComponent()

        try manager.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
        let data = try encoder.encode(assets)
        try data.write(to: fileURL, options: .atomic)
    }

    private static func defaultStorageDirectory() -> URL {
        let manager = FileManager.default

        if let url = manager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            return url.appendingPathComponent("Heron", isDirectory: true)
        }

        return manager.temporaryDirectory.appendingPathComponent("Heron", isDirectory: true)
    }
}
