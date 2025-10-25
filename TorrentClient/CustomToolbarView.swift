import SwiftUI

/// This view represents our completely custom toolbar UI.
/// We have full control over its appearance and layout.
struct CustomToolbarView: View {
    
    // State to hold the text for our custom search field.
    @State private var searchText = ""
    
    var body: some View {
        // We use an HStack to lay out the toolbar items horizontally.
        HStack {
            // --- Search Field (Left Side) ---
            HStack {
                // Magnifying glass icon
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                // The actual text field for user input
                TextField("Search episodes and series...", text: $searchText)
                    .textFieldStyle(.plain) // Use plain style to remove default borders
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            // This creates the rounded rectangle background for the search field.
            .background(Color(.unemphasizedSelectedContentBackgroundColor))
            .cornerRadius(8)
            
            // This spacer pushes the search field to the left and the buttons to the right.
            Spacer()
            
            // --- Action Buttons (Right Side) ---
            HStack {
                Button {
                    // Action for adding a torrent
                    print("Add Torrent button tapped")
                } label: {
                    // Use a Label for an icon and text together.
                    Label("Add Torrent", systemImage: "plus")
                }
                // This style gives the button a subtle border, similar to your design.
                .buttonStyle(.bordered)
                
                Button {
                    // Action for the more options menu
                    print("More options button tapped")
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .buttonStyle(.plain) // Plain style for an icon-only button
                .font(.title2)
            }
        }
        // --- THIS IS THE KEY CHANGE ---
        // We now manually control the padding to avoid the traffic lights.
        .padding(.horizontal)
        .padding(.leading, 60)
        // Set a fixed height for our toolbar area.
        .frame(height: 40)
    }
}

struct CustomToolbarView_Previews: PreviewProvider {
    static var previews: some View {
        CustomToolbarView()
            .preferredColorScheme(.light)
    }
}

