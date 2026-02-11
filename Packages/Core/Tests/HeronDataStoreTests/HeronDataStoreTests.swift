import Foundation
import XCTest
import HeronDataStore
import HeronModels

final class HeronDataStoreTests: XCTestCase {
    func testSaveFetchAndList() async throws {
        let directory = makeTemporaryDirectory()
        let store = FileObservationStore(directory: directory)

        let first = Observation(createdAt: Date(timeIntervalSince1970: 1_000), notes: "First")
        let second = Observation(createdAt: Date(timeIntervalSince1970: 2_000), notes: "Second")

        try await store.save(first)
        try await store.save(second)

        let fetched = try await store.fetch(id: first.id)
        XCTAssertEqual(fetched?.notes, "First")

        let listed = try await store.list(limit: 10)
        XCTAssertEqual(listed.count, 2)
        XCTAssertEqual(listed.map(\.id), [second.id, first.id])
    }

    func testSaveUpdatesExistingObservation() async throws {
        let directory = makeTemporaryDirectory()
        let store = FileObservationStore(directory: directory)

        let original = Observation(createdAt: Date(timeIntervalSince1970: 1_000), notes: "Old")
        try await store.save(original)

        let updated = Observation(
            id: original.id,
            createdAt: original.createdAt,
            notes: "Updated",
            consentProfileID: original.consentProfileID
        )
        try await store.save(updated)

        let listed = try await store.list(limit: 10)
        XCTAssertEqual(listed.count, 1)
        XCTAssertEqual(listed.first?.notes, "Updated")
    }

    func testListRespectsLimit() async throws {
        let directory = makeTemporaryDirectory()
        let store = FileObservationStore(directory: directory)

        for index in 0..<5 {
            let observation = Observation(
                createdAt: Date(timeIntervalSince1970: TimeInterval(index)),
                notes: "Obs \(index)"
            )
            try await store.save(observation)
        }

        let listed = try await store.list(limit: 3)
        XCTAssertEqual(listed.count, 3)
        XCTAssertEqual(listed.first?.notes, "Obs 4")
        XCTAssertEqual(listed.last?.notes, "Obs 2")
    }

    private func makeTemporaryDirectory() -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("HeronDataStoreTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.removeItem(at: directory)
        return directory
    }
}
