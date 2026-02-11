import Foundation
import FenModels

public enum ConsentDecision: Sendable {
    case allow
    case deny
    case deferred
}

public protocol ConsentPolicyEvaluating: Sendable {
    func canShare(observation: Observation) async -> ConsentDecision
}
