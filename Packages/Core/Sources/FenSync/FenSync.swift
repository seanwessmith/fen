import Foundation
import FenDataStore
import FenModels
import FenNetworking
import FenPermissions
import FenTelemetry

public final class SyncEngine {
    private let store: ObservationStore
    private let network: NetworkClient
    private let consentEvaluator: ConsentPolicyEvaluating
    private let telemetry: TelemetryClient?

    public init(
        store: ObservationStore,
        network: NetworkClient,
        consentEvaluator: ConsentPolicyEvaluating,
        telemetry: TelemetryClient? = nil
    ) {
        self.store = store
        self.network = network
        self.consentEvaluator = consentEvaluator
        self.telemetry = telemetry
    }

    public func enqueue(observation: Observation) async throws {
        try await store.save(observation)
        telemetry?.record(TelemetryEvent(name: "sync.enqueue"))
    }
}
