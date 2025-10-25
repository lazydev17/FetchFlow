#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// --- UPDATED: Callback now includes the torrent name and its state ---
typedef void (^TorrentProgressBlock)(NSString *infoHash, NSString *name, double progress, int downloadRate, int uploadRate, NSString *state);

// --- NEW: A dedicated callback for propagating errors to Swift ---
typedef void (^TorrentErrorBlock)(NSString *infoHash, NSString *error);


@interface TorrentWrapper : NSObject

- (instancetype)init;

- (void)setProgressCallback:(TorrentProgressBlock)cb;
- (void)setErrorCallback:(TorrentErrorBlock)cb;

- (void)addMagnet:(NSString*)magnet savePath:(NSString*)path;
- (void)stopAll;

@end

NS_ASSUME_NONNULL_END
