#import "TorrentWrapper.h"

// Include all necessary libtorrent headers
#include <libtorrent/session.hpp>
#include <libtorrent/add_torrent_params.hpp>
#include <libtorrent/magnet_uri.hpp>
#include <libtorrent/torrent_status.hpp>
#include <libtorrent/alert_types.hpp>
#include <libtorrent/alert.hpp>
#include <libtorrent/settings_pack.hpp>
#include <libtorrent/info_hash.hpp>
#include <libtorrent/sha1_hash.hpp>

// Standard C++ library headers
#include <thread>
#include <atomic>
#include <mutex>
#include <map>
#include <sstream>
#include <iomanip>

using namespace lt;

// Helper function to convert libtorrent state to a string for Swift
static NSString* torrentStateToString(lt::torrent_status::state_t s) {
    switch (s) {
        case lt::torrent_status::checking_files: return @"Checking";
        case lt::torrent_status::downloading_metadata: return @"Fetching Metadata";
        case lt::torrent_status::downloading: return @"Downloading";
        case lt::torrent_status::finished: return @"Finished";
        case lt::torrent_status::seeding: return @"Seeding";
        case lt::torrent_status::checking_resume_data: return @"Checking";
        default: return @"Downloading";
    }
}

// Local hex helpers that work across libtorrent 1.2.x and 2.0.x

// Convert a contiguous byte range to lowercase hex string
static std::string bytes_to_hex(const uint8_t* data, std::size_t len) {
    std::ostringstream oss;
    oss.setf(std::ios::hex, std::ios::basefield);
    oss.unsetf(std::ios::uppercase); // ensure lowercase hex
    oss.fill('0');
    for (std::size_t i = 0; i < len; ++i) {
        oss << std::setw(2) << static_cast<unsigned>(static_cast<uint8_t>(data[i]));
    }
    return oss.str();
}

// Overload for sha1_hash
static std::string hash_to_hex(const lt::sha1_hash& h) {
#if TORRENT_ABI_VERSION >= 3
    // libtorrent 2.0+: sha1_hash provides .data()/.size()
    auto const* ptr = reinterpret_cast<const uint8_t*>(h.data());
    constexpr std::size_t kSha1Len = 20;
    return bytes_to_hex(ptr, kSha1Len);
#else
    // libtorrent 1.2.x: data() returns const char*, use fixed 20-byte length
    auto const* ptr = reinterpret_cast<const uint8_t*>(h.data());
    constexpr std::size_t kSha1Len = 20;
    return bytes_to_hex(ptr, kSha1Len);
#endif
}

#if TORRENT_ABI_VERSION >= 3
// libtorrent 2.0+: info_hash_t may be v1, v2 or both. Prefer v1 if available for UI stability.
static std::string info_hash_to_hex(const lt::info_hash_t& ih) {
    if (ih.has_v1()) {
        return hash_to_hex(ih.v1);
    }
    // v2 is 32-byte SHA-256
    auto const* ptr = reinterpret_cast<const uint8_t*>(ih.v2.data());
    constexpr std::size_t kSha256Len = 32;
    return bytes_to_hex(ptr, kSha256Len);
}
#else
// libtorrent 1.2.x: info_hash is sha1_hash
static std::string info_hash_to_hex(const lt::sha1_hash& h) {
    return hash_to_hex(h);
}
#endif

@implementation TorrentWrapper {
    std::shared_ptr<lt::session> _session;
    std::thread _alertThread;
    std::atomic<bool> _running;
    
    // Callbacks
    TorrentProgressBlock _progressCb;
    TorrentErrorBlock _errorCb;
    
    // Mutex to protect access to callbacks
    std::mutex _cbMutex;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        lt::settings_pack settings;
        // Remove alert_category::update; it's not available in your libtorrent build.
        settings.set_int(lt::settings_pack::alert_mask,
                         lt::alert_category::status |
                         lt::alert_category::error |
                         lt::alert_category::storage);
        settings.set_str(lt::settings_pack::user_agent, "FetchFlow/1.0");
        
        _session = std::make_shared<lt::session>(settings);
        _running = true;

        // --- FIXED: Use a weak-strong dance to prevent a retain cycle ---
        __weak TorrentWrapper *weakSelf = self;
        
        // Start the dedicated alert processing thread
        _alertThread = std::thread([weakSelf]() {
            while (true) {
                TorrentWrapper *strongSelf = weakSelf;
                if (!strongSelf || !strongSelf->_running.load()) {
                    break;
                }
                
                std::vector<lt::alert*> alerts;
                strongSelf->_session->wait_for_alert(std::chrono::milliseconds(500));
                strongSelf->_session->pop_alerts(&alerts);

                for (lt::alert* a : alerts) {
                    if (auto st = lt::alert_cast<lt::state_update_alert>(a)) {
                        TorrentProgressBlock cbCopy = nil;
                        {
                            std::lock_guard<std::mutex> lock(strongSelf->_cbMutex);
                            if (strongSelf->_progressCb) cbCopy = [strongSelf->_progressCb copy];
                        }
                        if (!cbCopy) continue;

                        dispatch_async(dispatch_get_main_queue(), ^{
                            for (auto const& status : st->status) {
                                std::string ih;
#if TORRENT_ABI_VERSION >= 3
                                ih = info_hash_to_hex(status.info_hashes);
#else
                                ih = info_hash_to_hex(status.info_hash);
#endif
                                NSString *ihStr = [NSString stringWithUTF8String:ih.c_str()];
                                NSString *name = status.name.empty() ? ihStr : [NSString stringWithUTF8String:status.name.c_str()];
                                cbCopy(ihStr,
                                       name,
                                       status.progress,
                                       static_cast<int>(status.download_payload_rate),
                                       static_cast<int>(status.upload_payload_rate),
                                       torrentStateToString(status.state));
                            }
                        });
                    }
                    else if (auto te = lt::alert_cast<lt::torrent_error_alert>(a)) {
                        TorrentErrorBlock cbCopy = nil;
                        {
                            std::lock_guard<std::mutex> lock(strongSelf->_cbMutex);
                            if (strongSelf->_errorCb) cbCopy = [strongSelf->_errorCb copy];
                        }
                        if (cbCopy) {
                            dispatch_async(dispatch_get_main_queue(), ^{
                                std::string ih;
#if TORRENT_ABI_VERSION >= 3
                                ih = info_hash_to_hex(te->handle.info_hashes());
#else
                                ih = info_hash_to_hex(te->handle.info_hash());
#endif
                                cbCopy([NSString stringWithUTF8String:ih.c_str()],
                                       [NSString stringWithUTF8String:te->error.message().c_str()]);
                            });
                        }
                    }
                }
            }
        });
    }
    return self;
}

- (void)setProgressCallback:(TorrentProgressBlock)cb {
    std::lock_guard<std::mutex> lock(_cbMutex);
    _progressCb = [cb copy];
}

- (void)setErrorCallback:(TorrentErrorBlock)cb {
    std::lock_guard<std::mutex> lock(_cbMutex);
    _errorCb = [cb copy];
}

- (void)addMagnet:(NSString*)magnet savePath:(NSString*)path {
    if (magnet == nil || [magnet length] == 0) return;
    try {
        lt::add_torrent_params params = lt::parse_magnet_uri([magnet UTF8String]);
        params.save_path = [path UTF8String];
        _session->async_add_torrent(std::move(params));
    } catch (std::exception &e) {
        NSLog(@"addMagnet failed: %s", e.what());
    }
}

- (void)stopAll {
    {
        std::lock_guard<std::mutex> lock(_cbMutex);
        _progressCb = nil;
        _errorCb = nil;
    }

    _running = false;
    if (_alertThread.joinable()) {
        _alertThread.join();
    }
    _session.reset();
}

- (void)dealloc {
    [self stopAll];
}

@end
