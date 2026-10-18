import SwiftUI

struct ContentView: View {
    @StateObject private var torrentManager = TorrentManager()
    @State private var isPresentingAddSheet: Bool = false
    @State private var sidebarWidth: CGFloat = 220
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom Toolbar
            CustomToolbarView(isPresentingAddSheet: $isPresentingAddSheet)
            
            Divider()
            
            // Main Content Area
            HStack(spacing: 0) {
                // Sidebar
                FolderSidebar()
                    .frame(width: sidebarWidth)
                
                // Resizable Divider
                Divider()
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let newWidth = value.location.x
                                self.sidebarWidth = max(180, min(newWidth, 350))
                            }
                    )
                
                // Detail List
                FileList(isPresentingAddSheet: $isPresentingAddSheet)
            }
        }
        .background(Color(.windowBackgroundColor))
        .ignoresSafeArea(edges: .top)
        .environmentObject(torrentManager)
        .sheet(isPresented: $isPresentingAddSheet) {
            AddTorrentSheet()
                .environmentObject(torrentManager)
        }
        .frame(minWidth: 700, minHeight: 450)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
