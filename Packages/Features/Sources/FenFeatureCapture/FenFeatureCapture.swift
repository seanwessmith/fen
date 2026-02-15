import SwiftUI
#if canImport(MapKit)
import MapKit
#endif
import FenDataStore
import FenMedia
import FenModels
#if canImport(CoreLocation)
import CoreLocation
#endif
#if canImport(UIKit)
import AVFoundation
import UIKit
#endif

#if canImport(UIKit)
private extension Notification.Name {
    static let fenCameraDidCapturePhoto = Notification.Name("FenCameraDidCapturePhoto")
}
#endif

public struct CaptureView: View {
    private enum RejectionGate {
        struct Thresholds {
            let minimumTopScore: Double
            let minimumMargin: Double
            let profileName: String
        }

        static let highConfidenceBypassTopScore = 0.75
        static let general = Thresholds(minimumTopScore: 0.65, minimumMargin: 0.20, profileName: "general")
        static let plant = Thresholds(minimumTopScore: 0.45, minimumMargin: 0.10, profileName: "plant")
    }

    private enum Style {
        static let fenGreen = Color(red: 0 / 255, green: 66 / 255, blue: 37 / 255)
        static let actionHeight: CGFloat = 44
        static let shutterSize: CGFloat = 92
        static let shutterIconSize: CGFloat = 30
    }

    private let observationStore: any ObservationStore
    private let mediaStore: any MediaStore
    private let speciesIdentifier: any SpeciesIdentifier

    @State private var notes = ""
    @State private var pendingPhotoData: Data?
    @State private var isSaving = false
    @State private var statusMessage: String?
    @State private var hasCapturedPhoto = false
    @State private var isNotesExpanded = false
    @State private var speciesIdentificationStatus: Observation.SpeciesIdentificationStatus?
    @State private var speciesIdentificationContext: SpeciesIdentificationContext?
    @State private var identifiedTaxonomy: Observation.Taxonomy?
    @State private var speciesCandidates: [SpeciesCandidate] = []
    @State private var speciesIdentifiedAt: Date?
    @State private var speciesPredictionSource: SpeciesPrediction.Source?
    @State private var speciesIdentificationDiagnostics: String?
    @State private var isDebugSectionExpanded = false
    @State private var identificationToken = UUID()
    @FocusState private var isNotesFieldFocused: Bool

#if canImport(UIKit)
    @StateObject private var cameraModel = CameraCaptureModel()
    @State private var showingLibraryPicker = false
    @State private var pinchStartZoomFactor: CGFloat?
    @State private var focusReticlePoint: CGPoint?
    @State private var focusReticleScale: CGFloat = 1.3
    @State private var focusReticleOpacity: Double = 0
    @State private var focusReticleToken = UUID()
#if canImport(CoreLocation)
    @StateObject private var locationProvider = CaptureLocationProvider()
#endif
#endif

    public init(
        observationStore: any ObservationStore,
        mediaStore: any MediaStore,
        speciesIdentifier: any SpeciesIdentifier = PlaceholderSpeciesIdentifier()
    ) {
        self.observationStore = observationStore
        self.mediaStore = mediaStore
        self.speciesIdentifier = speciesIdentifier
    }

    public var body: some View {
#if canImport(UIKit)
        ZStack {
            if let capturedImage = pendingCapturedImage, hasCapturedPhoto {
                Image(uiImage: capturedImage)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .onTapGesture {
                        isNotesFieldFocused = false
                    }
            } else {
                CameraPreviewRepresentable(session: cameraModel.session) { layerPoint, devicePoint in
                    showFocusReticle(at: layerPoint)
                    cameraModel.focus(atDevicePoint: devicePoint)
                }
                .ignoresSafeArea()
                .onTapGesture {
                    isNotesFieldFocused = false
                }
                .simultaneousGesture(
                    MagnificationGesture()
                        .onChanged { value in
                            let start = pinchStartZoomFactor ?? cameraModel.zoomFactor
                            if pinchStartZoomFactor == nil {
                                pinchStartZoomFactor = start
                            }
                            cameraModel.setZoomFactor(start * value)
                        }
                        .onEnded { _ in
                            pinchStartZoomFactor = nil
                        }
                )
                .overlay(alignment: .topLeading) {
                    if let focusReticlePoint {
                        FocusReticle()
                            .scaleEffect(focusReticleScale)
                            .opacity(focusReticleOpacity)
                            .position(x: focusReticlePoint.x, y: focusReticlePoint.y)
                            .allowsHitTesting(false)
                    }
                }
            }

            VStack(spacing: 12) {
                Spacer()

                if hasCapturedPhoto {
                    speciesStatusCard
                } else {
                    zoomControl
                }

                ZStack {
                    if !hasCapturedPhoto {
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            cameraModel.capturePhoto()
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(.white)
                                    .overlay(
                                        Circle()
                                            .stroke(Style.fenGreen.opacity(0.2), lineWidth: 1)
                                    )
                                    .frame(width: Style.shutterSize, height: Style.shutterSize)
                                Image(systemName: "camera.fill")
                                    .font(.system(size: Style.shutterIconSize, weight: .semibold))
                                    .foregroundStyle(Style.fenGreen)
                            }
                        }
                        .disabled(isSaving)
                        .accessibilityIdentifier("capture.takePhotoButton")

                        HStack {
                            Spacer()
                            Button {
                                showingLibraryPicker = true
                            } label: {
                                Image(systemName: "photo")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 44, height: 44)
                                    .background(Color.clear)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.white, lineWidth: 1.5)
                                    )
                            }
                            .disabled(isSaving)
                            .accessibilityIdentifier("capture.openLibraryButton")
                        }
                    }
                }

                if let statusMessage {
                    Text(statusMessage)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.bottom, 6)
                        .accessibilityIdentifier("capture.statusMessage")
                }
            }
            .frame(maxWidth: 430)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, controlsHorizontalPadding)
            .padding(.bottom, controlsBottomPadding)
            .animation(.easeOut(duration: 0.2), value: isNotesFieldFocused)
            .background(Color.black.opacity(0.22).allowsHitTesting(false))

        }
        .navigationTitle("Fen")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            cameraModel.start()
#if canImport(CoreLocation)
            locationProvider.start()
#endif
        }
        .onChange(of: hasCapturedPhoto) { _, isCaptured in
            if isCaptured {
                cameraModel.stop()
            } else {
                cameraModel.start()
            }
        }
        .onDisappear {
            cameraModel.stop()
#if canImport(CoreLocation)
            locationProvider.stop()
#endif
        }
        .onReceive(NotificationCenter.default.publisher(for: .fenCameraDidCapturePhoto)) { notification in
            let data = notification.object as? Data
            handleCapturedData(data)
        }
        .sheet(isPresented: $showingLibraryPicker) {
            MediaCaptureSheet(sourceType: .photoLibrary) { data in
                handleCapturedData(data)
            }
        }
#else
        VStack {
            Text("Camera preview is unavailable on this platform.")
                .foregroundStyle(.secondary)
        }
        .navigationTitle("Fen")
#endif
    }

#if canImport(UIKit)
    private var pendingCapturedImage: UIImage? {
        guard let pendingPhotoData else { return nil }
        return UIImage(data: pendingPhotoData)
    }

    @ViewBuilder
    private var zoomControl: some View {
        let presets = availableZoomPresets
        if !presets.isEmpty {
            HStack(spacing: 10) {
                ForEach(presets, id: \.self) { preset in
                    let isNearest = nearestZoomPreset == preset
                    Button {
                        cameraModel.setZoomFactor(preset)
                    } label: {
                        Text(isNearest ? liveZoomLabel : "\(zoomLabel(for: preset))x")
                            .font(.system(size: 14, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(isNearest ? Style.fenGreen : .white)
                            .frame(minWidth: 44, minHeight: 34)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(isNearest ? .white : Color.white.opacity(0.14))
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("capture.zoom.\(zoomLabel(for: preset))x")
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .fenGlassBackground(cornerRadius: 18)
        }
    }

    private func showFocusReticle(at point: CGPoint) {
        let token = UUID()
        focusReticleToken = token
        focusReticlePoint = point
        focusReticleScale = 1.3
        focusReticleOpacity = 1
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        withAnimation(.spring(response: 0.22, dampingFraction: 0.72)) {
            focusReticleScale = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            guard focusReticleToken == token else { return }
            withAnimation(.easeOut(duration: 0.22)) {
                focusReticleOpacity = 0
            }
        }
    }
#endif

    private func handleCapturedData(_ data: Data?) {
        guard let data, !data.isEmpty else { return }
        isNotesFieldFocused = false
        pendingPhotoData = data
        hasCapturedPhoto = true
        isNotesExpanded = false
        statusMessage = nil
        startSpeciesIdentification(for: data)
    }

    private func saveObservation() {
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let pendingPhotoData, !isSaving else { return }

        isNotesFieldFocused = false
        isSaving = true

        Task {
            do {
                let finalSpeciesStatus: Observation.SpeciesIdentificationStatus =
                    speciesIdentificationStatus == .completed ? .completed : .failed
                let finalTaxonomy = finalSpeciesStatus == .completed ? identifiedTaxonomy : nil
                let finalPredictionSource = speciesPredictionSource
                let finalDiagnostics = speciesIdentificationDiagnostics
                let finalCandidates = speciesCandidates.isEmpty ? nil : speciesCandidates
                let finalIdentifiedAt = speciesIdentifiedAt

                let observation = Observation(
                    notes: trimmedNotes,
                    speciesIdentificationStatus: finalSpeciesStatus,
                    speciesIdentificationContext: speciesIdentificationContext,
                    taxonomy: finalTaxonomy,
                    speciesPredictionSource: finalPredictionSource,
                    speciesPredictionDiagnostics: finalDiagnostics,
                    speciesCandidates: finalCandidates,
                    speciesIdentifiedAt: finalIdentifiedAt
                )
                try await observationStore.save(observation)
                let savedMediaCount = try await saveSelectedMedia(for: observation.id, photoData: pendingPhotoData)

                await MainActor.run {
                    notes = ""
                    self.pendingPhotoData = nil
                    hasCapturedPhoto = false
                    isNotesExpanded = false
                    speciesIdentificationStatus = nil
                    speciesIdentificationContext = nil
                    identifiedTaxonomy = nil
                    speciesCandidates = []
                    speciesIdentifiedAt = nil
                    speciesPredictionSource = nil
                    speciesIdentificationDiagnostics = nil
                    if savedMediaCount > 0 {
                        if finalSpeciesStatus == .completed, let rank = finalTaxonomy?.lowestAvailableRank {
                            statusMessage = "Saved. \(rank.label): \(rank.value)."
                        } else {
                            statusMessage = "Saved as unidentified species."
                        }
                    } else {
                        statusMessage = "Saved at \(Date.now.formatted(date: .omitted, time: .shortened))."
                    }
#if canImport(UIKit)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
#endif
                    isSaving = false
                }
            } catch {
                await MainActor.run {
                    statusMessage = "Save failed: \(error.localizedDescription)"
#if canImport(UIKit)
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
#endif
                    isSaving = false
                }
            }
        }
    }

    private func saveSelectedMedia(for observationID: ObservationID, photoData: Data) async throws -> Int {
        let directory = try Self.mediaDirectoryURL()
        let fileURL = directory.appendingPathComponent("\(UUID().uuidString).jpg", isDirectory: false)
        try photoData.write(to: fileURL, options: .atomic)
        let asset = MediaAsset(observationID: observationID, localURL: fileURL)
        try await mediaStore.save(asset)
        return 1
    }

    private func discardPendingCapture() {
        isNotesFieldFocused = false
        notes = ""
        pendingPhotoData = nil
        hasCapturedPhoto = false
        isNotesExpanded = false
        speciesIdentificationStatus = nil
        speciesIdentificationContext = nil
        identifiedTaxonomy = nil
        speciesCandidates = []
        speciesIdentifiedAt = nil
        speciesPredictionSource = nil
        speciesIdentificationDiagnostics = nil
        isDebugSectionExpanded = false
        identificationToken = UUID()
        statusMessage = "Capture discarded."
    }

    private var saveButtonTitle: String {
        switch speciesIdentificationStatus {
        case .completed:
            return "Save"
        case .pending, .failed, .none:
            return "Save as Unidentified"
        }
    }

    @ViewBuilder
    private var speciesStatusCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch speciesIdentificationStatus {
            case .pending:
                HStack(spacing: 8) {
                    ProgressView()
                        .tint(.white)
                    Text("Identifying species...")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                }
            case .completed:
                if let topCandidate = topSpeciesCandidate, let taxonomy = identifiedTaxonomy {
                    speciesIdentificationLayout(topCandidate: topCandidate, taxonomy: taxonomy)
                } else {
                    Text("Species identification completed.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                }
            case .failed:
                Text("Taxonomic identification is undetermined for this photo.")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Retry Identification") {
                    if let data = pendingPhotoData {
                        startSpeciesIdentification(for: data)
                    }
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white.opacity(0.9))
            case .none:
                Text("Species status unavailable.")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.9))
            }

            if hasDebugDetails {
                DisclosureGroup(
                    isExpanded: $isDebugSectionExpanded,
                    content: {
                        if let diagnostics = speciesIdentificationDiagnostics, !diagnostics.isEmpty {
                            Text(diagnostics)
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.82))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if !topThreeDebugCandidates.isEmpty {
                            Text(topThreeDebugCandidates)
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.82))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    },
                    label: {
                        Text("Debug Details")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                )
            }

            if isNotesExpanded {
                TextEditor(text: $notes)
                    .focused($isNotesFieldFocused)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .foregroundStyle(.white)
                    .accessibilityIdentifier("capture.notesField")
                    .frame(height: 132)
                    .fenGlassBackground(cornerRadius: 16)
            } else {
                Button {
                    isNotesExpanded = true
                    isNotesFieldFocused = true
                } label: {
                    HStack {
                        Image(systemName: "note.text.badge.plus")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Add note (optional)")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .padding(.horizontal, 12)
                    .fenGlassBackground(cornerRadius: 12)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 12) {
                Button {
                    discardPendingCapture()
                } label: {
                    Text("Discard")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: Style.actionHeight)
                        .fenGlassBackground(cornerRadius: 12)
                }
                .buttonStyle(.plain)
                .disabled(isSaving)
                .accessibilityIdentifier("capture.discardButton")

                Button {
                    saveObservation()
                } label: {
                    if isSaving {
                        ProgressView()
                            .tint(Style.fenGreen)
                            .frame(maxWidth: .infinity, minHeight: Style.actionHeight)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(.white)
                            )
                    } else {
                        Text(saveButtonTitle)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Style.fenGreen)
                            .frame(maxWidth: .infinity, minHeight: Style.actionHeight)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(.white)
                            )
                    }
                }
                .buttonStyle(.plain)
                .disabled(isSaving)
                .accessibilityIdentifier("capture.saveButton")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .fenGlassBackground(cornerRadius: 12)
    }

    @ViewBuilder
    private func speciesIdentificationLayout(
        topCandidate: SpeciesCandidate,
        taxonomy: Observation.Taxonomy
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(commonName(for: topCandidate, taxonomy: taxonomy))
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)

                    Text(scientificName(for: topCandidate, taxonomy: taxonomy))
                        .font(.caption)
                        .italic()
                        .foregroundStyle(.white.opacity(0.92))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 1) {
                    Text(confidencePercentText(topCandidate.confidence))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.green)
                    Text("Confidence")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.green.opacity(0.9))
                }
            }

            Text(speciesSourceLabel(speciesPredictionSource ?? .fallback))
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.85))

            if let context = speciesIdentificationContext {
                HStack(alignment: .top, spacing: 8) {
                    CaptureObservationLocationMapView(context: context)
                        .frame(width: 124)
                    CaptureSpeciesPhotoCollageView(photoURLs: topCandidate.photoURLs)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .clipped()
                CaptureObservationLocationTextView(context: context)
            } else {
                CaptureSpeciesPhotoCollageView(photoURLs: topCandidate.photoURLs)
            }
        }
    }

    private func startSpeciesIdentification(for data: Data) {
        let token = UUID()
        identificationToken = token
        speciesIdentificationStatus = .pending
        let observedAt = Date()
        let context = SpeciesIdentificationContext(
            latitude: currentLatitude,
            longitude: currentLongitude,
            observedAt: observedAt
        )
        speciesIdentificationContext = context
        identifiedTaxonomy = nil
        speciesCandidates = []
        speciesIdentifiedAt = nil
        speciesPredictionSource = nil
        speciesIdentificationDiagnostics = "Starting species identification."
        isDebugSectionExpanded = false

        Task {
            do {
                let prediction = try await speciesIdentifier.identifySpecies(
                    in: data,
                    context: context
                )

                await MainActor.run {
                    guard token == identificationToken else { return }
                    guard pendingPhotoData == data, hasCapturedPhoto else { return }
                    speciesPredictionSource = prediction.source
                    let sortedCandidates = prediction.candidates.sorted(by: { $0.confidence > $1.confidence })
                    speciesCandidates = sortedCandidates
                    speciesIdentifiedAt = Date()

                    let gateResult = applyRejectionGate(to: sortedCandidates)
                    if let accepted = gateResult.accepted {
                        speciesIdentificationStatus = .completed
                        identifiedTaxonomy = accepted.taxonomy
                        let topLabel = accepted.label
                        let confidence = accepted.confidence
                        let score = scoreText(confidence)
                        let extraDiagnostics = prediction.diagnostics?
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        if let extraDiagnostics, !extraDiagnostics.isEmpty {
                            speciesIdentificationDiagnostics =
                                "Top: \(topLabel) (score \(score)). \(extraDiagnostics)"
                        } else {
                            speciesIdentificationDiagnostics = "Top: \(topLabel) (score \(score))."
                        }
                    } else {
                        speciesIdentificationStatus = .failed
                        identifiedTaxonomy = nil
                        let extraDiagnostics = prediction.diagnostics?
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        if let extraDiagnostics, !extraDiagnostics.isEmpty {
                            speciesIdentificationDiagnostics = "\(gateResult.reason) \(extraDiagnostics)"
                        } else {
                            speciesIdentificationDiagnostics = gateResult.reason
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    guard token == identificationToken else { return }
                    guard pendingPhotoData == data, hasCapturedPhoto else { return }
                    speciesPredictionSource = nil
                    speciesIdentificationStatus = .failed
                    identifiedTaxonomy = nil
                    speciesCandidates = []
                    speciesIdentifiedAt = nil
                    speciesIdentificationDiagnostics = error.localizedDescription
                }
            }
        }
    }

    private func applyRejectionGate(to sortedCandidates: [SpeciesCandidate]) -> (accepted: SpeciesCandidate?, reason: String) {
        guard let top = sortedCandidates.first else {
            return (nil, "Undetermined: no candidates returned.")
        }

        let thresholds = rejectionThresholds(for: top)

        if top.confidence < thresholds.minimumTopScore {
            return (
                nil,
                "Undetermined: top score \(scoreText(top.confidence)) is below \(thresholds.profileName) threshold \(scoreText(thresholds.minimumTopScore))."
            )
        }

        if sortedCandidates.count > 1 {
            let second = sortedCandidates[1]
            let margin = top.confidence - second.confidence
            if top.confidence < RejectionGate.highConfidenceBypassTopScore,
               margin < thresholds.minimumMargin {
                return (
                    nil,
                    "Undetermined: top-vs-second margin \(scoreText(margin)) is below \(thresholds.profileName) threshold \(scoreText(thresholds.minimumMargin))."
                )
            }
        }

        guard top.taxonomy.lowestAvailableRank != nil else {
            return (nil, "Undetermined: top candidate has no taxonomy.")
        }

        return (top, "Accepted by gate.")
    }

    private func rejectionThresholds(for candidate: SpeciesCandidate) -> RejectionGate.Thresholds {
        let kingdom = candidate.taxonomy.kingdom?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if kingdom == "plantae" {
            return RejectionGate.plant
        }
        return RejectionGate.general
    }

    private func speciesSourceLabel(_ source: SpeciesPrediction.Source) -> String {
        switch source {
        case .cloud:
            return "Cloud (iNaturalist)"
        case .onDevice:
            return "On-device model"
        case .fallback:
            return "Fallback"
        }
    }

    private var topSpeciesCandidate: SpeciesCandidate? {
        speciesCandidates.max(by: { $0.confidence < $1.confidence })
    }

    private var hasDebugDetails: Bool {
        let hasDiagnostics = !(speciesIdentificationDiagnostics?.isEmpty ?? true)
        let hasCandidates = !speciesCandidates.isEmpty
        return hasDiagnostics || hasCandidates
    }

    private var topThreeDebugCandidates: String {
        let topThree = speciesCandidates.prefix(3)
        guard !topThree.isEmpty else { return "" }

        let rows = topThree.enumerated().map { index, candidate in
            let scientific = scientificName(for: candidate, taxonomy: candidate.taxonomy)
            return "\(index + 1). \(candidate.label) \(confidencePercentText(candidate.confidence)) [\(scientific)]"
        }

        return "Top 3 IDs:\n" + rows.joined(separator: "\n")
    }

    private func scoreText(_ confidence: Double) -> String {
        String(format: "%.2f", confidence)
    }

    private func confidencePercentText(_ confidence: Double) -> String {
        String(format: "%.1f%%", max(0, min(confidence, 1)) * 100)
    }

    private func commonName(for candidate: SpeciesCandidate, taxonomy: Observation.Taxonomy) -> String {
        let scientific = scientificName(for: candidate, taxonomy: taxonomy).lowercased()
        if candidate.label.lowercased() == scientific {
            return "Unlabeled taxon"
        }
        return candidate.label
    }

    private func scientificName(for candidate: SpeciesCandidate, taxonomy: Observation.Taxonomy) -> String {
        taxonomy.species
            ?? taxonomy.genus
            ?? taxonomy.family
            ?? taxonomy.order
            ?? taxonomy.className
            ?? taxonomy.phylum
            ?? taxonomy.kingdom
            ?? taxonomy.domain
            ?? candidate.label
    }

    private var currentLatitude: Double? {
#if canImport(UIKit) && canImport(CoreLocation)
        return locationProvider.latestCoordinate?.latitude
#else
        return nil
#endif
    }

    private var currentLongitude: Double? {
#if canImport(UIKit) && canImport(CoreLocation)
        return locationProvider.latestCoordinate?.longitude
#else
        return nil
#endif
    }

    private var controlsBottomPadding: CGFloat {
        isNotesFieldFocused ? 56 : 22
    }

    private var controlsHorizontalPadding: CGFloat {
        isNotesFieldFocused ? 20 : 26
    }

    #if canImport(UIKit)
    private var availableZoomPresets: [CGFloat] {
        let supported = [CGFloat(1), CGFloat(2), CGFloat(5)]
        return supported.filter {
            $0 >= cameraModel.minZoomFactor - 0.01 && $0 <= cameraModel.maxZoomFactor + 0.01
        }
    }

    private var liveZoomLabel: String {
        let rounded = (cameraModel.zoomFactor * 10).rounded() / 10
        if rounded.rounded(.toNearestOrAwayFromZero) == rounded {
            return "\(Int(rounded))x"
        }
        return String(format: "%.1fx", rounded)
    }

    private var nearestZoomPreset: CGFloat? {
        availableZoomPresets.min(by: { abs($0 - cameraModel.zoomFactor) < abs($1 - cameraModel.zoomFactor) })
    }

    private func zoomLabel(for value: CGFloat) -> String {
        value.rounded(.toNearestOrAwayFromZero) == value
            ? String(Int(value))
            : String(format: "%.1f", value)
    }
    #endif

    private static func mediaDirectoryURL() throws -> URL {
        let manager = FileManager.default
        let baseDirectory = manager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? manager.temporaryDirectory
        let mediaDirectory = baseDirectory
            .appendingPathComponent("Fen", isDirectory: true)
            .appendingPathComponent("Media", isDirectory: true)
        try manager.createDirectory(at: mediaDirectory, withIntermediateDirectories: true)
        return mediaDirectory
    }
}

#if canImport(UIKit) && canImport(CoreLocation)
@MainActor
private final class CaptureLocationProvider: NSObject, ObservableObject, @preconcurrency CLLocationManagerDelegate {
    @Published private(set) var latestCoordinate: CLLocationCoordinate2D?

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func start() {
        guard CLLocationManager.locationServicesEnabled() else { return }

        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .restricted, .denied:
            break
        @unknown default:
            break
        }
    }

    func stop() {
        manager.stopUpdatingLocation()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        latestCoordinate = locations.last?.coordinate
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    }
}
#endif

private struct FenGlassBackgroundModifier: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(iOS 26.0, macOS 26.0, tvOS 26.0, watchOS 26.0, visionOS 26.0, *) {
            content
                .glassEffect(in: .rect(cornerRadius: cornerRadius))
                .clipShape(shape)
        } else {
            content
                .background(
                    shape
                        .fill(.ultraThinMaterial)
                        .overlay(
                            shape
                                .fill(Color.white.opacity(0.18))
                        )
                        .overlay(
                            shape
                                .stroke(Color.white.opacity(0.32), lineWidth: 1)
                        )
                )
                .clipShape(shape)
        }
    }
}

private extension View {
    func fenGlassBackground(cornerRadius: CGFloat) -> some View {
        modifier(FenGlassBackgroundModifier(cornerRadius: cornerRadius))
    }
}

#if canImport(MapKit) && canImport(CoreLocation)
private struct CaptureSpeciesPhotoCollageView: View {
    let photoURLs: [URL]

    private let spacing: CGFloat = 8
    private let smallTileSize: CGFloat = 34
    private var height: CGFloat { (smallTileSize * 3) + (spacing * 2) }

    var body: some View {
        GeometryReader { proxy in
            let availableWidth = max(proxy.size.width, 0)
            let derivedMainWidth = availableWidth - spacing - smallTileSize
            let mainWidth = min(160, max(96, derivedMainWidth))

            HStack(spacing: spacing) {
                CaptureSpeciesPhotoTile(url: photoURL(at: 0))
                    .frame(width: mainWidth, height: height)

                VStack(spacing: spacing) {
                    CaptureSpeciesPhotoTile(url: photoURL(at: 1))
                        .frame(width: smallTileSize, height: smallTileSize)
                    CaptureSpeciesPhotoTile(url: photoURL(at: 2))
                        .frame(width: smallTileSize, height: smallTileSize)
                    CaptureSpeciesPhotoTile(url: photoURL(at: 3))
                        .frame(width: smallTileSize, height: smallTileSize)
                }
                .frame(width: smallTileSize, height: height)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: height)
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipped()
    }

    private func photoURL(at index: Int) -> URL? {
        guard index >= 0, index < photoURLs.count else { return nil }
        return photoURLs[index]
    }
}

private struct CaptureSpeciesPhotoTile: View {
    let url: URL?
    private let cornerRadius: CGFloat = 10

    var body: some View {
        GeometryReader { proxy in
            let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

            ZStack {
                shape
                    .fill(Color.white.opacity(0.10))

                if let url {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case let .success(image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: proxy.size.width, height: proxy.size.height)
                                .clipShape(shape)
                        case .failure:
                            Image(systemName: "photo")
                                .foregroundStyle(.white.opacity(0.65))
                        case .empty:
                            ProgressView()
                                .tint(.white)
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    Image(systemName: "photo")
                        .foregroundStyle(.white.opacity(0.65))
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipShape(shape)
        }
        .clipped()
    }
}

private struct CaptureObservationLocationMapView: View {
    let context: SpeciesIdentificationContext

    private var coordinate: CLLocationCoordinate2D? {
        guard let latitude = context.latitude, let longitude = context.longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var body: some View {
        if let coordinate {
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
                .frame(height: 132)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.12))
                    .overlay {
                        Text(String(format: "%.5f, %.5f", coordinate.latitude, coordinate.longitude))
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .frame(height: 132)
            }
        } else {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.10))
                .overlay {
                    Image(systemName: "map")
                        .foregroundStyle(.white.opacity(0.65))
                }
                .frame(height: 132)
        }
    }
}

private struct CaptureObservationLocationTextView: View {
    let context: SpeciesIdentificationContext
    @State private var addressLine = "Resolving address..."

    private var hasCoordinate: Bool {
        context.latitude != nil && context.longitude != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Observed in")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.85))

            Text(addressText)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.92))

            Text(observedAtText)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.78))
        }
        .task(id: locationKey) {
            await resolveAddress()
        }
    }

    private var locationKey: String {
        "\(context.latitude ?? 0),\(context.longitude ?? 0)"
    }

    private var addressText: String {
        if !hasCoordinate {
            return "Location unavailable"
        }
        return addressLine
    }

    private var observedAtText: String {
        guard let observedAt = context.observedAt else {
            return "Date/time unavailable"
        }
        return observedAt.formatted(date: .abbreviated, time: .complete)
    }

    private func resolveAddress() async {
        guard let latitude = context.latitude, let longitude = context.longitude else {
            addressLine = "Location unavailable"
            return
        }

        let location = CLLocation(latitude: latitude, longitude: longitude)
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
                    addressLine = String(format: "%.5f, %.5f", latitude, longitude)
                } else {
                    addressLine = parts.joined(separator: ", ")
                }
            } else {
                addressLine = String(format: "%.5f, %.5f", latitude, longitude)
            }
        } catch {
            addressLine = String(format: "%.5f, %.5f", latitude, longitude)
        }
    }
}
#endif

#if canImport(UIKit)
private final class CameraCaptureModel: NSObject, ObservableObject {
    let session = AVCaptureSession()
    @Published private(set) var minZoomFactor: CGFloat = 1
    @Published private(set) var zoomFactor: CGFloat = 1
    @Published private(set) var maxZoomFactor: CGFloat = 1

    private let sessionQueue = DispatchQueue(label: "Fen.CameraSessionQueue")
    private let photoOutput = AVCapturePhotoOutput()
    private var captureDevice: AVCaptureDevice?
    private var configured = false

    func start() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.configureIfNeeded()
            guard self.configured, !self.session.isRunning else { return }
            self.session.startRunning()
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    func capturePhoto() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard self.configured else { return }
            let settings = AVCapturePhotoSettings()
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    func setZoomFactor(_ value: CGFloat) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard self.configured, let device = self.captureDevice else { return }
            let target = max(self.minSupportedZoomFactor(for: device), min(value, self.maxSupportedZoomFactor(for: device)))
            guard abs(target - self.zoomFactor) > 0.001 else { return }
            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = target
                device.unlockForConfiguration()
                self.zoomFactor = target
            } catch {
                return
            }
        }
    }

    func focus(atDevicePoint point: CGPoint) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard self.configured, let device = self.captureDevice else { return }

            do {
                try device.lockForConfiguration()

                if device.isFocusPointOfInterestSupported {
                    device.focusPointOfInterest = point
                }
                if device.isFocusModeSupported(.continuousAutoFocus) {
                    device.focusMode = .continuousAutoFocus
                } else if device.isFocusModeSupported(.autoFocus) {
                    device.focusMode = .autoFocus
                }

                if device.isExposurePointOfInterestSupported {
                    device.exposurePointOfInterest = point
                }
                if device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposureMode = .continuousAutoExposure
                } else if device.isExposureModeSupported(.autoExpose) {
                    device.exposureMode = .autoExpose
                }

                device.isSubjectAreaChangeMonitoringEnabled = true
                device.unlockForConfiguration()
            } catch {
                return
            }
        }
    }

    private func configureIfNeeded() {
        guard !configured else { return }
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else { return }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            break
        case .notDetermined:
            let semaphore = DispatchSemaphore(value: 0)
            AVCaptureDevice.requestAccess(for: .video) { _ in
                semaphore.signal()
            }
            semaphore.wait()
            guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else { return }
        default:
            return
        }

        guard let device = Self.preferredBackCamera(),
              let input = try? AVCaptureDeviceInput(device: device) else { return }
        captureDevice = device

        session.beginConfiguration()
        session.sessionPreset = .photo

        if session.canAddInput(input) {
            session.addInput(input)
        }

        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }

        session.commitConfiguration()
        let minZoom = minSupportedZoomFactor(for: device)
        let maxZoom = maxSupportedZoomFactor(for: device)
        minZoomFactor = minZoom
        maxZoomFactor = maxZoom
        zoomFactor = max(1, minZoom)
        configured = true
    }

    private func minSupportedZoomFactor(for device: AVCaptureDevice) -> CGFloat {
        max(0.5, device.minAvailableVideoZoomFactor)
    }

    private func maxSupportedZoomFactor(for device: AVCaptureDevice) -> CGFloat {
        max(1, min(device.activeFormat.videoMaxZoomFactor, 6))
    }

    private static func preferredBackCamera() -> AVCaptureDevice? {
        let preferredTypes: [AVCaptureDevice.DeviceType] = [
            .builtInTripleCamera,
            .builtInDualWideCamera,
            .builtInDualCamera,
            .builtInWideAngleCamera
        ]
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: preferredTypes,
            mediaType: .video,
            position: .back
        )
        return discovery.devices.first
    }
}

extension CameraCaptureModel: AVCapturePhotoCaptureDelegate {
    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        guard error == nil, let data = photo.fileDataRepresentation() else { return }
        NotificationCenter.default.post(name: .fenCameraDidCapturePhoto, object: data)
    }
}

private struct CameraPreviewRepresentable: UIViewRepresentable {
    let session: AVCaptureSession
    let onTapToFocus: (CGPoint, CGPoint) -> Void

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.videoGravity = .resizeAspectFill
        view.previewLayer.session = session
        view.onTap = { [weak view] layerPoint in
            guard let view else { return }
            let devicePoint = view.previewLayer.captureDevicePointConverted(fromLayerPoint: layerPoint)
            onTapToFocus(layerPoint, devicePoint)
        }
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.previewLayer.session = session
    }
}

private final class PreviewView: UIView {
    var onTap: ((CGPoint) -> Void)?

    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        addGestureRecognizer(tapRecognizer)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        addGestureRecognizer(tapRecognizer)
    }

    @objc
    private func handleTap(_ recognizer: UITapGestureRecognizer) {
        onTap?(recognizer.location(in: self))
    }
}

private struct FocusReticle: View {
    private let size: CGFloat = 72

    var body: some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .stroke(Color.yellow.opacity(0.92), lineWidth: 2)
            .frame(width: size, height: size)
    }
}

private struct MediaCaptureSheet: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    let onCapture: (Data?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        if sourceType == .camera, UIImagePickerController.isSourceTypeAvailable(.camera) {
            picker.sourceType = .camera
            picker.cameraCaptureMode = .photo
        } else {
            picker.sourceType = .photoLibrary
        }
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (Data?) -> Void

        init(onCapture: @escaping (Data?) -> Void) {
            self.onCapture = onCapture
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
            onCapture(nil)
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            let image = info[.originalImage] as? UIImage
            let data = image?.jpegData(compressionQuality: 0.9)
            picker.dismiss(animated: true)
            onCapture(data)
        }
    }
}
#endif
