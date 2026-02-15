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

public struct SpeciesIdentificationContext: Hashable, Codable, Sendable {
    public let latitude: Double?
    public let longitude: Double?
    public let observedAt: Date?

    public init(
        latitude: Double? = nil,
        longitude: Double? = nil,
        observedAt: Date? = nil
    ) {
        self.latitude = latitude
        self.longitude = longitude
        self.observedAt = observedAt
    }
}

public struct SpeciesCandidate: Hashable, Codable, Sendable {
    public let label: String
    public let confidence: Double
    public let taxonomy: Observation.Taxonomy
    public let photoURLs: [URL]

    public init(
        label: String,
        confidence: Double,
        taxonomy: Observation.Taxonomy,
        photoURLs: [URL] = []
    ) {
        self.label = label
        self.confidence = confidence
        self.taxonomy = taxonomy
        self.photoURLs = photoURLs
    }
}

public struct SpeciesPrediction: Hashable, Codable, Sendable {
    public enum Source: String, Codable, Sendable {
        case cloud
        case onDevice
        case fallback
    }

    public let source: Source
    public let candidates: [SpeciesCandidate]
    public let diagnostics: String?

    public init(
        source: Source,
        candidates: [SpeciesCandidate],
        diagnostics: String? = nil
    ) {
        self.source = source
        self.candidates = candidates
        self.diagnostics = diagnostics
    }

    public var topCandidate: SpeciesCandidate? {
        candidates.max(by: { $0.confidence < $1.confidence })
    }
}

public protocol SpeciesIdentifier: Sendable {
    func identifySpecies(
        in imageData: Data,
        context: SpeciesIdentificationContext
    ) async throws -> SpeciesPrediction
}

public struct Observation: Hashable, Codable, Sendable {
    public struct Taxonomy: Hashable, Codable, Sendable {
        public let domain: String?
        public let kingdom: String?
        public let phylum: String?
        public let className: String?
        public let order: String?
        public let family: String?
        public let genus: String?
        public let species: String?

        public init(
            domain: String? = nil,
            kingdom: String? = nil,
            phylum: String? = nil,
            className: String? = nil,
            order: String? = nil,
            family: String? = nil,
            genus: String? = nil,
            species: String? = nil
        ) {
            self.domain = domain
            self.kingdom = kingdom
            self.phylum = phylum
            self.className = className
            self.order = order
            self.family = family
            self.genus = genus
            self.species = species
        }

        public var lowestAvailableRank: (label: String, value: String)? {
            if let species, !species.isEmpty { return ("Species", species) }
            if let genus, !genus.isEmpty { return ("Genus", genus) }
            if let family, !family.isEmpty { return ("Family", family) }
            if let order, !order.isEmpty { return ("Order", order) }
            if let className, !className.isEmpty { return ("Class", className) }
            if let phylum, !phylum.isEmpty { return ("Phylum", phylum) }
            if let kingdom, !kingdom.isEmpty { return ("Kingdom", kingdom) }
            if let domain, !domain.isEmpty { return ("Domain", domain) }
            return nil
        }
    }

    public enum SpeciesIdentificationStatus: String, Codable, Sendable {
        case pending
        case completed
        case failed
    }

    public let id: ObservationID
    public let createdAt: Date
    public let notes: String
    public let consentProfileID: UUID?
    public let speciesIdentificationStatus: SpeciesIdentificationStatus?
    public let speciesIdentificationContext: SpeciesIdentificationContext?
    public let taxonomy: Taxonomy?
    public let speciesPredictionSource: SpeciesPrediction.Source?
    public let speciesPredictionDiagnostics: String?
    public let speciesCandidates: [SpeciesCandidate]?
    public let speciesIdentifiedAt: Date?

    public init(
        id: ObservationID = ObservationID(),
        createdAt: Date = Date(),
        notes: String,
        consentProfileID: UUID? = nil,
        speciesIdentificationStatus: SpeciesIdentificationStatus? = nil,
        speciesIdentificationContext: SpeciesIdentificationContext? = nil,
        taxonomy: Taxonomy? = nil,
        speciesPredictionSource: SpeciesPrediction.Source? = nil,
        speciesPredictionDiagnostics: String? = nil,
        speciesCandidates: [SpeciesCandidate]? = nil,
        speciesIdentifiedAt: Date? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.notes = notes
        self.consentProfileID = consentProfileID
        self.speciesIdentificationStatus = speciesIdentificationStatus
        self.speciesIdentificationContext = speciesIdentificationContext
        self.taxonomy = taxonomy
        self.speciesPredictionSource = speciesPredictionSource
        self.speciesPredictionDiagnostics = speciesPredictionDiagnostics
        self.speciesCandidates = speciesCandidates
        self.speciesIdentifiedAt = speciesIdentifiedAt
    }
}
