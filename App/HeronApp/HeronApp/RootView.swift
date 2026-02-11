//
//  RootView.swift
//  HeronApp
//
//  Created by Sean Smith on 1/22/26.
//

import SwiftUI
import HeronDataStore
import HeronFeatureCapture
import HeronFeatureJournal
import HeronFeatureNearby
import HeronFeatureOnboarding
import HeronFeatureSettings
import HeronFeatureTrends

struct RootView: View {
    private let observationStore: any ObservationStore
    @AppStorage("hasOnboarded") private var hasOnboarded = false

    init(observationStore: any ObservationStore = FileObservationStore()) {
        self.observationStore = observationStore
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

    var body: some View {
        TabView {
            NavigationStack {
                CaptureView(observationStore: observationStore)
            }
            .tabItem {
                Label("Capture", systemImage: "camera")
            }

            NavigationStack {
                JournalView(observationStore: observationStore)
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
