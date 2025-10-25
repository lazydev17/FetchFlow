import SwiftUI

struct ContentView: View {
    
    @State private var allSeries = SampleData.series
    
    @State private var selectedSeriesId: Series.ID? = SampleData.series[4].id
    
    var body: some View {
        VStack(spacing: 0) {
            CustomToolbarView()

            // A divider to separate the toolbar from the content below.
            Divider()

            // --- Main Content Area ---
            HStack(spacing: 0) {
                
                // --- Sidebar View (First Column) ---
                FolderSidebar(series: allSeries, selection: $selectedSeriesId)
                    .frame(minWidth: 250, maxWidth: 350)

                // This divider creates the vertical line between the sidebar and the detail view.
                Divider()

                // --- Detail View (Second Column) ---
                FileList(series: selectedSeries())
            }
        }
        .background(Color(.windowBackgroundColor))
        .ignoresSafeArea(edges: .top)
    }

    
    // --- Helper Function ---
    
    /// A private helper function to find the full 'Series' object that corresponds
    /// to the 'selectedSeriesId'.
    private func selectedSeries() -> Series? {
        if let id = selectedSeriesId {
            return allSeries.first { $0.id == id }
        }
        return nil
    }
}


// --- Xcode Preview ---
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .preferredColorScheme(.dark)
    }
}

