//
//  Models.swift
//  TorrentClient
//
//  Created by Satya Sanjay on 03/10/25.
//

import Foundation

// --- Data Models ---

/// Represents a single series, containing multiple episodes.
/// It's 'Identifiable' so lists can track items uniquely.
/// It's 'Hashable' to allow it to be used in selection-based collections.
struct Series: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let totalSize: String
    let episodes: [Episode]
}

/// Represents a single episode within a series.
struct Episode: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let size: String
}


// --- Sample Data ---
// A centralized place to hold all the dummy data for the preview and app.
class SampleData {
    
    /// A static list of sample episodes for the "Friends" series.
    static let friendsEpisodes = [
        Episode(name: "S01E01 - The One Where Monica Gets a Roommate", size: "780 MB"),
        Episode(name: "S01E02 - The One with the Sonogram at the End", size: "750 MB"),
        Episode(name: "S01E03 - The One with the Thumb", size: "760 MB"),
        Episode(name: "S01E04 - The One with George Stephanopoulos", size: "770 MB")
    ]
    
    /// A static list of all the sample series, matching your UI design.
    static let series: [Series] = [
        Series(name: "Breaking Bad", totalSize: "3.6 GB", episodes: []),
        Series(name: "Game of Thrones", totalSize: "7.8 GB", episodes: []),
        Series(name: "The Office", totalSize: "4.5 GB", episodes: []),
        Series(name: "Stranger Things", totalSize: "4.5 GB", episodes: []),
        Series(name: "Friends", totalSize: "3.1 GB", episodes: friendsEpisodes),
        Series(name: "The Crown", totalSize: "6.6 GB", episodes: []),
        Series(name: "Money Heist", totalSize: "6.6 GB", episodes: [])
    ]
}
