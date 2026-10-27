//
//  UpdaterViewModel.swift
//  FetchFlow
//
//  Manages Sparkle 2 automatic updates and user-initiated checks.
//

import SwiftUI
import Combine
import Sparkle

@MainActor
final class UpdaterViewModel: NSObject, ObservableObject {
    static let shared = UpdaterViewModel()

    @Published var canCheckForUpdates: Bool = false
    @Published var automaticallyChecksForUpdates: Bool = true {
        didSet {
            updaterController.updater.automaticallyChecksForUpdates = automaticallyChecksForUpdates
        }
    }

    private let updaterController: SPUStandardUpdaterController

    private override init() {
        // Initialize Sparkle 2 standard updater controller programmatically
        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)

        super.init()

        self.automaticallyChecksForUpdates = updaterController.updater.automaticallyChecksForUpdates

        // Observe canCheckForUpdates via KVO publisher
        updaterController.updater.publisher(for: \.canCheckForUpdates)
            .receive(on: RunLoop.main)
            .assign(to: &$canCheckForUpdates)
    }

    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }
}
