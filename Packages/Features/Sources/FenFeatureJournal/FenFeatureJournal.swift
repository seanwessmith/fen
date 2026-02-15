import SwiftUI
import MapKit
import CoreLocation
import FenDataStore
import FenDesignSystem
import FenMedia
import FenModels
import FenSwiftUIComponents
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public struct JournalView: View {
    private let observationStore: any ObservationStore
    private let mediaStore: any MediaStore
    @State private var observations: [Observation] = []
    @State private var mediaByObservation: [ObservationID: [MediaAsset]] = [:]
    @State private var isLoading = false
    @State private var errorMessage: String?

    public init(observationStore: any ObservationStore, mediaStore: any MediaStore) {
        self.observationStore = observationStore
        self.mediaStore = mediaStore
    }

    public var body: some View {
        Group {
            if isLoading && observations.isEmpty {
                ProgressView("Loading Journal...")
            } else if observations.isEmpty {
                VStack(spacing: CGFloat(FenDesignTokens.spacingSmall)) {
                    Text("No observations yet.")
                    Text("Save one from the Capture tab.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(CGFloat(FenDesignTokens.spacingLarge))
            } else {
                List(observations, id: \.id) { observation in
                    NavigationLink {
                        ObservationDetailView(
                            observation: observation,
                            observationStore: observationStore,
                            mediaAssets: mediaByObservation[observation.id] ?? [],
                            onSave: { updated in
                                upsert(updated)
                            }
                        )
                    } label: {
                        HStack(spacing: 10) {
                            MediaThumbnailView(asset: mediaByObservation[observation.id]?.first)

                            VStack(alignment: .leading, spacing: 6) {
                                Text(observation.notes.isEmpty ? "Untitled observation" : observation.notes)
                                    .lineLimit(2)
                                Text(observation.createdAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)

                                let mediaCount = mediaByObservation[observation.id]?.count ?? 0
                                if mediaCount > 0 {
                                    Text("\(mediaCount) photo(s)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                if let speciesStatusText = speciesStatusText(for: observation) {
                                    Text(speciesStatusText)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .accessibilityIdentifier("journal.row")
                }
                .accessibilityIdentifier("journal.list")
            }
        }
        .navigationTitle("Journal")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Refresh") {
                    Task {
                        await loadObservations()
                    }
                }
                .accessibilityIdentifier("journal.refreshButton")
            }
        }
        .task {
            await loadObservations()
        }
        .alert("Journal Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { newValue in
                if !newValue {
                    errorMessage = nil
                }
            }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
    }

    private func loadObservations() async {
        await MainActor.run {
            isLoading = true
        }

        do {
            let result = try await observationStore.list(limit: 500)
            let assets = try await mediaStore.list(observationID: nil)
            let grouped = Dictionary(grouping: assets, by: \.observationID)
            await MainActor.run {
                observations = result
                mediaByObservation = grouped
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    private func upsert(_ observation: Observation) {
        if let index = observations.firstIndex(where: { $0.id == observation.id }) {
            observations[index] = observation
        } else {
            observations.append(observation)
        }

        observations.sort(by: { $0.createdAt > $1.createdAt })
    }

    private func speciesStatusText(for observation: Observation) -> String? {
        switch observation.speciesIdentificationStatus {
        case .pending:
            return "Identifying species..."
        case .completed:
            if let rank = observation.taxonomy?.lowestAvailableRank {
                return "\(rank.label): \(rank.value)"
            }
            return "Species identified"
        case .failed:
            return "Undetermined"
        case .none:
            return nil
        }
    }
}

private struct ObservationDetailView: View {
    let observation: Observation
    let observationStore: any ObservationStore
    let mediaAssets: [MediaAsset]
    let onSave: (Observation) -> Void

    @State private var notes: String
    @State private var isSaving = false
    @State private var statusMessage: String?

    init(
        observation: Observation,
        observationStore: any ObservationStore,
        mediaAssets: [MediaAsset],
        onSave: @escaping (Observation) -> Void
    ) {
        self.observation = observation
        self.observationStore = observationStore
        self.mediaAssets = mediaAssets
        self.onSave = onSave
        _notes = State(initialValue: observation.notes)
    }

    var body: some View {
        Form {
            Section("Created") {
                Text(observation.createdAt.formatted(date: .abbreviated, time: .shortened))
            }

            Section("Notes") {
                TextField("Observation notes", text: $notes, axis: .vertical)
                    .lineLimit(3...10)
                    .accessibilityIdentifier("journal.detail.notesField")
            }

            if !mediaAssets.isEmpty {
                Section("Photos (\(mediaAssets.count))") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(mediaAssets, id: \.id) { asset in
                                MediaThumbnailView(asset: asset)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .accessibilityIdentifier("journal.detail.mediaList")
                }
            }

            Section("Species") {
                switch observation.speciesIdentificationStatus {
                case .pending:
                    Text("Identifying species...")
                case .completed:
                    if observation.taxonomy != nil {
                        SpeciesReferenceView(observation: observation)
                    } else {
                        Text("Species identified")
                    }
                case .failed:
                    Text("Taxonomic identification is undetermined.")
                case .none:
                    Text("No species data")
                }

                ObservationLocationView(context: observation.speciesIdentificationContext)
            }

            Section {
                Button {
                    save()
                } label: {
                    if isSaving {
                        ProgressView()
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        Text("Save Changes")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .disabled(isSaving)
                .accessibilityIdentifier("journal.detail.saveButton")
            }

            if let statusMessage {
                Section("Status") {
                    Text(statusMessage)
                        .accessibilityIdentifier("journal.detail.statusMessage")
                }
            }
        }
        .navigationTitle("Observation")
    }

    private func save() {
        isSaving = true

        Task {
            do {
                let updated = Observation(
                    id: observation.id,
                    createdAt: observation.createdAt,
                    notes: notes,
                    consentProfileID: observation.consentProfileID,
                    speciesIdentificationStatus: observation.speciesIdentificationStatus,
                    speciesIdentificationContext: observation.speciesIdentificationContext,
                    taxonomy: observation.taxonomy,
                    speciesPredictionSource: observation.speciesPredictionSource,
                    speciesPredictionDiagnostics: observation.speciesPredictionDiagnostics,
                    speciesCandidates: observation.speciesCandidates,
                    speciesIdentifiedAt: observation.speciesIdentifiedAt
                )
                try await observationStore.save(updated)

                await MainActor.run {
                    onSave(updated)
                    statusMessage = "Saved."
                    isSaving = false
                }
            } catch {
                await MainActor.run {
                    statusMessage = "Save failed: \(error.localizedDescription)"
                    isSaving = false
                }
            }
        }
    }
}

private struct SpeciesReferenceView: View {
    let observation: Observation

    private var taxonomy: Observation.Taxonomy? {
        observation.taxonomy
    }

    private var topCandidate: SpeciesCandidate? {
        observation.speciesCandidates?.max(by: { $0.confidence < $1.confidence })
    }

    var body: some View {
        if let taxonomy {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(commonName(for: topCandidate, taxonomy: taxonomy))
                            .font(.title2.weight(.bold))

                        Text(scientificName(for: topCandidate, taxonomy: taxonomy))
                            .font(.caption)
                            .italic()
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 8)

                    VStack(alignment: .trailing, spacing: 1) {
                        Text(confidencePercentText(topCandidate?.confidence ?? 0))
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.green)
                        Text("Confidence")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.green)
                    }
                }

                Text(sourceLabel(observation.speciesPredictionSource ?? .fallback))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        } else {
            Text("No taxonomy returned")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func sourceLabel(_ source: SpeciesPrediction.Source) -> String {
        switch source {
        case .cloud:
            return "Cloud (iNaturalist)"
        case .onDevice:
            return "On-device model"
        case .fallback:
            return "Fallback"
        }
    }

    private func confidencePercentText(_ confidence: Double) -> String {
        String(format: "%.1f%%", max(0, min(confidence, 1)) * 100)
    }

    private func commonName(for candidate: SpeciesCandidate?, taxonomy: Observation.Taxonomy) -> String {
        guard let candidate else {
            return taxonomy.lowestAvailableRank?.value ?? "Unlabeled taxon"
        }
        let scientific = scientificName(for: candidate, taxonomy: taxonomy).lowercased()
        if candidate.label.lowercased() == scientific {
            return "Unlabeled taxon"
        }
        return candidate.label
    }

    private func scientificName(for candidate: SpeciesCandidate?, taxonomy: Observation.Taxonomy) -> String {
        taxonomy.species
            ?? taxonomy.genus
            ?? taxonomy.family
            ?? taxonomy.order
            ?? taxonomy.className
            ?? taxonomy.phylum
            ?? taxonomy.kingdom
            ?? taxonomy.domain
            ?? candidate?.label
            ?? "Unspecified taxon"
    }
}

private struct MediaThumbnailView: View {
    let asset: MediaAsset?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.12))

            if let url = asset?.localURL {
                LocalMediaImage(url: url)
            } else {
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct LocalMediaImage: View {
    let url: URL

    var body: some View {
#if canImport(UIKit)
        if let image = UIImage(contentsOfFile: url.path) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            Image(systemName: "photo")
                .foregroundStyle(.secondary)
        }
#elseif canImport(AppKit)
        if let image = NSImage(contentsOf: url) {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
        } else {
            Image(systemName: "photo")
                .foregroundStyle(.secondary)
        }
#else
        Image(systemName: "photo")
            .foregroundStyle(.secondary)
#endif
    }
}

private struct ObservationLocationView: View {
    let context: SpeciesIdentificationContext?
    @State private var addressLine = "Resolving address..."

    private var hasRealCoordinate: Bool {
        context?.latitude != nil && context?.longitude != nil
    }

    private var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: context?.latitude ?? 0,
            longitude: context?.longitude ?? 0
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if #available(iOS 17.0, macOS 14.0, *) {
                Map(
                    initialPosition: .region(
                        MKCoordinateRegion(
                            center: coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                        )
                    ),
                    interactionModes: []
                ) {
                    Marker("Observed location", coordinate: coordinate)
                }
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.secondary.opacity(0.12))
                    .overlay {
                        VStack(spacing: 4) {
                            Image(systemName: "map")
                                .foregroundStyle(.secondary)
                            Text(String(format: "%.5f, %.5f", coordinate.latitude, coordinate.longitude))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                .frame(height: 180)
            }

            Text("Observed in")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(addressLine)
                .font(.body)

            Text(observedAtText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .task(id: locationKey) {
            await resolveAddress()
        }
    }

    private var locationKey: String {
        "\(context?.latitude ?? 0),\(context?.longitude ?? 0)"
    }

    private var observedAtText: String {
        guard let observedAt = context?.observedAt else {
            return "Date/time unavailable"
        }
        return observedAt.formatted(date: .abbreviated, time: .complete)
    }

    private func resolveAddress() async {
        guard hasRealCoordinate else {
            addressLine = "Location unavailable"
            return
        }

        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let geocoder = CLGeocoder()

        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            if let placemark = placemarks.first {
                let parts = [
                    placemark.name,
                    placemark.locality,
                    placemark.administrativeArea,
                    placemark.postalCode,
                    placemark.country
                ]
                .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

                if parts.isEmpty {
                    addressLine = String(format: "%.5f, %.5f", coordinate.latitude, coordinate.longitude)
                } else {
                    addressLine = parts.joined(separator: ", ")
                }
            } else {
                addressLine = String(format: "%.5f, %.5f", coordinate.latitude, coordinate.longitude)
            }
        } catch {
            addressLine = String(format: "%.5f, %.5f", coordinate.latitude, coordinate.longitude)
        }
    }
}
