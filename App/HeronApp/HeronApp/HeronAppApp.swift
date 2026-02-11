//
//  HeronAppApp.swift
//  HeronApp
//
//  Created by Sean Smith on 1/22/26.
//

import Foundation
import SwiftUI
import HeronDataStore

@main
struct HeronAppApp: App {
    private let observationStore: FileObservationStore

    init() {
        let arguments = ProcessInfo.processInfo.arguments

        if arguments.contains("-reset-onboarding") {
            UserDefaults.standard.removeObject(forKey: "hasOnboarded")
        }

        if arguments.contains("-ui-testing") {
            let uiTestDirectory = FileManager.default.temporaryDirectory
                .appendingPathComponent("HeronUITestStore", isDirectory: true)

            if arguments.contains("-reset-observations") {
                try? FileManager.default.removeItem(at: uiTestDirectory)
            }

            observationStore = FileObservationStore(directory: uiTestDirectory)
        } else {
            observationStore = FileObservationStore()
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView(observationStore: observationStore)
        }
    }
}
