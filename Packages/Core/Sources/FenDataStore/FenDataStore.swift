import Foundation
import FenModels

public enum DataStoreError: Error {
    case notFound
    case invalidStorageLocation
}

public protocol ObservationStore: Sendable {
    func save(_ observation: Observation) async throws
    func fetch(id: ObservationID) async throws -> Observation?
    func list(limit: Int) async throws -> [Observation]
}

public actor FileObservationStore: ObservationStore {
    private struct Envelope: Codable {
        let version: Int
        let observations: [Observation]
    }

    private static let currentVersion = 1

    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(filename: String = "observations.json", directory: URL? = nil) {
        let baseDirectory = directory ?? Self.defaultStorageDirectory()
        self.fileURL = baseDirectory.appendingPathComponent(filename, isDirectory: false)
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    public func save(_ observation: Observation) async throws {
        var observations = try loadAll()

        if let index = observations.firstIndex(where: { $0.id == observation.id }) {
            observations[index] = observation
        } else {
            observations.append(observation)
        }

        try persist(observations)
    }

    public func fetch(id: ObservationID) async throws -> Observation? {
        try loadAll().first(where: { $0.id == id })
    }

    public func list(limit: Int) async throws -> [Observation] {
        guard limit > 0 else { return [] }

        return try loadAll()
            .sorted(by: { $0.createdAt > $1.createdAt })
            .prefix(limit)
            .map { $0 }
    }

    private func loadAll() throws -> [Observation] {
        let manager = FileManager.default
        guard manager.fileExists(atPath: fileURL.path) else { return [] }

        let data = try Data(contentsOf: fileURL)

        if let envelope = try? decoder.decode(Envelope.self, from: data) {
            return envelope.observations
        }

        if let legacy = try? decoder.decode([Observation].self, from: data) {
            try persist(legacy)
            return legacy
        }

        quarantineCorruptFileIfNeeded()
        return []
    }

    private func persist(_ observations: [Observation]) throws {
        let manager = FileManager.default
        let directoryURL = fileURL.deletingLastPathComponent()

        try manager.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
        let envelope = Envelope(version: Self.currentVersion, observations: observations)
        let data = try encoder.encode(envelope)
        try data.write(to: fileURL, options: .atomic)
    }

    private func quarantineCorruptFileIfNeeded() {
        let manager = FileManager.default
        guard manager.fileExists(atPath: fileURL.path) else { return }

        let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let baseName = fileURL.deletingPathExtension().lastPathComponent
        let pathExtension = fileURL.pathExtension
        let quarantinedURL = fileURL
            .deletingLastPathComponent()
            .appendingPathComponent("\(baseName).corrupt-\(timestamp).\(pathExtension)", isDirectory: false)

        do {
            if manager.fileExists(atPath: quarantinedURL.path) {
                try manager.removeItem(at: quarantinedURL)
            }
            try manager.moveItem(at: fileURL, to: quarantinedURL)
        } catch {
        }
    }

    private static func defaultStorageDirectory() -> URL {
        let manager = FileManager.default

        if let url = manager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            return url.appendingPathComponent("Fen", isDirectory: true)
        }

        return manager.temporaryDirectory.appendingPathComponent("Fen", isDirectory: true)
    }
}
