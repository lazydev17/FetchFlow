import SwiftUI
import AppKit

struct FileList: View {
    @EnvironmentObject private var torrentManager: TorrentManager
    @Binding var isPresentingAddSheet: Bool
    @State private var torrentToDelete: TorrentModel?
    @State private var showingDeleteConfirmation = false

    private var items: [TorrentModel] { torrentManager.filteredTorrents }

    var body: some View {
        VStack(spacing: 0) {
            // Column Headers Bar
            TableHeaderView(items: items)

            Divider()

            // Main Table & Persistent Drop Zone
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(items) { torrent in
                        TorrentTableRow(
                            torrent: torrent,
                            isSelected: torrentManager.selectedInfoHash == torrent.infoHash,
                            onSelect: {
                                withAnimation(.easeInOut(duration: 0.12)) {
                                    torrentManager.selectedInfoHash = torrent.infoHash
                                }
                            },
                            onDelete: {
                                torrentToDelete = torrent
                                showingDeleteConfirmation = true
                            }
                        )
                        .contextMenu { contextMenu(for: torrent) }

                        Divider()
                            .opacity(0.5)
                    }

                    // Persistent Drag-and-Drop Dropzone
                    PersistentDropZoneView(onTap: {
                        isPresentingAddSheet = true
                    })
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
            }

            // Bottom Inspector Pane
            if let selectedTorrent = torrentManager.selectedTorrent {
                Divider()
                TorrentInspectorView(torrent: selectedTorrent)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .confirmationDialog("Remove Torrent", isPresented: $showingDeleteConfirmation, presenting: torrentToDelete) { torrent in
            Button("Remove from Client") { torrentManager.removeTorrent(torrent.infoHash, deleteFiles: false) }
            Button("Remove and Delete Files", role: .destructive) { torrentManager.removeTorrent(torrent.infoHash, deleteFiles: true) }
            Button("Cancel", role: .cancel) {}
        } message: { torrent in
            Text("Are you sure you want to remove '\(torrent.name)'?")
        }
    }

    @ViewBuilder private func contextMenu(for torrent: TorrentModel) -> some View {
        Button(torrent.canResume ? "Resume" : "Pause") {
            torrent.canResume ? torrentManager.resumeTorrent(torrent.infoHash) : torrentManager.pauseTorrent(torrent.infoHash)
        }
        Button("Show in Finder") { torrentManager.openInFinder(torrent.infoHash) }
        Button("Force Recheck") { torrentManager.forceRecheck(torrent.infoHash) }
        Menu("Priority") {
            ForEach(TorrentPriority.allCases) { priority in
                Button {
                    torrentManager.setPriority(priority, for: torrent.infoHash)
                } label: {
                    if torrent.priorityValue == priority {
                        Label(priority.rawValue, systemImage: "checkmark")
                    } else {
                        Text(priority.rawValue)
                    }
                }
            }
        }
        Divider()
        Button("Copy Magnet Link") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(torrent.magnetURI, forType: .string)
        }
        Button("Copy Info Hash") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(torrent.infoHash, forType: .string)
        }
        Divider()
        Button("Remove", role: .destructive) { torrentToDelete = torrent; showingDeleteConfirmation = true }
    }
}

// MARK: - Table Header View

struct TableHeaderView: View {
    @EnvironmentObject private var torrentManager: TorrentManager
    let items: [TorrentModel]

    private var allSelected: Bool {
        !items.isEmpty && torrentManager.checkedInfoHashes.isSuperset(of: items.map { $0.infoHash })
    }

    var body: some View {
        HStack(spacing: 8) {
            Toggle("", isOn: Binding(
                get: { allSelected },
                set: { _ in torrentManager.toggleCheckAll(items: items) }
            ))
            .toggleStyle(.checkbox)
            .labelsHidden()
            .frame(width: 34, alignment: .center)
            
            Text("Name")
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text("Size")
                .frame(width: 75, alignment: .trailing)
            
            Text("Status")
                .frame(width: 150, alignment: .leading)
                .padding(.leading, 8)
            
            Text("Download")
                .frame(width: 80, alignment: .trailing)
            
            Text("Upload")
                .frame(width: 80, alignment: .trailing)
            
            Text("Added")
                .frame(width: 75, alignment: .trailing)
            
            Spacer()
                .frame(width: 32)
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
    }
}

// MARK: - Torrent Table Row

struct TorrentTableRow: View {
    let torrent: TorrentModel
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void

    @EnvironmentObject private var torrentManager: TorrentManager
    @State private var isHovered = false

    private var isChecked: Bool {
        torrentManager.checkedInfoHashes.contains(torrent.infoHash)
    }

    var body: some View {
        HStack(spacing: 8) {
            // Checkbox
            Toggle("", isOn: Binding(
                get: { isChecked },
                set: { _ in torrentManager.toggleCheck(torrent.infoHash) }
            ))
            .toggleStyle(.checkbox)
            .labelsHidden()
            .frame(width: 34, alignment: .center)

            // Name with Folder/Doc Icon
            HStack(spacing: 8) {
                Image(systemName: torrent.files.count > 1 ? "folder.fill" : "doc.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.accentColor)

                Text(torrent.name)
                    .font(.system(size: 12.5, weight: isSelected ? .semibold : .regular))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Size
            Text(torrent.formattedTotalSize)
                .font(.system(size: 12).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 75, alignment: .trailing)

            // Status Column: Thick Progress Bar with Info Inside
            ThickStatusProgressBar(torrent: torrent)
                .frame(width: 150)
                .padding(.leading, 8)

            // Download Speed
            Text(torrent.downloadRate > 0 ? torrent.formattedDownloadRate : "0 B/s")
                .font(.system(size: 11.5).monospacedDigit())
                .foregroundStyle(torrent.downloadRate > 0 ? Color.primary : Color.secondary)
                .frame(width: 80, alignment: .trailing)

            // Upload Speed
            Text(torrent.uploadRate > 0 ? torrent.formattedUploadRate : "0 B/s")
                .font(.system(size: 11.5).monospacedDigit())
                .foregroundStyle(torrent.uploadRate > 0 ? Color.green : Color.secondary)
                .frame(width: 80, alignment: .trailing)

            // Added Date
            Text(torrent.shortDateAdded)
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
                .frame(width: 75, alignment: .trailing)

            // 3-dots Context Menu Button (Native NSMenu popup to eliminate SwiftUI render-loop flicker)
            ActionMenuButton {
                TorrentMenuBuilder.buildMenu(
                    for: torrent,
                    torrentManager: torrentManager,
                    onDelete: onDelete
                )
            }
            .frame(width: 32, height: 24)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(rowBackground)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .onHover { hovering in
            isHovered = hovering
        }
    }

    @ViewBuilder private var rowBackground: some View {
        if isSelected {
            Color.accentColor.opacity(0.14)
        } else if isChecked {
            Color.accentColor.opacity(0.08)
        } else if isHovered {
            Color(nsColor: .quaternaryLabelColor).opacity(0.4)
        } else {
            Color.clear
        }
    }
}

// MARK: - Thick Status Progress Bar

struct ThickStatusProgressBar: View {
    let torrent: TorrentModel

    private var statusText: String {
        switch torrent.state {
        case .finished:
            return "Completed"
        case .downloading:
            if torrent.etaDescription != "Downloading" {
                return "\(torrent.formattedProgress) • \(torrent.etaDescription)"
            } else {
                return torrent.formattedProgress
            }
        case .queued:
            return "Queued"
        case .skipped:
            return "No files selected"
        case .paused:
            return "Paused • \(torrent.formattedProgress)"
        case .seeding:
            return "Seeding • \(torrent.formattedProgress)"
        case .checkingFiles:
            return "Checking • \(torrent.formattedProgress)"
        case .downloadingMetadata:
            return "Fetching Metadata"
        case .error:
            return torrent.error ?? "Error"
        }
    }

    private var tintColor: Color {
        torrent.state == .finished ? Color.green : torrent.state.tintColor
    }

    var body: some View {
        GeometryReader { geo in
            let fillWidth = max(0, min(geo.size.width * CGFloat(torrent.displayProgress), geo.size.width))

            ZStack(alignment: .leading) {
                // Background track
                Capsule()
                    .fill(Color(nsColor: .separatorColor).opacity(0.35))

                // Progress fill (clipped to capsule container)
                Rectangle()
                    .fill(tintColor)
                    .frame(width: fillWidth)

                // Base text (over unfilled track)
                Text(statusText)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.primary.opacity(0.85))
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

                // High-contrast white text (clipped to filled track)
                Text(statusText)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .mask(
                        HStack(spacing: 0) {
                            Rectangle()
                                .frame(width: fillWidth)
                            Spacer(minLength: 0)
                        }
                    )
            }
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
            )
        }
        .frame(height: 20)
    }
}


struct PersistentDropZoneView: View {
    let onTap: () -> Void
    @EnvironmentObject private var torrentManager: TorrentManager
    @State private var isTargeted = false
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "arrow.down.doc")
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(isTargeted ? Color.accentColor : Color.secondary.opacity(0.8))

            Text("Drag-and-drop a .torrent file or magnet link")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isTargeted ? Color.accentColor : Color.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isTargeted ? Color.accentColor.opacity(0.08) : (isHovered ? Color(nsColor: .controlBackgroundColor).opacity(0.5) : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(
                    isTargeted ? Color.accentColor : Color.secondary.opacity(0.35),
                    style: StrokeStyle(lineWidth: 1.5, dash: [8, 5])
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            var handled = false
            for url in urls {
                let ext = url.pathExtension.lowercased()
                if url.isFileURL && ext == "torrent" {
                    if torrentManager.addTorrentFile(url) == nil {
                        torrentManager.engineError = torrentManager.lastAddError
                            ?? "Failed to add torrent file."
                    }
                    handled = true
                } else if url.scheme?.lowercased() == "magnet" {
                    if torrentManager.addMagnet(url.absoluteString) == nil {
                        torrentManager.engineError = torrentManager.lastAddError
                            ?? "Failed to add magnet link."
                    }
                    handled = true
                }
            }
            return handled
        } isTargeted: { targeted in
            isTargeted = targeted
        }
    }
}

// MARK: - Native NSMenuItem Closure Target

fileprivate final class MenuItemActionTarget: NSObject {
    private let action: () -> Void

    init(action: @escaping () -> Void) {
        self.action = action
        super.init()
    }

    @objc func invoke(_ sender: Any?) {
        action()
    }
}

fileprivate extension NSMenuItem {
    convenience init(title: String, keyEquivalent: String = "", action: @escaping () -> Void) {
        let target = MenuItemActionTarget(action: action)
        self.init(title: title, action: #selector(MenuItemActionTarget.invoke(_:)), keyEquivalent: keyEquivalent)
        self.target = target
        self.representedObject = target
    }
}

// MARK: - Native Torrent Menu Builder

enum TorrentMenuBuilder {
    @MainActor
    static func buildMenu(
        for torrent: TorrentModel,
        torrentManager: TorrentManager,
        onDelete: @escaping () -> Void
    ) -> NSMenu {
        let menu = NSMenu(title: "Torrent Actions")
        menu.autoenablesItems = false

        // Resume / Pause
        let resumePauseTitle = torrent.canResume ? "Resume" : "Pause"
        let resumePauseItem = NSMenuItem(title: resumePauseTitle) {
            if torrent.canResume {
                torrentManager.resumeTorrent(torrent.infoHash)
            } else {
                torrentManager.pauseTorrent(torrent.infoHash)
            }
        }
        menu.addItem(resumePauseItem)

        // Show in Finder
        let finderItem = NSMenuItem(title: "Show in Finder") {
            torrentManager.openInFinder(torrent.infoHash)
        }
        menu.addItem(finderItem)

        // Priority Submenu
        let prioritySubmenu = NSMenu(title: "Priority")
        prioritySubmenu.autoenablesItems = false
        for priority in TorrentPriority.allCases {
            let item = NSMenuItem(title: priority.rawValue) {
                torrentManager.setPriority(priority, for: torrent.infoHash)
            }
            item.state = (torrent.priorityValue == priority) ? .on : .off
            prioritySubmenu.addItem(item)
        }

        let priorityParentItem = NSMenuItem(title: "Priority", action: nil, keyEquivalent: "")
        priorityParentItem.submenu = prioritySubmenu
        menu.addItem(priorityParentItem)

        menu.addItem(NSMenuItem.separator())

        // Copy Magnet Link
        let magnetItem = NSMenuItem(title: "Copy Magnet Link") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(torrent.magnetURI, forType: .string)
        }
        menu.addItem(magnetItem)

        // Copy Info Hash
        let hashItem = NSMenuItem(title: "Copy Info Hash") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(torrent.infoHash, forType: .string)
        }
        menu.addItem(hashItem)

        menu.addItem(NSMenuItem.separator())

        // Remove
        let removeItem = NSMenuItem(title: "Remove") {
            DispatchQueue.main.async {
                onDelete()
            }
        }
        menu.addItem(removeItem)

        return menu
    }
}

// MARK: - Action Menu Button (Native AppKit PopUp to avoid SwiftUI render-loop flicker)

struct ActionMenuButton: NSViewRepresentable {
    let makeMenu: () -> NSMenu

    func makeNSView(context: Context) -> ActionMenuNSButton {
        let button = ActionMenuNSButton()
        button.menuBuilder = makeMenu
        return button
    }

    func updateNSView(_ nsView: ActionMenuNSButton, context: Context) {
        nsView.menuBuilder = makeMenu
    }
}

final class ActionMenuNSButton: NSButton {
    var menuBuilder: (() -> NSMenu)?

    private var trackingArea: NSTrackingArea?
    private var isHovered = false
    private var isMenuOpen = false

    private static let verticalEllipsisImage: NSImage = {
        let size = NSSize(width: 24, height: 24)
        let img = NSImage(size: size, flipped: false) { _ in
            guard let base = NSImage(systemSymbolName: "ellipsis", accessibilityDescription: nil) else {
                return false
            }
            let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .bold)
            let configured = base.withSymbolConfiguration(config) ?? base

            let transform = NSAffineTransform()
            transform.translateX(by: size.width / 2, yBy: size.height / 2)
            transform.rotate(byDegrees: 90)
            transform.translateX(by: -size.height / 2, yBy: -size.width / 2)
            transform.concat()

            let drawRect = NSRect(
                x: (size.width - configured.size.width) / 2,
                y: (size.height - configured.size.height) / 2,
                width: configured.size.width,
                height: configured.size.height
            )
            configured.draw(in: drawRect)
            return true
        }
        img.isTemplate = true
        return img
    }()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        isBordered = false
        imagePosition = .imageOnly
        image = Self.verticalEllipsisImage
        imageScaling = .scaleNone
        contentTintColor = .secondaryLabelColor
        bezelStyle = .regularSquare
        setButtonType(.momentaryPushIn)
        focusRingType = .none
        toolTip = "More Actions"
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea = trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        isHovered = true
        contentTintColor = .labelColor
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        isHovered = false
        contentTintColor = isMenuOpen ? .labelColor : .secondaryLabelColor
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        if isHighlighted || isMenuOpen {
            let pillRect = bounds.insetBy(dx: 4, dy: 1)
            let path = NSBezierPath(roundedRect: pillRect, xRadius: 4, yRadius: 4)
            NSColor.separatorColor.withAlphaComponent(0.35).setFill()
            path.fill()
        } else if isHovered {
            let pillRect = bounds.insetBy(dx: 4, dy: 1)
            let path = NSBezierPath(roundedRect: pillRect, xRadius: 4, yRadius: 4)
            NSColor.separatorColor.withAlphaComponent(0.18).setFill()
            path.fill()
        }
        super.draw(dirtyRect)
    }

    override func mouseDown(with event: NSEvent) {
        presentMenu()
    }

    override func performClick(_ sender: Any?) {
        presentMenu()
    }

    private func presentMenu() {
        guard let menu = menuBuilder?() else { return }

        isMenuOpen = true
        highlight(true)
        contentTintColor = .labelColor
        needsDisplay = true

        // Position directly below button, aligning the right edge of the menu with the button
        let origin = NSPoint(x: bounds.maxX - menu.size.width, y: bounds.height + 2)
        _ = menu.popUp(positioning: nil, at: origin, in: self)

        isMenuOpen = false
        highlight(false)
        contentTintColor = isHovered ? .labelColor : .secondaryLabelColor
        needsDisplay = true
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        return menuBuilder?()
    }
}
