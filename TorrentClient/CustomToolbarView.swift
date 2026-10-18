import SwiftUI

struct CustomToolbarView: View {
    @EnvironmentObject private var torrentManager: TorrentManager
    @Binding var isPresentingAddSheet: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Search Field
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 13))
                
                TextField("Search downloads...", text: $torrentManager.searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                
                if !torrentManager.searchText.isEmpty {
                    Button {
                        torrentManager.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(Color(.unemphasizedSelectedContentBackgroundColor).opacity(0.7))
            .cornerRadius(8)
            .frame(maxWidth: 300)
            
            Spacer()
            
            // Action Buttons
            HStack(spacing: 8) {
                Button {
                    isPresentingAddSheet = true
                } label: {
                    Label("Add Torrent", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                
                Button {
                    torrentManager.stopAll()
                } label: {
                    Image(systemName: "pause.fill")
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .help("Pause All Torrents")
            }
        }
        .padding(.horizontal, 16)
        .padding(.leading, 72) // Safe inset for macOS traffic light buttons
        .frame(height: 48)
    }
}
