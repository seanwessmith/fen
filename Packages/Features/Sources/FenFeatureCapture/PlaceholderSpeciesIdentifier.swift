import Foundation
import FenModels

public struct PlaceholderSpeciesIdentifier: SpeciesIdentifier {
    public init() {}

    public func identifySpecies(
        in _: Data,
        context _: SpeciesIdentificationContext
    ) async throws -> SpeciesPrediction {
        try await Task.sleep(for: .milliseconds(700))

        return SpeciesPrediction(
            source: .fallback,
            candidates: [],
            diagnostics: "No on-device fallback classifier configured. Returning undetermined."
        )
    }
}
