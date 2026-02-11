//
//  RootView.swift
//  HeronApp
//
//  Created by Sean Smith on 1/22/26.
//

import SwiftUI
import HeronFeatureCapture
import HeronFeatureJournal
import HeronFeatureNearby
import HeronFeatureOnboarding
import HeronFeatureSettings
import HeronFeatureTrends

struct RootView: View {
    @AppStorage("hasOnboarded") private var hasOnboarded = false

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
                CaptureView()
            }
            .tabItem {
                Label("Capture", systemImage: "camera")
            }

            NavigationStack {
                JournalView()
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
