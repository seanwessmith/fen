import SwiftUI
import FenDataStore
import FenMedia
import FenModels
import FenSync
import FenSwiftUIComponents

public struct CaptureView: View {
    private let observationStore: any ObservationStore
    @State private var notes = ""
    @State private var isSaving = false
    @State private var statusMessage: String?

    public init(observationStore: any ObservationStore) {
        self.observationStore = observationStore
    }

    public var body: some View {
        Form {
            Section("New Observation") {
                TextField("What did you see?", text: $notes, axis: .vertical)
                    .lineLimit(3...8)
                    .accessibilityIdentifier("capture.notesField")

                Button {
                    saveObservation()
                } label: {
                    if isSaving {
                        ProgressView()
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        Text("Save Observation")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .disabled(isSaving || notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("capture.saveButton")
            }

            if let statusMessage {
                Section("Status") {
                    Text(statusMessage)
                        .accessibilityIdentifier("capture.statusMessage")
                }
            }

            Section("Next") {
                Text("Open the Journal tab to view and edit saved observations.")
                    .font(.footnote)
            }
        }
        .navigationTitle("Capture")
        .overlay(alignment: .bottom) {
            FenPlaceholderCard()
                .padding()
        }
    }

    private func saveObservation() {
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedNotes.isEmpty else { return }

        isSaving = true

        Task {
            do {
                let observation = Observation(notes: trimmedNotes)
                try await observationStore.save(observation)

                await MainActor.run {
                    notes = ""
                    statusMessage = "Saved at \(Date.now.formatted(date: .omitted, time: .shortened))."
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
