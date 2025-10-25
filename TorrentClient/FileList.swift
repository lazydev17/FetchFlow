import SwiftUI

/// This view represents the main content area (the "detail" view).
/// It displays the list of episodes for the currently selected series.
struct FileList: View {
    
    // --- Properties ---
    /// The currently selected series. This is an optional, because it's possible
    /// that no series is selected when the app first launches.
    let series: Series?
    
    // --- Body ---
    var body: some View {
        // We must handle the case where 'series' might be nil.
        // 'if let' safely unwraps the optional. If it has a value, the code inside
        // the braces runs. Otherwise, the 'else' block is shown.
        if let selectedSeries = series {
            
            // A vertical stack to hold the header and the list.
            VStack(alignment: .leading, spacing: 0) {
                
                // --- Custom Header ---
                HStack {
                    Text("Episodes in \(selectedSeries.name) (\(selectedSeries.episodes.count))")
                        .font(.headline)
                    
                    Spacer()
                    
                    Button(action: {}) {
                        Label("Download All as ZIP", systemImage: "arrow.down.circle")
                    }
                    // STYLE CHANGE: Reverted to '.borderedProminent' to match the solid button
                    // in your original design image.
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                
                Divider()
                
                // --- Episodes List ---
                List {
                    // We loop through each episode in the selected series to create a row.
                    ForEach(selectedSeries.episodes) { episode in
                        HStack(spacing: 16) {
                            Image(systemName: "video")
                            
                            Image(systemName: "ellipsis")
                                .foregroundColor(.secondary)

                            Text(episode.name)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Text(episode.size)
                                .foregroundColor(.secondary)
                            
                            Button(action: {}) {
                                Image(systemName: "arrow.down")
                            }
                            .buttonStyle(.borderless)
                        }
                        .padding(.vertical, 4)
                    }
                }
                // STYLE CHANGE: Changed from '.plain' to '.inset' and removed custom dividers
                // from the list rows for a cleaner look that matches your design.
                .listStyle(.inset)
            }
        } else {
            // --- Placeholder View ---
            // This is shown when no series is selected yet.
            VStack {
                Spacer()
                Text("Select a series from the list")
                    .font(.title)
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
    }
}

