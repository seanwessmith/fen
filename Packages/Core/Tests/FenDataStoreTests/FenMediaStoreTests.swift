import Foundation
import XCTest
import FenMedia
import FenModels

final class FenMediaStoreTests: XCTestCase {
    func testPersistWritesVersionedEnvelope() async throws {
        let directory = makeTemporaryDirectory()
        let store = FileMediaStore(directory: directory)
        let asset = MediaAsset(observationID: ObservationID(), localURL: URL(fileURLWithPath: "/tmp/a.jpg"))

        try await store.save(asset)

        let fileURL = directory.appendingPathComponent("media-assets.json", isDirectory: false)
        let data = try Data(contentsOf: fileURL)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertEqual(json?["version"] as? Int, 1)
        let assets = json?["assets"] as? [[String: Any]]
        XCTAssertEqual(assets?.count, 1)
    }

    func testListRecoversFromCorruptJSON() async throws {
        let directory = makeTemporaryDirectory()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent("media-assets.json", isDirectory: false)
        try Data("{ this is broken".utf8).write(to: fileURL, options: .atomic)

        let store = FileMediaStore(directory: directory)
        let assets = try await store.list(observationID: nil)

        XCTAssertTrue(assets.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))

        let quarantined = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .map(\.lastPathComponent)
            .filter { $0.hasPrefix("media-assets.corrupt-") && $0.hasSuffix(".json") }
        XCTAssertEqual(quarantined.count, 1)
    }

    private func makeTemporaryDirectory() -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FenMediaStoreTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.removeItem(at: directory)
        return directory
    }
}
