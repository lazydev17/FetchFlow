import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct AddTorrentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var torrentManager: TorrentManager
    
    @State private var inputMode: Int = 0 // 0 = Magnet Link, 1 = Torrent File
    @State private var magnetLink: String = ""
    @State private var selectedFileURL: URL? = nil
    @State private var saveFolderURL: URL
    @State private var errorMessage: String? = nil
    
    init() {
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Downloads")
        _saveFolderURL = State(initialValue: downloads)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.primary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Add New Torrent")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Enter a magnet URI or select a local .torrent file")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            
            // Picker
            Picker("Source", selection: $inputMode) {
                Text("Magnet Link").tag(0)
                Text(".torrent File").tag(1)
            }
            .pickerStyle(.segmented)
            
            // Input Area
            if inputMode == 0 {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Magnet Link:")
                        .font(.headline)
                    HStack {
                        TextField("magnet:?xt=urn:btih:...", text: $magnetLink)
                            .textFieldStyle(.roundedBorder)
                        
                        Button("Paste") {
                            if let clip = NSPasteboard.general.string(forType: .string) {
                                magnetLink = clip.trimmingCharacters(in: .whitespacesAndNewlines)
                            }
                        }
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Torrent File:")
                        .font(.headline)
                    HStack {
                        Text(selectedFileURL?.lastPathComponent ?? "No file selected")
                            .foregroundStyle(selectedFileURL == nil ? .secondary : .primary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(6)
                            .background(Color(.textBackgroundColor))
                            .cornerRadius(6)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3), lineWidth: 1))
                        
                        Button("Browse...") {
                            chooseTorrentFile()
                        }
                    }
                }
            }
            
            // Destination Directory
            VStack(alignment: .leading, spacing: 6) {
                Text("Save Location:")
                    .font(.headline)
                HStack {
                    Image(systemName: "folder")
                        .foregroundStyle(.secondary)
                    Text(saveFolderURL.path)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Button("Choose...") {
                        chooseDestinationFolder()
                    }
                }
                .padding(6)
                .background(Color(.textBackgroundColor))
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3), lineWidth: 1))
            }
            
            if let error = errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
            }
            
            Spacer()
            
            // Actions
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Add Torrent") {
                    submit()
                }
                .buttonStyle(.borderedProminent)
                .tint(.primary)
                .keyboardShortcut(.defaultAction)
                .disabled(isAddDisabled)
            }
        }
        .padding(24)
        .frame(width: 520, height: 350)
    }
    
    private var isAddDisabled: Bool {
        if inputMode == 0 {
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
        }
    }
    
    private func submit() {
        if inputMode == 0 {
            let trimmed = magnetLink.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            if torrentManager.addMagnet(trimmed, saveLocation: saveFolderURL) != nil {
                dismiss()
            } else {
                errorMessage = "Failed to add magnet link. Please verify the URL."
            }
        } else {
            guard let fileURL = selectedFileURL else { return }
            if torrentManager.addTorrentFile(fileURL, saveLocation: saveFolderURL) != nil {
                dismiss()
            } else {
                errorMessage = "Failed to parse torrent file."
            }
        }
    }
}
