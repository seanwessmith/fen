import SwiftUI
import HeronDataStore
import HeronDesignSystem
import HeronModels
import HeronSwiftUIComponents

public struct JournalView: View {
    private let observationStore: any ObservationStore
    @State private var observations: [Observation] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    public init(observationStore: any ObservationStore) {
        self.observationStore = observationStore
    }

    public var body: some View {
        Group {
            if isLoading && observations.isEmpty {
                ProgressView("Loading Journal...")
            } else if observations.isEmpty {
                VStack(spacing: CGFloat(HeronDesignTokens.spacingSmall)) {
                    Text("No observations yet.")
                    Text("Save one from the Capture tab.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    HeronPlaceholderCard()
                }
                .padding(CGFloat(HeronDesignTokens.spacingLarge))
            } else {
                List(observations, id: \.id) { observation in
                    NavigationLink {
                        ObservationDetailView(
                            observation: observation,
                            observationStore: observationStore,
                            onSave: { updated in
                                upsert(updated)
                            }
                        )
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(observation.notes.isEmpty ? "Untitled observation" : observation.notes)
                                .lineLimit(2)
                            Text(observation.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
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
            await MainActor.run {
                observations = result
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
}

private struct ObservationDetailView: View {
    let observation: Observation
    let observationStore: any ObservationStore
    let onSave: (Observation) -> Void

    @State private var notes: String
    @State private var isSaving = false
    @State private var statusMessage: String?

    init(
        observation: Observation,
        observationStore: any ObservationStore,
        onSave: @escaping (Observation) -> Void
    ) {
        self.observation = observation
        self.observationStore = observationStore
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
                    consentProfileID: observation.consentProfileID
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
