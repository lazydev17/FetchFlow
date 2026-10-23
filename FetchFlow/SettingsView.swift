//
//  SettingsView.swift
//  FetchFlow
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
        VStack(alignment: .leading, spacing: 0) {
            Text("Settings")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 6)

            VStack(spacing: 3) {
                ForEach(SettingsTab.allCases) { tab in
                    SettingsSidebarRow(
                        tab: tab,
                        isSelected: selectedTab == tab
                    ) {
                        withAnimation(.easeInOut(duration: 0.12)) {
                            selectedTab = tab
                        }
                    }
                }
            }
            .padding(.horizontal, 10)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct SettingsSidebarRow: View {
    let tab: SettingsTab
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.white : Color.accentColor)
                    .frame(width: 18, alignment: .center)

                Text(tab.title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.white : Color.primary)

                Spacer()
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5.5)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 6.5, style: .continuous)
                    .fill(
                        isSelected
                            ? Color.accentColor
                            : (isHovered ? Color.primary.opacity(0.06) : Color.clear)
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
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

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.7"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "7"
        return "\(version) (Build \(build))"
    }

    var body: some View {
        Form {
            Section("Download Directory") {
                LabeledContent("Save files to") {
                    HStack(spacing: 8) {
                        Image(systemName: "folder.fill")
                            .foregroundStyle(.secondary)

                        Text(customSavePath.isEmpty ? defaultDownloadPath : customSavePath)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }

                HStack(spacing: 8) {
                    Button("Choose Folder") {
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
                    Text(appVersion)
                        .foregroundStyle(.secondary)
                        .font(.callout)
                    Button("Check Now") {
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
            EngineSettings.saveBookmark(for: url, key: EngineSettings.customSavePathBookmarkKey)
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
                Toggle("Limit Download Speed", isOn: $limitDownloadRate.animation(.easeInOut(duration: 0.18)))
                    .toggleStyle(.switch)

                if limitDownloadRate {
                    RateLimitConfigView(
                        rateKB: $maxDownloadRateKB,
                        presets: [
                            (label: "500 KB/s", kb: 500),
                            (label: "1 MB/s", kb: 1_000),
                            (label: "2 MB/s", kb: 2_000),
                            (label: "5 MB/s", kb: 5_000),
                            (label: "10 MB/s", kb: 10_000),
                            (label: "25 MB/s", kb: 25_000),
                            (label: "50 MB/s", kb: 50_000),
                            (label: "100 MB/s", kb: 100_000),
                        ],
                        minKB: 500,
                        maxKB: 100_000
                    )
                }
            }

            Section("Upload Bandwidth") {
                Toggle("Limit Upload Speed", isOn: $limitUploadRate.animation(.easeInOut(duration: 0.18)))
                    .toggleStyle(.switch)

                if limitUploadRate {
                    RateLimitConfigView(
                        rateKB: $maxUploadRateKB,
                        presets: [
                            (label: "500 KB/s", kb: 500),
                            (label: "1 MB/s", kb: 1_000),
                            (label: "2 MB/s", kb: 2_000),
                            (label: "5 MB/s", kb: 5_000),
                            (label: "10 MB/s", kb: 10_000),
                            (label: "20 MB/s", kb: 20_000),
                        ],
                        minKB: 100,
                        maxKB: 25_000
                    )
                }
            }

            Section {
                Stepper(value: $maxActiveTorrents, in: 1...20) {
                    LabeledContent("Max Active Downloads", value: "\(maxActiveTorrents)")
                }
            } footer: {
                Text("Rate limits are session-wide targets. libtorrent may briefly exceed them, and peers on the local network are exempt by default.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .contentMargins(.top, 8, for: .scrollContent)
    }
}

// MARK: - Rate Limit Config View

struct RateLimitConfigView: View {
    @Binding var rateKB: Int
    let presets: [(label: String, kb: Int)]
    let minKB: Int
    let maxKB: Int

    @State private var unit: RateUnit = .mb
    @State private var textValue: String = ""
    @FocusState private var isFieldFocused: Bool

    enum RateUnit: String, CaseIterable, Identifiable {
        case mb = "MB/s"
        case kb = "KB/s"
        var id: String { rawValue }
    }

    private var currentUnitMultiplier: Double {
        unit == .mb ? 1000.0 : 1.0
    }

    private var mbpsEquivalent: Double {
        (Double(rateKB) * 8.0) / 1000.0
    }

    private var formattedMbps: String {
        if mbpsEquivalent >= 10 {
            return String(format: "%.0f", mbpsEquivalent)
        } else {
            return String(format: "%.1f", mbpsEquivalent)
        }
    }

    private var formattedRateString: String {
        if rateKB >= 1000 && rateKB % 1000 == 0 {
            return "\(rateKB / 1000) MB/s"
        } else if rateKB >= 1000 {
            return String(format: "%.1f MB/s", Double(rateKB) / 1000.0)
        } else {
            return "\(rateKB) KB/s"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Quick Presets
            VStack(alignment: .leading, spacing: 6) {
                Text("Quick Presets")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(presets, id: \.kb) { preset in
                            let isSelected = rateKB == preset.kb
                            Button {
                                rateKB = preset.kb
                                if preset.kb < 1000 {
                                    unit = .kb
                                } else if preset.kb % 1000 == 0 {
                                    unit = .mb
                                }
                                syncTextFromRate()
                            } label: {
                                Text(preset.label)
                                    .font(.system(size: 11.5, weight: isSelected ? .semibold : .regular))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule()
                                            .fill(isSelected ? Color.accentColor : Color(nsColor: .quaternaryLabelColor).opacity(0.6))
                                    )
                                    .overlay(
                                        Capsule()
                                            .strokeBorder(isSelected ? Color.clear : Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 0.8)
                                    )
                                    .foregroundStyle(isSelected ? Color.white : Color.primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            Divider()
                .opacity(0.6)

            // Slider & Precise Input Row
            HStack(spacing: 12) {
                Slider(
                    value: Binding(
                        get: { Double(rateKB) },
                        set: { newValue in
                            let step: Double = unit == .mb ? 500 : 100
                            let rounded = Int((newValue / step).rounded() * step)
                            rateKB = max(minKB, min(maxKB, rounded))
                            syncTextFromRate()
                        }
                    ),
                    in: Double(minKB)...Double(maxKB)
                )

                HStack(spacing: 4) {
                    TextField("", text: $textValue)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 58)
                        .multilineTextAlignment(.trailing)
                        .font(.system(size: 12.5).monospacedDigit())
                        .focused($isFieldFocused)
                        .onSubmit {
                            commitTextValue()
                        }
                        .onChange(of: isFieldFocused) {
                            if !isFieldFocused {
                                commitTextValue()
                            }
                        }

                    Picker("", selection: $unit) {
                        ForEach(RateUnit.allCases) { u in
                            Text(u.rawValue).tag(u)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 82)
                    .onChange(of: unit) {
                        syncTextFromRate()
                    }

                    Stepper("", onIncrement: {
                        stepRate(by: 1)
                    }, onDecrement: {
                        stepRate(by: -1)
                    })
                    .labelsHidden()
                    .controlSize(.small)
                }
            }

            // Status Banner with Mbps Equivalent
            HStack(spacing: 6) {
                Image(systemName: "speedometer")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.accentColor)

                Text("Allocated limit: \(formattedRateString)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.primary)

                Text("•")
                    .foregroundStyle(.tertiary)

                Text("≈ \(formattedMbps) Mbps bandwidth")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 2)
        }
        .padding(.vertical, 4)
        .onAppear {
            if rateKB < 1000 || rateKB % 1000 != 0 {
                unit = .kb
            } else {
                unit = .mb
            }
            syncTextFromRate()
        }
        .onChange(of: rateKB) {
            if !isFieldFocused {
                syncTextFromRate()
            }
        }
    }

    private func stepRate(by direction: Int) {
        if unit == .mb {
            let currentMB = Double(rateKB) / 1000.0
            let step: Double = currentMB < 2.0 ? 0.5 : 1.0
            let newMB = max(Double(minKB) / 1000.0, min(Double(maxKB) / 1000.0, currentMB + (Double(direction) * step)))
            rateKB = Int((newMB * 1000.0).rounded())
        } else {
            let step = 500
            let newKB = max(minKB, min(maxKB, rateKB + (direction * step)))
            rateKB = newKB
        }
        syncTextFromRate()
    }

    private func syncTextFromRate() {
        if unit == .mb {
            let mbVal = Double(rateKB) / 1000.0
            if mbVal.truncatingRemainder(dividingBy: 1) == 0 {
                textValue = "\(Int(mbVal))"
            } else {
                textValue = String(format: "%.1f", mbVal)
            }
        } else {
            textValue = "\(rateKB)"
        }
    }

    private func commitTextValue() {
        guard let num = Double(textValue), num > 0 else {
            syncTextFromRate()
            return
        }
        let calculatedKB = Int((num * currentUnitMultiplier).rounded())
        rateKB = max(minKB, min(maxKB, calculatedKB))
        syncTextFromRate()
    }
}

// MARK: - Network Settings Pane

struct NetworkSettingsPane: View {
    @AppStorage("enableDHT") private var enableDHT = true
    @AppStorage("enableLSD") private var enableLSD = true
    @AppStorage("enableUPnP") private var enableUPnP = true
    @AppStorage("randomPort") private var randomPort = true
    @AppStorage("customPort") private var customPort = 6881

    @AppStorage("networkInterfaceMode") private var networkInterfaceMode = "auto_vpn"
    @AppStorage("killSwitchEnabled") private var killSwitchEnabled = false
    @AppStorage("connectionProfile") private var connectionProfile = "balanced"
    @AppStorage("maxGlobalConnections") private var maxGlobalConnections = 200
    @AppStorage("maxConnectionsPerTorrent") private var maxConnectionsPerTorrent = 50
    @AppStorage("mixedModePreferTCP") private var mixedModePreferTCP = true

    @ObservedObject private var networkService = NetworkInterfaceService.shared

    private struct ConnectionProfilePreset: Identifiable {
        let id: String
        let label: String
        let icon: String
        let globalLimit: Int
        let perTorrentLimit: Int
    }

    private let connectionPresets: [ConnectionProfilePreset] = [
        ConnectionProfilePreset(id: "hotspot", label: "Hotspot", icon: "antenna.radiowaves.left.and.right", globalLimit: 80, perTorrentLimit: 25),
        ConnectionProfilePreset(id: "balanced", label: "Balanced", icon: "scalemass.fill", globalLimit: 200, perTorrentLimit: 50),
        ConnectionProfilePreset(id: "fiber", label: "Fiber / Mesh", icon: "bolt.horizontal.fill", globalLimit: 500, perTorrentLimit: 120),
        ConnectionProfilePreset(id: "custom", label: "Custom", icon: "slider.horizontal.3", globalLimit: 200, perTorrentLimit: 50)
    ]

    private func applyProfilePreset(_ preset: ConnectionProfilePreset) {
        connectionProfile = preset.id
        if preset.id != "custom" {
            maxGlobalConnections = preset.globalLimit
            maxConnectionsPerTorrent = preset.perTorrentLimit
        }
    }

    var body: some View {
        Form {
            Section {
                Picker("Interface", selection: $networkInterfaceMode) {
                    Text("Auto-Detect VPN (Recommended)").tag("auto_vpn")
                    Text("Any Interface (All)").tag("any")
                    Divider()
                    ForEach(networkService.availableInterfaces) { iface in
                        Text(iface.displayName).tag(iface.name)
                    }
                }

                HStack {
                    if networkService.isConnectedToVPN {
                        Label {
                            Text("Active: \(networkService.activeVPN?.displayName ?? "VPN")")
                        } icon: {
                            Image(systemName: "lock.shield.fill")
                                .foregroundStyle(.green)
                        }
                    } else {
                        Label {
                            Text("Direct Connection (No VPN active)")
                        } icon: {
                            Image(systemName: "network")
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Button("Refresh") {
                        networkService.refreshInterfaces()
                    }
                    .controlSize(.small)
                }
                .font(.caption)

                Toggle(isOn: $killSwitchEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Require VPN (Kill Switch)")
                        Text("Halt transfers if the VPN disconnects to prevent leaking your real IP address.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)
            } header: {
                Text("VPN & Network Routing")
            } footer: {
                Text("When set to Auto-Detect, FetchFlow automatically binds to your VPN tunnel whenever connected. If you start a download on Wi-Fi and then connect to your VPN, traffic seamlessly transfers to the VPN.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Connection Profile")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(connectionPresets) { preset in
                                let isSelected = connectionProfile == preset.id
                                Button {
                                    applyProfilePreset(preset)
                                } label: {
                                    HStack(spacing: 5) {
                                        Image(systemName: preset.icon)
                                            .font(.system(size: 10.5))
                                        Text(preset.label)
                                            .font(.system(size: 11.5, weight: isSelected ? .semibold : .regular))
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule()
                                            .fill(isSelected ? Color.accentColor : Color(nsColor: .quaternaryLabelColor).opacity(0.6))
                                    )
                                    .overlay(
                                        Capsule()
                                            .strokeBorder(isSelected ? Color.clear : Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 0.8)
                                    )
                                    .foregroundStyle(isSelected ? Color.white : Color.primary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }

                LabeledContent("Global Connection Limit") {
                    HStack(spacing: 8) {
                        Slider(
                            value: Binding(
                                get: { Double(maxGlobalConnections) },
                                set: { newValue in
                                    let rounded = Int((newValue / 10.0).rounded() * 10.0)
                                    maxGlobalConnections = max(30, min(1000, rounded))
                                    connectionProfile = "custom"
                                }
                            ),
                            in: 30...1000
                        )

                        Text("\(maxGlobalConnections)")
                            .font(.system(size: 12.5).monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 36, alignment: .trailing)
                    }
                }

                LabeledContent("Per-Torrent Limit") {
                    HStack(spacing: 8) {
                        Slider(
                            value: Binding(
                                get: { Double(maxConnectionsPerTorrent) },
                                set: { newValue in
                                    let rounded = Int((newValue / 5.0).rounded() * 5.0)
                                    maxConnectionsPerTorrent = max(10, min(300, rounded))
                                    connectionProfile = "custom"
                                }
                            ),
                            in: 10...300
                        )

                        Text("\(maxConnectionsPerTorrent)")
                            .font(.system(size: 12.5).monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 36, alignment: .trailing)
                    }
                }
            } header: {
                Text("Connections & Router Stability")
            } footer: {
                Text("Controls concurrent connections to prevent home router NAT table exhaustion and Wi-Fi bufferbloat. Real-time active swarm stats can be monitored in the Inspector Connections tab.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Traffic Management") {
                Toggle(isOn: $mixedModePreferTCP) {
                    HStack(spacing: 8) {
                        Image(systemName: "globe.americas.fill")
                            .foregroundStyle(Color.accentColor)
                            .font(.system(size: 14))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Web & Streaming Protection (uTP LEDBAT)")
                            Text("Ensures background torrent traffic automatically yields bandwidth when websites, video calls, or DNS queries load.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .toggleStyle(.switch)
            }

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

                    if customPort < 1024 || customPort > 65535 {
                        Text("Ports must be between 1024 and 65535. 6881 is used until this is corrected.")
                            .font(.caption)
                            .foregroundStyle(.orange)
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
    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        if let build, !build.isEmpty {
            return "Version \(version) (Build \(build))"
        }
        return "Version \(version)"
    }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 16) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.primary)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("FetchFlow")
                            .font(.title2.bold())

                        Text(appVersion)
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
                LabeledContent("User Interface", value: "SwiftUI + AppKit (macOS 15.6+)")
            }

            Section("Links") {
                Link(destination: URL(string: "https://github.com/lazydev17/FetchFlow")!) {
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
