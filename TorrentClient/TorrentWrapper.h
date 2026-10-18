#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^TorrentProgressBlock)(NSString *infoHash,
                                     NSString *name,
                                     double progress,
                                     int64_t downloadRate,
                                     int64_t uploadRate,
                                     int64_t totalDownloaded,
                                     int64_t totalSize,
                                     NSString *state,
                                     int numPeers,
                                     int numSeeds);

typedef void (^TorrentMetadataBlock)(NSString *infoHash,
                                     NSString *name,
                                     int64_t totalSize,
                                     NSArray<NSDictionary<NSString *, id> *> *files);

typedef void (^TorrentFinishedBlock)(NSString *infoHash);

typedef void (^TorrentErrorBlock)(NSString *infoHash, NSString *error);


@interface TorrentWrapper : NSObject

- (instancetype)init;

- (void)setProgressCallback:(TorrentProgressBlock)cb;
- (void)setErrorCallback:(TorrentErrorBlock)cb;
- (void)setMetadataCallback:(TorrentMetadataBlock)cb;
- (void)setFinishedCallback:(TorrentFinishedBlock)cb;

- (nullable NSString *)addMagnet:(NSString *)magnet savePath:(NSString *)path;
- (nullable NSString *)addTorrentFile:(NSString *)filePath savePath:(NSString *)path;

- (void)pauseTorrent:(NSString *)infoHash;
- (void)resumeTorrent:(NSString *)infoHash;
- (void)removeTorrent:(NSString *)infoHash deleteFiles:(BOOL)deleteFiles;
- (void)setFilePriority:(int)fileIndex priority:(int)priority infoHash:(NSString *)infoHash;

- (void)stopAll;

@end

NS_ASSUME_NONNULL_END
