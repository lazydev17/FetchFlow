#import "TorrentWrapper.h"

// Include all necessary libtorrent headers
#include <libtorrent/session.hpp>
#include <libtorrent/add_torrent_params.hpp>
#include <libtorrent/magnet_uri.hpp>
#include <libtorrent/torrent_status.hpp>
#include <libtorrent/torrent_info.hpp>
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
#include <vector>
#include <sstream>
#include <iomanip>
#include <chrono>

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

// Convert a contiguous byte range to lowercase hex string
static std::string bytes_to_hex(const uint8_t* data, std::size_t len) {
    std::ostringstream oss;
    oss.setf(std::ios::hex, std::ios::basefield);
    oss.unsetf(std::ios::uppercase);
    oss.fill('0');
    for (std::size_t i = 0; i < len; ++i) {
        oss << std::setw(2) << static_cast<unsigned>(static_cast<uint8_t>(data[i]));
    }
    return oss.str();
}

static std::string hash_to_hex(const lt::sha1_hash& h) {
#if TORRENT_ABI_VERSION >= 3
    auto const* ptr = reinterpret_cast<const uint8_t*>(h.data());
    constexpr std::size_t kSha1Len = 20;
    return bytes_to_hex(ptr, kSha1Len);
#else
    auto const* ptr = reinterpret_cast<const uint8_t*>(h.data());
    constexpr std::size_t kSha1Len = 20;
    return bytes_to_hex(ptr, kSha1Len);
#endif
}

#if TORRENT_ABI_VERSION >= 3
static std::string info_hash_to_hex(const lt::info_hash_t& ih) {
    if (ih.has_v1()) {
        return hash_to_hex(ih.v1);
    }
    auto const* ptr = reinterpret_cast<const uint8_t*>(ih.v2.data());
    constexpr std::size_t kSha256Len = 32;
    return bytes_to_hex(ptr, kSha256Len);
}
#else
static std::string info_hash_to_hex(const lt::sha1_hash& h) {
    return hash_to_hex(h);
}
#endif

static NSArray<NSDictionary<NSString *, id> *>* extractFiles(const lt::torrent_handle& h) {
    if (!h.is_valid()) return @[];
    auto ti = h.torrent_file();
    if (!ti) return @[];
    auto const& fs = ti->files();
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:fs.num_files()];
    std::vector<std::int64_t> progress;
    h.file_progress(progress);
    for (int i = 0; i < fs.num_files(); ++i) {
        lt::file_index_t idx(i);
        std::string p = fs.file_path(idx);
        std::int64_t size = fs.file_size(idx);
        double prog = (size > 0 && i < (int)progress.size()) ? ((double)progress[i] / (double)size) : 0.0;
        [result addObject:@{
            @"index": @(i),
            @"path": [NSString stringWithUTF8String:p.c_str()] ?: @"",
            @"size": @(size),
            @"progress": @(prog)
        }];
    }
    return result;
}

@implementation TorrentWrapper {
    std::shared_ptr<lt::session> _session;
    std::thread _alertThread;
    std::atomic<bool> _running;
    
    // Callbacks
    TorrentProgressBlock _progressCb;
    TorrentErrorBlock _errorCb;
    TorrentMetadataBlock _metaCb;
    TorrentFinishedBlock _finishedCb;
    
    // Mutexes
    std::mutex _cbMutex;
    std::mutex _handleMutex;
    std::map<std::string, lt::torrent_handle> _handles;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        lt::settings_pack settings;
        settings.set_int(lt::settings_pack::alert_mask,
                         lt::alert_category::status |
                         lt::alert_category::error |
                         lt::alert_category::storage);
        settings.set_str(lt::settings_pack::user_agent, "FetchFlow/1.0");
        settings.set_bool(lt::settings_pack::enable_dht, true);
        settings.set_bool(lt::settings_pack::enable_lsd, true);
        settings.set_bool(lt::settings_pack::enable_upnp, true);
        settings.set_bool(lt::settings_pack::enable_natpmp, true);
        
        _session = std::make_shared<lt::session>(settings);
        _running = true;

        __weak TorrentWrapper *weakSelf = self;
        
        _alertThread = std::thread([weakSelf]() {
            auto lastUpdate = std::chrono::steady_clock::now();
            while (true) {
                TorrentWrapper *strongSelf = weakSelf;
                if (!strongSelf || !strongSelf->_running.load()) {
                    break;
                }
                
                auto now = std::chrono::steady_clock::now();
                if (std::chrono::duration_cast<std::chrono::milliseconds>(now - lastUpdate).count() >= 500) {
                    if (strongSelf->_session) {
                        strongSelf->_session->post_torrent_updates();
                    }
                    lastUpdate = now;
                }
                
                std::vector<lt::alert*> alerts;
                strongSelf->_session->wait_for_alert(std::chrono::milliseconds(500));
                strongSelf->_session->pop_alerts(&alerts);

                for (lt::alert* a : alerts) {
                    if (auto at = lt::alert_cast<lt::add_torrent_alert>(a)) {
                        std::string ih;
#if TORRENT_ABI_VERSION >= 3
                        ih = info_hash_to_hex(at->handle.info_hashes());
#else
                        ih = info_hash_to_hex(at->handle.info_hash());
#endif
                        {
                            std::lock_guard<std::mutex> lock(strongSelf->_handleMutex);
                            strongSelf->_handles[ih] = at->handle;
                        }
                        auto ti = at->handle.torrent_file();
                        if (ti) {
                            NSArray *files = extractFiles(at->handle);
                            int64_t totalSize = ti->total_size();
                            std::string name = !ti->name().empty() ? ti->name() : ih;
                            TorrentMetadataBlock metaCb = nil;
                            {
                                std::lock_guard<std::mutex> lock(strongSelf->_cbMutex);
                                if (strongSelf->_metaCb) metaCb = [strongSelf->_metaCb copy];
                            }
                            if (metaCb) {
                                NSString *ihStr = [NSString stringWithUTF8String:ih.c_str()];
                                NSString *nameStr = [NSString stringWithUTF8String:name.c_str()];
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    metaCb(ihStr, nameStr, totalSize, files);
                                });
                            }
                        }
                    }
                    else if (auto mr = lt::alert_cast<lt::metadata_received_alert>(a)) {
                        std::string ih;
#if TORRENT_ABI_VERSION >= 3
                        ih = info_hash_to_hex(mr->handle.info_hashes());
#else
                        ih = info_hash_to_hex(mr->handle.info_hash());
#endif
                        NSArray *files = extractFiles(mr->handle);
                        auto ti = mr->handle.torrent_file();
                        int64_t totalSize = ti ? ti->total_size() : 0;
                        std::string name = (ti && !ti->name().empty()) ? ti->name() : ih;
                        TorrentMetadataBlock metaCb = nil;
                        {
                            std::lock_guard<std::mutex> lock(strongSelf->_cbMutex);
                            if (strongSelf->_metaCb) metaCb = [strongSelf->_metaCb copy];
                        }
                        if (metaCb) {
                            NSString *ihStr = [NSString stringWithUTF8String:ih.c_str()];
                            NSString *nameStr = [NSString stringWithUTF8String:name.c_str()];
                            dispatch_async(dispatch_get_main_queue(), ^{
                                metaCb(ihStr, nameStr, totalSize, files);
                            });
                        }
                    }
                    else if (auto tf = lt::alert_cast<lt::torrent_finished_alert>(a)) {
                        std::string ih;
#if TORRENT_ABI_VERSION >= 3
                        ih = info_hash_to_hex(tf->handle.info_hashes());
#else
                        ih = info_hash_to_hex(tf->handle.info_hash());
#endif
                        TorrentFinishedBlock finCb = nil;
                        {
                            std::lock_guard<std::mutex> lock(strongSelf->_cbMutex);
                            if (strongSelf->_finishedCb) finCb = [strongSelf->_finishedCb copy];
                        }
                        if (finCb) {
                            NSString *ihStr = [NSString stringWithUTF8String:ih.c_str()];
                            dispatch_async(dispatch_get_main_queue(), ^{
                                finCb(ihStr);
                            });
                        }
                    }
                    else if (auto st = lt::alert_cast<lt::state_update_alert>(a)) {
                        TorrentProgressBlock cbCopy = nil;
                        {
                            std::lock_guard<std::mutex> lock(strongSelf->_cbMutex);
                            if (strongSelf->_progressCb) cbCopy = [strongSelf->_progressCb copy];
                        }
                        if (cbCopy) {
                            struct StatusItem {
                                std::string ih;
                                std::string name;
                                double progress;
                                int64_t dl;
                                int64_t ul;
                                int64_t totalDone;
                                int64_t totalSize;
                                std::string state;
                                int peers;
                                int seeds;
                            };
                            std::vector<StatusItem> items;
                            items.reserve(st->status.size());
                            for (auto const& status : st->status) {
                                std::string ih;
#if TORRENT_ABI_VERSION >= 3
                                ih = info_hash_to_hex(status.info_hashes);
#else
                                ih = info_hash_to_hex(status.info_hash);
#endif
                                std::string stateStr;
                                if (status.flags & lt::torrent_flags::paused) {
                                    stateStr = "Paused";
                                } else {
                                    stateStr = [torrentStateToString(status.state) UTF8String];
                                }
                                items.push_back({
                                    ih,
                                    status.name.empty() ? ih : status.name,
                                    status.progress,
                                    status.download_payload_rate,
                                    status.upload_payload_rate,
                                    status.total_done,
                                    status.total_wanted > 0 ? status.total_wanted : status.total_done,
                                    stateStr,
                                    status.num_peers,
                                    status.num_seeds
                                });
                            }

                            dispatch_async(dispatch_get_main_queue(), ^{
                                for (auto const& item : items) {
                                    cbCopy([NSString stringWithUTF8String:item.ih.c_str()],
                                           [NSString stringWithUTF8String:item.name.c_str()],
                                           item.progress,
                                           item.dl,
                                           item.ul,
                                           item.totalDone,
                                           item.totalSize,
                                           [NSString stringWithUTF8String:item.state.c_str()],
                                           item.peers,
                                           item.seeds);
                                }
                            });
                        }
                    }
                    else if (auto te = lt::alert_cast<lt::torrent_error_alert>(a)) {
                        TorrentErrorBlock cbCopy = nil;
                        {
                            std::lock_guard<std::mutex> lock(strongSelf->_cbMutex);
                            if (strongSelf->_errorCb) cbCopy = [strongSelf->_errorCb copy];
                        }
                        if (cbCopy) {
                            std::string ih;
#if TORRENT_ABI_VERSION >= 3
                            ih = info_hash_to_hex(te->handle.info_hashes());
#else
                            ih = info_hash_to_hex(te->handle.info_hash());
#endif
                            std::string msg = te->error.message();
                            dispatch_async(dispatch_get_main_queue(), ^{
                                cbCopy([NSString stringWithUTF8String:ih.c_str()],
                                       [NSString stringWithUTF8String:msg.c_str()]);
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

- (void)setMetadataCallback:(TorrentMetadataBlock)cb {
    std::lock_guard<std::mutex> lock(_cbMutex);
    _metaCb = [cb copy];
}

- (void)setFinishedCallback:(TorrentFinishedBlock)cb {
    std::lock_guard<std::mutex> lock(_cbMutex);
    _finishedCb = [cb copy];
}

- (nullable NSString *)addMagnet:(NSString *)magnet savePath:(NSString *)path {
    if (magnet == nil || [magnet length] == 0) return nil;
    try {
        lt::add_torrent_params params = lt::parse_magnet_uri([magnet UTF8String]);
        params.save_path = [path UTF8String];
        
        std::string ih;
#if TORRENT_ABI_VERSION >= 3
        ih = info_hash_to_hex(params.info_hashes);
#else
        ih = info_hash_to_hex(params.info_hash);
#endif
        lt::torrent_handle h = _session->add_torrent(std::move(params));
        {
            std::lock_guard<std::mutex> lock(_handleMutex);
            _handles[ih] = h;
        }
        return [NSString stringWithUTF8String:ih.c_str()];
    } catch (std::exception &e) {
        NSLog(@"addMagnet failed: %s", e.what());
        return nil;
    }
}

- (nullable NSString *)addTorrentFile:(NSString *)filePath savePath:(NSString *)path {
    if (filePath == nil || [filePath length] == 0) return nil;
    try {
        lt::add_torrent_params params;
        params.ti = std::make_shared<lt::torrent_info>(std::string([filePath UTF8String]));
        params.save_path = [path UTF8String];
        
        std::string ih;
#if TORRENT_ABI_VERSION >= 3
        ih = info_hash_to_hex(params.ti->info_hashes());
#else
        ih = info_hash_to_hex(params.ti->info_hash());
#endif
        lt::torrent_handle h = _session->add_torrent(std::move(params));
        {
            std::lock_guard<std::mutex> lock(_handleMutex);
            _handles[ih] = h;
        }
        return [NSString stringWithUTF8String:ih.c_str()];
    } catch (std::exception &e) {
        NSLog(@"addTorrentFile failed: %s", e.what());
        return nil;
    }
}

- (void)pauseTorrent:(NSString *)infoHash {
    std::lock_guard<std::mutex> lock(_handleMutex);
    auto it = _handles.find([infoHash UTF8String]);
    if (it != _handles.end() && it->second.is_valid()) {
        it->second.unset_flags(lt::torrent_flags::auto_managed);
        it->second.pause();
    }
}

- (void)resumeTorrent:(NSString *)infoHash {
    std::lock_guard<std::mutex> lock(_handleMutex);
    auto it = _handles.find([infoHash UTF8String]);
    if (it != _handles.end() && it->second.is_valid()) {
        it->second.resume();
        it->second.set_flags(lt::torrent_flags::auto_managed);
    }
}

- (void)removeTorrent:(NSString *)infoHash deleteFiles:(BOOL)deleteFiles {
    std::lock_guard<std::mutex> lock(_handleMutex);
    auto it = _handles.find([infoHash UTF8String]);
    if (it != _handles.end() && it->second.is_valid()) {
        _session->remove_torrent(it->second, deleteFiles ? lt::session::delete_files : lt::remove_flags_t{});
        _handles.erase(it);
    }
}

- (void)setFilePriority:(int)fileIndex priority:(int)priority infoHash:(NSString *)infoHash {
    std::lock_guard<std::mutex> lock(_handleMutex);
    auto it = _handles.find([infoHash UTF8String]);
    if (it != _handles.end() && it->second.is_valid()) {
        it->second.file_priority(lt::file_index_t(fileIndex), lt::download_priority_t(priority));
    }
}

- (void)stopAll {
    {
        std::lock_guard<std::mutex> lock(_cbMutex);
        _progressCb = nil;
        _errorCb = nil;
        _metaCb = nil;
        _finishedCb = nil;
    }

    _running = false;
    if (_alertThread.joinable()) {
        _alertThread.join();
    }
    
    {
        std::lock_guard<std::mutex> lock(_handleMutex);
        _handles.clear();
    }
    _session.reset();
}

- (void)dealloc {
    [self stopAll];
}

@end
