import Foundation
import FenModels

public enum INaturalistSpeciesIdentifierError: LocalizedError, Sendable {
    case emptyImageData
    case missingAPIToken
    case invalidHTTPResponse
    case requestFailed(statusCode: Int, message: String?)
    case decodingFailed
    case noPredictions

    public var errorDescription: String? {
        switch self {
        case .emptyImageData:
            return "No image data was provided."
        case .missingAPIToken:
            return "INATURALIST_API_TOKEN is not configured."
        case .invalidHTTPResponse:
            return "Received an invalid response from iNaturalist."
        case let .requestFailed(statusCode, message):
            if let message, !message.isEmpty {
                return "iNaturalist request failed (\(statusCode)): \(message)"
            }
            return "iNaturalist request failed (\(statusCode))."
        case .decodingFailed:
            return "Unable to decode iNaturalist computer vision response."
        case .noPredictions:
            return "iNaturalist did not return any predictions."
        }
    }
}

public struct INaturalistSpeciesIdentifier: SpeciesIdentifier {
    private let baseURL: URL
    private let apiToken: String?
    private let requestTimeout: TimeInterval

    public init(
        baseURL: URL = URL(string: "https://api.inaturalist.org")!,
        apiToken: String? = nil,
        requestTimeout: TimeInterval = 8
    ) {
        self.baseURL = baseURL
        self.apiToken = apiToken?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.requestTimeout = requestTimeout
    }

    public func identifySpecies(
        in imageData: Data,
        context: SpeciesIdentificationContext
    ) async throws -> SpeciesPrediction {
        guard !imageData.isEmpty else {
            throw INaturalistSpeciesIdentifierError.emptyImageData
        }
        guard let token = apiToken, !token.isEmpty else {
            throw INaturalistSpeciesIdentifierError.missingAPIToken
        }

        let request = makeRequest(imageData: imageData, apiToken: token, context: context)
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw INaturalistSpeciesIdentifierError.invalidHTTPResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw INaturalistSpeciesIdentifierError.requestFailed(
                statusCode: httpResponse.statusCode,
                message: message
            )
        }

        let decoded: APIResponse
        do {
            decoded = try JSONDecoder().decode(APIResponse.self, from: data)
        } catch {
            throw INaturalistSpeciesIdentifierError.decodingFailed
        }

        let candidates = decoded.results.compactMap(Self.makeCandidate(from:))
        guard !candidates.isEmpty else {
            throw INaturalistSpeciesIdentifierError.noPredictions
        }

        return SpeciesPrediction(
            source: .cloud,
            candidates: candidates,
            diagnostics: "Cloud classification succeeded with \(candidates.count) candidate(s)."
        )
    }

    private func makeRequest(
        imageData: Data,
        apiToken: String,
        context: SpeciesIdentificationContext
    ) -> URLRequest {
        let endpoint = baseURL
            .appendingPathComponent("v1", isDirectory: true)
            .appendingPathComponent("computervision", isDirectory: true)
            .appendingPathComponent("score_image", isDirectory: false)

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = requestTimeout
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let authorization = apiToken.lowercased().hasPrefix("bearer ")
            ? apiToken
            : "Bearer \(apiToken)"
        request.setValue(authorization, forHTTPHeaderField: "Authorization")
        request.httpBody = Self.makeMultipartBody(
            boundary: boundary,
            imageData: imageData,
            context: context
        )
        return request
    }

    private static func makeMultipartBody(
        boundary: String,
        imageData: Data,
        context: SpeciesIdentificationContext
    ) -> Data {
        var body = Data()
        body.appendFormField(
            name: "image",
            filename: "capture.jpg",
            mimeType: "image/jpeg",
            data: imageData,
            boundary: boundary
        )

        if let latitude = context.latitude {
            body.appendTextField(name: "lat", value: String(latitude), boundary: boundary)
        }
        if let longitude = context.longitude {
            body.appendTextField(name: "lng", value: String(longitude), boundary: boundary)
        }
        if let observedAt = context.observedAt {
            body.appendTextField(
                name: "observed_on",
                value: observedOnFormatter.string(from: observedAt),
                boundary: boundary
            )
        }

        body.appendUTF8("--\(boundary)--\r\n")
        return body
    }

    private static func makeCandidate(from result: ResultPayload) -> SpeciesCandidate? {
        guard let taxon = result.taxon else { return nil }
        var taxonomy = taxonomy(from: taxon)

        if taxonomy.lowestAvailableRank == nil, let taxonName = taxon.name, !taxonName.isEmpty {
            taxonomy = Observation.Taxonomy(species: taxonName)
        }

        guard taxonomy.lowestAvailableRank != nil else { return nil }

        let rawScore = result.combinedScore ?? result.visionScore ?? 0
        let confidence = normalizedConfidence(rawScore)
        let label = taxon.preferredCommonName ?? taxon.name ?? taxonomy.lowestAvailableRank?.value ?? "Unknown"
        let photoURLs = photoURLs(from: taxon)

        return SpeciesCandidate(label: label, confidence: confidence, taxonomy: taxonomy, photoURLs: photoURLs)
    }

    private static func photoURLs(from taxon: TaxonPayload) -> [URL] {
        var urls: [URL] = []

        if let defaultPhoto = taxon.defaultPhoto {
            if let url = normalizedURL(defaultPhoto.mediumURL ?? defaultPhoto.url ?? defaultPhoto.squareURL) {
                urls.append(url)
            }
        }

        for taxonPhoto in taxon.taxonPhotos ?? [] {
            guard let photo = taxonPhoto.photo else { continue }
            if let url = normalizedURL(photo.mediumURL ?? photo.url ?? photo.squareURL) {
                urls.append(url)
            }
        }

        var seen = Set<URL>()
        return urls.filter { seen.insert($0).inserted }
    }

    private static func normalizedURL(_ rawValue: String?) -> URL? {
        guard var value = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        if value.hasPrefix("//") {
            value = "https:" + value
        }
        return URL(string: value)
    }

    private static func taxonomy(from taxon: TaxonPayload) -> Observation.Taxonomy {
        var domain: String?
        var kingdom: String?
        var phylum: String?
        var className: String?
        var order: String?
        var family: String?
        var genus: String?
        var species: String?

        let lineage = (taxon.ancestors ?? []) + [LineageNode(rank: taxon.rank, name: taxon.name)]

        for node in lineage {
            guard let rawRank = node.rank?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                  let name = node.name?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !rawRank.isEmpty,
                  !name.isEmpty
            else {
                continue
            }

            switch canonicalRank(rawRank) {
            case "domain", "superkingdom":
                domain = name
            case "kingdom", "subkingdom":
                kingdom = name
            case "phylum", "subphylum", "superphylum":
                phylum = name
            case "class", "subclass", "superclass":
                className = name
            case "order", "suborder", "infraorder", "superorder":
                order = name
            case "family", "subfamily", "superfamily", "tribe", "subtribe":
                family = name
            case "genus", "subgenus":
                genus = name
            case "species", "hybrid", "subspecies", "variety", "form":
                species = name
            default:
                continue
            }
        }

        return Observation.Taxonomy(
            domain: domain,
            kingdom: kingdom,
            phylum: phylum,
            className: className,
            order: order,
            family: family,
            genus: genus,
            species: species
        )
    }

    private static func canonicalRank(_ rank: String) -> String {
        rank.replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
    }

    private static func normalizedConfidence(_ score: Double) -> Double {
        let zeroToOne = score > 1 ? score / 100 : score
        return min(max(zeroToOne, 0), 1)
    }
}

public struct FallbackSpeciesIdentifier: SpeciesIdentifier {
    private let primary: any SpeciesIdentifier
    private let fallback: any SpeciesIdentifier

    public init(primary: any SpeciesIdentifier, fallback: any SpeciesIdentifier) {
        self.primary = primary
        self.fallback = fallback
    }

    public func identifySpecies(
        in imageData: Data,
        context: SpeciesIdentificationContext
    ) async throws -> SpeciesPrediction {
        do {
            return try await primary.identifySpecies(in: imageData, context: context)
        } catch {
            let fallbackPrediction = try await fallback.identifySpecies(in: imageData, context: context)
            let reason = Self.sanitizedErrorDescription(error)
            let existingDiagnostics = fallbackPrediction.diagnostics?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let fallbackDiagnostics: String
            if let existingDiagnostics, !existingDiagnostics.isEmpty {
                fallbackDiagnostics = "Primary failed: \(reason) Fallback: \(existingDiagnostics)"
            } else {
                fallbackDiagnostics = "Primary failed: \(reason) Fallback source: \(fallbackPrediction.source.rawValue)."
            }

            return SpeciesPrediction(
                source: fallbackPrediction.source,
                candidates: fallbackPrediction.candidates,
                diagnostics: fallbackDiagnostics
            )
        }
    }

    private static func sanitizedErrorDescription(_ error: Error) -> String {
        let text = error.localizedDescription
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
        let compact = text.split(separator: " ", omittingEmptySubsequences: true).joined(separator: " ")
        if compact.count <= 240 {
            return compact
        }
        let end = compact.index(compact.startIndex, offsetBy: 240)
        return String(compact[..<end]) + "..."
    }
}

private struct APIResponse: Decodable {
    let results: [ResultPayload]
}

private struct ResultPayload: Decodable {
    let combinedScore: Double?
    let visionScore: Double?
    let taxon: TaxonPayload?

    enum CodingKeys: String, CodingKey {
        case combinedScore = "combined_score"
        case visionScore = "vision_score"
        case taxon
    }
}

private struct TaxonPayload: Decodable {
    let name: String?
    let preferredCommonName: String?
    let rank: String?
    let ancestors: [LineageNode]?
    let defaultPhoto: PhotoPayload?
    let taxonPhotos: [TaxonPhotoPayload]?

    enum CodingKeys: String, CodingKey {
        case name
        case preferredCommonName = "preferred_common_name"
        case rank
        case ancestors
        case defaultPhoto = "default_photo"
        case taxonPhotos = "taxon_photos"
    }
}

private struct LineageNode: Decodable {
    let rank: String?
    let name: String?
}

private struct TaxonPhotoPayload: Decodable {
    let photo: PhotoPayload?
}

private struct PhotoPayload: Decodable {
    let url: String?
    let mediumURL: String?
    let squareURL: String?

    enum CodingKeys: String, CodingKey {
        case url
        case mediumURL = "medium_url"
        case squareURL = "square_url"
    }
}

private let observedOnFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
}()

private extension Data {
    mutating func appendTextField(name: String, value: String, boundary: String) {
        appendUTF8("--\(boundary)\r\n")
        appendUTF8("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
        appendUTF8("\(value)\r\n")
    }

    mutating func appendFormField(
        name: String,
        filename: String,
        mimeType: String,
        data: Data,
        boundary: String
    ) {
        appendUTF8("--\(boundary)\r\n")
        appendUTF8("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n")
        appendUTF8("Content-Type: \(mimeType)\r\n\r\n")
        append(data)
        appendUTF8("\r\n")
    }

    mutating func appendUTF8(_ value: String) {
        if let utf8Data = value.data(using: .utf8) {
            append(utf8Data)
        }
    }
}
