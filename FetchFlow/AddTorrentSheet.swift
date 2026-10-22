import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Input Mode

enum TorrentInputMode: String, CaseIterable {
    case magnet = "Magnet Link"
    case file = ".torrent File"
}

// MARK: - Add Torrent Sheet

struct AddTorrentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var torrentManager: TorrentManager

    @State private var inputMode: TorrentInputMode = .magnet
    @State private var magnetLink = ""
    @State private var selectedFileURL: URL?
    @State private var saveFolderURL: URL
    @State private var errorMessage: String?

    init() {
        _saveFolderURL = State(initialValue: EngineSettings.defaultSaveDirectory)
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    Picker("Source", selection: $inputMode) {
                        ForEach(TorrentInputMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    if inputMode == .magnet {
                        LabeledContent("Magnet URI") {
                            HStack {
                                TextField("magnet:?xt=urn:btih:…", text: $magnetLink)
                                    .textFieldStyle(.roundedBorder)

                                Button("Paste") {
                                    if let clip = NSPasteboard.general.string(forType: .string) {
                                        magnetLink = clip.trimmingCharacters(in: .whitespacesAndNewlines)
                                    }
                                }
                                .controlSize(.small)
                            }
                        }
                    } else {
                        LabeledContent("File") {
                            HStack {
                                Text(selectedFileURL?.lastPathComponent ?? "No file selected")
                                    .foregroundStyle(selectedFileURL == nil ? .secondary : .primary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                Button("Browse", action: chooseTorrentFile)
                                    .controlSize(.small)
                            }
                        }
                    }
                } header: {
                    Label("Add New Torrent", systemImage: "arrow.down.circle")
                        .font(.headline)
                }

                Section("Destination") {
                    LabeledContent("Save to") {
                        HStack {
                            Label(saveFolderURL.lastPathComponent, systemImage: "folder")
                                .lineLimit(1)
                                .truncationMode(.middle)

                            Spacer()

                            Button("Choose", action: chooseDestinationFolder)
                                .controlSize(.small)
                        }
                    }
                }

                if let error = errorMessage {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)

            Divider()

            HStack {
                Button("Cancel", action: dismiss.callAsFunction)
                    .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Add Torrent", action: submit)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(isAddDisabled)
            }
            .padding()
        }
        .frame(width: 520, height: 330)
    }

    private var isAddDisabled: Bool {
        if inputMode == .magnet {
            return magnetLink.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } else {
            return selectedFileURL == nil
        }
    }

    private func chooseTorrentFile() {
        let panel = NSOpenPanel()
        panel.title = "Select Torrent File"
        panel.allowedContentTypes = [.init(filenameExtension: "torrent") ?? .data]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        if panel.runModal() == .OK, let url = panel.url {
            selectedFileURL = url
            EngineSettings.saveTorrentBookmark(for: url)
            errorMessage = nil
        }
    }

    private func chooseDestinationFolder() {
        let panel = NSOpenPanel()
        panel.title = "Select Download Directory"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true

        if panel.runModal() == .OK, let url = panel.url {
            saveFolderURL = url
            EngineSettings.saveFolderBookmark(for: url)
        }
    }

    private func submit() {
        torrentManager.lastAddError = nil

        if inputMode == .magnet {
            let trimmed = magnetLink.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            if torrentManager.addMagnet(trimmed, saveLocation: saveFolderURL) != nil {
                dismiss()
            } else {
                errorMessage = torrentManager.lastAddError
                    ?? "Failed to add magnet link. Please verify the URL."
            }
        } else {
            guard let fileURL = selectedFileURL else { return }
            if torrentManager.addTorrentFile(fileURL, saveLocation: saveFolderURL) != nil {
                dismiss()
            } else {
                errorMessage = torrentManager.lastAddError
                    ?? "Failed to parse torrent file."
            }
        }
    }
}
