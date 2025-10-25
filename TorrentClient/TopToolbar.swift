//
//  TopToolbar.swift
//  TorrentClient
//
//  Created by Satya Sanjay on 02/10/25.
//

import SwiftUI

struct TopToolbar: ToolbarContent {
    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button(action: {}) {
                Label("Add torrent", systemImage: "plus")
            }
            
            Button(action: {}) {
                Label("More", systemImage: "ellipsis.circle")
            }
        }
    }
}
