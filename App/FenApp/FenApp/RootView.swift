//
//  RootView.swift
//  FenApp
//
//  Created by Sean Smith on 1/22/26.
//

import SwiftUI
import FenDataStore
import FenFeatureCapture
import FenFeatureJournal
import FenFeatureNearby
import FenFeatureOnboarding
import FenFeatureSettings
import FenFeatureTrends
import FenMedia

struct RootView: View {
    private let observationStore: any ObservationStore
    private let mediaStore: any MediaStore
    @AppStorage("hasOnboarded") private var hasOnboarded = false

    init(
        observationStore: any ObservationStore = FileObservationStore(),
        mediaStore: any MediaStore = FileMediaStore()
    ) {
        self.observationStore = observationStore
        self.mediaStore = mediaStore
    }

    private var showOnboarding: Binding<Bool> {
        Binding(
            get: { !hasOnboarded },
            set: { newValue in
                if newValue == false {
                    hasOnboarded = true
                }
            }
        )
    }

    private var captureSpeciesIdentifier: FallbackSpeciesIdentifier {
        let environment = ProcessInfo.processInfo.environment
        let configuredToken = environment["INATURALIST_API_TOKEN"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let configuredBaseURL = environment["INATURALIST_API_BASE_URL"].flatMap(URL.init(string:))
            ?? URL(string: "https://api.inaturalist.org")!

        return FallbackSpeciesIdentifier(
            primary: INaturalistSpeciesIdentifier(
                baseURL: configuredBaseURL,
                apiToken: configuredToken
            ),
            fallback: PlaceholderSpeciesIdentifier()
        )
    }

    var body: some View {
        TabView {
            NavigationStack {
                CaptureView(
                    observationStore: observationStore,
                    mediaStore: mediaStore,
                    speciesIdentifier: captureSpeciesIdentifier
                )
            }
            .tabItem {
                Label("Capture", systemImage: "camera")
            }

            NavigationStack {
                JournalView(observationStore: observationStore, mediaStore: mediaStore)
            }
            .tabItem {
                Label("Journal", systemImage: "book")
            }

            NavigationStack {
                NearbyView()
            }
            .tabItem {
                Label("Nearby", systemImage: "location")
            }

            NavigationStack {
                TrendsView()
            }
            .tabItem {
                Label("Trends", systemImage: "chart.line.uptrend.xyaxis")
            }

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }

#if DEBUG
            NavigationStack {
                CaptureImageClipTestView()
            }
            .tabItem {
                Label("Clip Test", systemImage: "crop")
            }
#endif
        }
        .fullScreenCover(isPresented: showOnboarding) {
            OnboardingContainer(isPresented: showOnboarding)
        }
    }
}

private struct OnboardingContainer: View {
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            OnboardingView()
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Continue") {
                            isPresented = false
                        }
                    }
                }
        }
    }
}

#Preview {
    RootView()
}
