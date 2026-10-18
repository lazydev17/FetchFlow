//
//  SettingsView.swift
//  TorrentClient
//
//  Root settings view with NavigationSplitView sidebar + detail,
//  back/forward toolbar navigation, and liquid glass styling.
//

import AppKit
import SwiftUI

// MARK: - Tab Enum

enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case bandwidth
    case network
    case about

    var id: Self { self }

    var title: String {
        switch self {
        case .general: "General"
        case .bandwidth: "Bandwidth"
        case .network: "Network"
        case .about: "About"
        }
    }

    var systemImage: String {
        switch self {
        case .general: "gearshape"
        case .bandwidth: "gauge.with.dots.needle.33percent"
        case .network: "network"
        case .about: "info.circle"
        }
    }
}

// MARK: - Navigation State

@MainActor
@Observable
final class SettingsNavigation {
    static let shared = SettingsNavigation()
    var selectedTab: SettingsTab? = .general
    private init() {}
}

// MARK: - Main Settings View

struct SettingsView: View {
    @State private var navigation = SettingsNavigation.shared
    @State private var navigationHistory: [SettingsTab] = [.general]
    @State private var historyIndex = 0
    @State private var isHistoryNavigation = false

    private var activeTab: SettingsTab {
        navigation.selectedTab ?? .general
    }

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            SettingsSidebarView(selectedTab: $navigation.selectedTab)
                .frame(width: 190)
                .navigationSplitViewColumnWidth(min: 180, ideal: 190, max: 210)
                .toolbar(removing: .sidebarToggle)
        } detail: {
            SettingsDetailView(tab: activeTab)
        }
        .navigationTitle("Settings")
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 640, minHeight: 460)
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button {
                    goBack()
                } label: {
                    Image(systemName: "chevron.left")
                }
                .disabled(!canGoBack)
                .help("Back")

                Button {
                    goForward()
                } label: {
                    Image(systemName: "chevron.right")
                }
                .disabled(!canGoForward)
                .help("Forward")
            }
        }
        .onChange(of: navigation.selectedTab) { _, _ in
            recordNavigation()
        }
    }

    private var canGoBack: Bool { historyIndex > 0 }
    private var canGoForward: Bool { historyIndex < navigationHistory.count - 1 }

    private func goBack() {
        guard canGoBack else { return }
        isHistoryNavigation = true
        historyIndex -= 1
        navigation.selectedTab = navigationHistory[historyIndex]
        DispatchQueue.main.async { isHistoryNavigation = false }
    }

    private func goForward() {
        guard canGoForward else { return }
        isHistoryNavigation = true
        historyIndex += 1
        navigation.selectedTab = navigationHistory[historyIndex]
        DispatchQueue.main.async { isHistoryNavigation = false }
    }

    private func recordNavigation() {
        guard !isHistoryNavigation else { return }
        guard let tab = navigation.selectedTab else { return }
        if navigationHistory.last == tab { return }
        if historyIndex < navigationHistory.count - 1 {
            navigationHistory = Array(navigationHistory.prefix(historyIndex + 1))
        }
        navigationHistory.append(tab)
        historyIndex = navigationHistory.count - 1
    }
}

// MARK: - Sidebar

private struct SettingsSidebarView: View {
    @Binding var selectedTab: SettingsTab?

    var body: some View {
        List(selection: $selectedTab) {
            ForEach(SettingsTab.allCases) { tab in
                Label {
                    Text(tab.title)
                } icon: {
                    Image(systemName: tab.systemImage)
                }
                .tag(tab)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Settings")
    }
}

// MARK: - Detail Router

private struct SettingsDetailView: View {
    let tab: SettingsTab

    var body: some View {
        Group {
            switch tab {
            case .general:
                GeneralSettingsPane()
            case .bandwidth:
                BandwidthSettingsPane()
            case .network:
                NetworkSettingsPane()
            case .about:
                AboutSettingsPane()
            }
        }
        .navigationTitle(tab.title)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - General Settings Pane

struct GeneralSettingsPane: View {
    @AppStorage("customSavePath") private var customSavePath = ""
    @AppStorage("autoStartDownloads") private var autoStartDownloads = true
    @AppStorage("notifyOnCompletion") private var notifyOnCompletion = true

    private var defaultDownloadPath: String {
        FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first?.path
            ?? "~/Downloads"
    }

    var body: some View {
        Form {
            Section("Download Directory") {
                LabeledContent("Save files to") {
                    HStack(spacing: 8) {
                        Image(systemName: "folder.fill")
                            .foregroundStyle(.blue)

                        Text(customSavePath.isEmpty ? defaultDownloadPath : customSavePath)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }

                HStack(spacing: 8) {
                    Button("Choose Folder...") {
                        chooseFolder()
                    }
                    .controlSize(.small)

                    Button("Use Default") {
                        customSavePath = ""
                    }
                    .controlSize(.small)
                    .disabled(customSavePath.isEmpty)
                }
            }

            Section("Behavior") {
                Toggle(isOn: $autoStartDownloads) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Auto-start downloads")
                        Text("Immediately begin transferring pieces after metadata is fetched.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)

                Toggle(isOn: $notifyOnCompletion) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Notify when download completes")
                        Text("Deliver a system notification when all pieces have finished downloading.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)
            }

            Section("Software Updates") {
                Toggle(isOn: Binding(
                    get: { UpdaterViewModel.shared.automaticallyChecksForUpdates },
                    set: { UpdaterViewModel.shared.automaticallyChecksForUpdates = $0 }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Automatically check for updates")
                        Text("Periodically checks for new releases in the background.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)

                HStack {
                    Text("Installed Version")
                    Spacer()
                    Text("1.0 (Build 1)")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                    Button("Check Now…") {
                        UpdaterViewModel.shared.checkForUpdates()
                    }
                    .controlSize(.small)
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .contentMargins(.top, 8, for: .scrollContent)
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.title = "Select Default Download Folder"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            customSavePath = url.path
        }
    }
}

// MARK: - Bandwidth Settings Pane

struct BandwidthSettingsPane: View {
    @AppStorage("limitDownloadRate") private var limitDownloadRate = false
    @AppStorage("maxDownloadRateKB") private var maxDownloadRateKB = 5000
    @AppStorage("limitUploadRate") private var limitUploadRate = false
    @AppStorage("maxUploadRateKB") private var maxUploadRateKB = 1000
    @AppStorage("maxActiveTorrents") private var maxActiveTorrents = 5

    var body: some View {
        Form {
            Section("Download Bandwidth") {
                Toggle("Limit Download Speed", isOn: $limitDownloadRate)
                    .toggleStyle(.switch)

                if limitDownloadRate {
                    LabeledContent("Maximum Rate") {
                        HStack(spacing: 8) {
                            Slider(value: Binding(
                                get: { Double(maxDownloadRateKB) },
                                set: { maxDownloadRateKB = Int($0) }
                            ), in: 500...50000, step: 500)
                            .frame(width: 140)

                            Text("\(maxDownloadRateKB) KB/s")
                                .monospacedDigit()
                                .frame(width: 80, alignment: .trailing)
                        }
                    }
                }
            }

            Section("Upload Bandwidth") {
                Toggle("Limit Upload Speed", isOn: $limitUploadRate)
                    .toggleStyle(.switch)

                if limitUploadRate {
                    LabeledContent("Maximum Rate") {
                        HStack(spacing: 8) {
                            Slider(value: Binding(
                                get: { Double(maxUploadRateKB) },
                                set: { maxUploadRateKB = Int($0) }
                            ), in: 100...20000, step: 100)
                            .frame(width: 140)

                            Text("\(maxUploadRateKB) KB/s")
                                .monospacedDigit()
                                .frame(width: 80, alignment: .trailing)
                        }
                    }
                }
            }

            Section("Queue Limits") {
                Stepper(value: $maxActiveTorrents, in: 1...20) {
                    LabeledContent("Max Active Downloads", value: "\(maxActiveTorrents)")
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .contentMargins(.top, 8, for: .scrollContent)
    }
}

// MARK: - Network Settings Pane

struct NetworkSettingsPane: View {
    @AppStorage("enableDHT") private var enableDHT = true
    @AppStorage("enableLSD") private var enableLSD = true
    @AppStorage("enableUPnP") private var enableUPnP = true
    @AppStorage("randomPort") private var randomPort = true
    @AppStorage("customPort") private var customPort = 6881

    var body: some View {
        Form {
            Section("Peer Discovery") {
                Toggle(isOn: $enableDHT) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Enable DHT (Distributed Hash Table)")
                        Text("Find peers without relying strictly on central trackers.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)

                Toggle(isOn: $enableLSD) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Enable LSD (Local Service Discovery)")
                        Text("Discover high-speed peers on your local network.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)

                Toggle(isOn: $enableUPnP) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Enable UPnP / NAT-PMP")
                        Text("Automatically configure port forwarding on supporting routers.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)
            }

            Section("Listening Port") {
                Toggle("Use Random Port", isOn: $randomPort)
                    .toggleStyle(.switch)

                if !randomPort {
                    LabeledContent("Custom Port") {
                        TextField("Port", value: $customPort, format: .number)
                            .frame(width: 80)
                            .textFieldStyle(.roundedBorder)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .contentMargins(.top, 8, for: .scrollContent)
    }
}

// MARK: - About Settings Pane

struct AboutSettingsPane: View {
    var body: some View {
        Form {
            Section {
                HStack(spacing: 16) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(Color.accentColor)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("TorrentClient")
                            .font(.title2.bold())

                        Text("Version 1.0 (FetchFlow Engine)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text("A native macOS BitTorrent client designed for simplicity, performance, and security.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 2)
                    }
                }
                .padding(.vertical, 6)
            }

            Section("Components") {
                LabeledContent("BitTorrent Engine", value: "libtorrent-rasterbar 2.0.11")
                LabeledContent("Cryptography & SSL", value: "OpenSSL 3.1.2")
                LabeledContent("Core Frameworks", value: "Boost 1.89.0")
                LabeledContent("Software Updates", value: "Sparkle 2 (Ed25519 Signed)")
                LabeledContent("User Interface", value: "SwiftUI + AppKit (macOS 15+)")
            }

            Section("Links") {
                Link(destination: URL(string: "https://github.com/satya-sanjay2110/TorrentClient")!) {
                    HStack {
                        Text("GitHub Repository")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .contentMargins(.top, 8, for: .scrollContent)
    }
}
