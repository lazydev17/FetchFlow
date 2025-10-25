import SwiftUI

/// This view represents the sidebar on the left of the main window.
/// It displays a custom-styled list of all the available series.
struct FolderSidebar: View {
    
    // --- Properties ---
    /// The complete list of series to display.
    let series: [Series]
    
    /// A 'Binding' to the selected series ID. When a row is tapped, this updates
    /// the @State variable in the ContentView.
    @Binding var selection: Series.ID?

    // --- Body ---
    /// The content and layout of the view.
    var body: some View {
        // A VStack to hold our custom title and the list.
        VStack(alignment: .leading, spacing: 0) {
            
            // --- Custom Header ---
            // Since we're not in a Navigation view, we create our own title.
            Text("Web Series")
                .font(.title2)
                .fontWeight(.bold)
                .padding()

            // LAYOUT CHANGE: Replaced 'List' with a 'ScrollView' and 'LazyVStack'.
            // This gives us complete control over the row styling, background, and selection.
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(series) { seriesItem in
                        
                        // --- Custom Row ---
                        HStack {
                            Image(systemName: "folder")
                                .font(.title2)
                            
                            VStack(alignment: .leading) {
                                Text(seriesItem.name)
                                    .font(.headline)
                                Text(seriesItem.totalSize)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Spacer() // Pushes the chevron to the right
                            
                            // Show a chevron only for the selected item
                            if seriesItem.id == selection {
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal)
                        // STYLE CHANGE: Manually set the background color for the selected row.
                        .background(seriesItem.id == selection ? Color(.selectedContentBackgroundColor) : Color.clear)
                        .cornerRadius(8)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        // This makes the entire row tappable.
                        .onTapGesture {
                            selection = seriesItem.id
                        }
                    }
                }
            }
        }
    }
}

