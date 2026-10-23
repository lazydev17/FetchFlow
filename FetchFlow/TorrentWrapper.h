#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^TorrentProgressBlock)(NSString *infoHash,
                                     NSString *name,
                                     double progress,
                                     int64_t downloadRate,
                                     int64_t uploadRate,
                                     int64_t totalDownloaded,
                                     int64_t totalUploaded,
                                     int64_t totalSize,
                                     int64_t totalWanted,
                                     int64_t totalWantedDone,
                                     NSString *state,
                                     int numPeers,
                                     int numSeeds);

typedef void (^TorrentMetadataBlock)(NSString *infoHash,
                                     NSString *name,
                                     int64_t totalSize,
                                     NSArray<NSDictionary<NSString *, id> *> *files);

typedef void (^TorrentFinishedBlock)(NSString *infoHash);

typedef void (^TorrentErrorBlock)(NSString *infoHash, NSString *error);

typedef void (^TorrentRemovedBlock)(NSString *infoHash);


@interface TorrentWrapper : NSObject

- (instancetype)init;

- (void)setProgressCallback:(TorrentProgressBlock)cb;
- (void)setErrorCallback:(TorrentErrorBlock)cb;
- (void)setMetadataCallback:(TorrentMetadataBlock)cb;
- (void)setFinishedCallback:(TorrentFinishedBlock)cb;
- (void)setRemovedCallback:(TorrentRemovedBlock)cb;

// Applies engine settings (DHT/LSD/UPnP, listening port, rate limits, queue limits).
// Keys are shared with the Swift layer; see EngineSettings.swift.
- (void)applySettings:(NSDictionary<NSString *, id> *)settings;

- (nullable NSString *)addMagnet:(NSString *)magnet savePath:(NSString *)path;
- (nullable NSString *)addTorrentFile:(NSString *)filePath savePath:(NSString *)path;

- (void)pauseTorrent:(NSString *)infoHash;
- (void)resumeTorrent:(NSString *)infoHash;
- (void)removeTorrent:(NSString *)infoHash deleteFiles:(BOOL)deleteFiles;
- (void)setFilePriority:(int)fileIndex priority:(int)priority infoHash:(NSString *)infoHash;

// 0 = move to the front of the download queue, 1 = leave order unchanged,
// 2 = move to the back of the download queue.
- (void)setQueuePriority:(int)priority infoHash:(NSString *)infoHash;

// Asks libtorrent to write fast-resume data for this torrent (includes file priorities).
- (void)saveResumeDataForTorrent:(NSString *)infoHash;

// Per-file progress in [0, 1], ordered by libtorrent file index. Nil until metadata exists.
- (nullable NSArray<NSNumber *> *)fileProgressForTorrent:(NSString *)infoHash;

// Human-readable reason for the most recent addMagnet/addTorrentFile failure.
- (nullable NSString *)lastAddError;

// Saves resume data and session state, then tears the session down. Idempotent.
- (void)stopAll;

// Re-binds all listen and outgoing sockets to accommodate network interface or VPN changes.
- (void)reopenNetworkSockets;

// The interface libtorrent is currently bound to (e.g. @"utun4"), or empty string if unbound.
- (NSString *)currentBoundInterface;

@end

NS_ASSUME_NONNULL_END
