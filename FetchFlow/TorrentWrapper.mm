#import "TorrentWrapper.h"

// libtorrent
#include <libtorrent/session.hpp>
#include <libtorrent/session_params.hpp>
#include <libtorrent/add_torrent_params.hpp>
#include <libtorrent/magnet_uri.hpp>
#include <libtorrent/torrent_status.hpp>
#include <libtorrent/torrent_info.hpp>
#include <libtorrent/alert_types.hpp>
#include <libtorrent/alert.hpp>
#include <libtorrent/settings_pack.hpp>
#include <libtorrent/info_hash.hpp>
#include <libtorrent/sha1_hash.hpp>
#include <libtorrent/read_resume_data.hpp>
#include <libtorrent/write_resume_data.hpp>
#include <libtorrent/span.hpp>

// Standard library
#include <algorithm>
#include <atomic>
#include <chrono>
#include <climits>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <iterator>
#include <map>
#include <mutex>
#include <sstream>
#include <string>
#include <thread>
#include <vector>

using namespace lt;

// MARK: - Helpers

static NSString *nsstring(std::string const& value) {
    NSString *result = [NSString stringWithUTF8String:value.c_str()];
    return result ?: @"";
}

static std::string utf8(NSString *value) {
    if (value == nil) return {};
    const char *bytes = value.UTF8String;
    return bytes ? std::string(bytes) : std::string();
}

static bool bool_setting(NSDictionary<NSString *, id> *settings, NSString *key, bool fallback) {
    id value = settings[key];
    if (value == nil || value == (id)[NSNull null]) return fallback;
    return [value boolValue];
}

static int int_setting(NSDictionary<NSString *, id> *settings, NSString *key, int fallback) {
    id value = settings[key];
    if (value == nil || value == (id)[NSNull null]) return fallback;
    return [value intValue];
}

static std::string state_to_string(lt::torrent_status::state_t state) {
    switch (state) {
        case lt::torrent_status::checking_files: return "Checking";
        case lt::torrent_status::downloading_metadata: return "Fetching Metadata";
        case lt::torrent_status::downloading: return "Downloading";
        case lt::torrent_status::finished: return "Finished";
        case lt::torrent_status::seeding: return "Seeding";
        case lt::torrent_status::checking_resume_data: return "Checking";
        default: return "Downloading";
    }
}

// Convert a contiguous byte range to lowercase hex.
static std::string bytes_to_hex(const std::uint8_t *data, std::size_t length) {
    static const char *digits = "0123456789abcdef";
    std::string result;
    result.reserve(length * 2);
    for (std::size_t i = 0; i < length; ++i) {
        result.push_back(digits[(data[i] >> 4) & 0x0f]);
        result.push_back(digits[data[i] & 0x0f]);
    }
    return result;
}

// libtorrent 2.0 exposes both v1 (SHA-1) and v2 (SHA-256) info hashes. Use the
// v1 hash whenever it exists (hybrid torrents are traditionally keyed by v1),
// otherwise use the full 64-character v2 hash. This avoids the deprecated
// `info_hash` fields, which hold a truncated 20-byte v2 hash.
static std::string info_hash_to_hex(lt::info_hash_t const& hashes) {
    if (hashes.has_v1()) {
        return bytes_to_hex(reinterpret_cast<const std::uint8_t *>(hashes.v1.data()), 20);
    }
    if (hashes.has_v2()) {
        return bytes_to_hex(reinterpret_cast<const std::uint8_t *>(hashes.v2.data()), 32);
    }
    return {};
}

static std::string handle_hash(lt::torrent_handle const& handle) {
    if (!handle.is_valid()) return {};
    return info_hash_to_hex(handle.info_hashes());
}

static std::string resume_path(std::string const& directory, std::string const& infoHash) {
    return directory + "/" + infoHash + ".resume";
}

static std::vector<char> read_file(std::string const& path) {
    if (path.empty()) return {};
    std::ifstream input(path, std::ios::binary);
    if (!input) return {};
    return std::vector<char>(std::istreambuf_iterator<char>(input),
                             std::istreambuf_iterator<char>());
}

static bool write_file_atomic(std::string const& path, std::vector<char> const& data) {
    if (path.empty()) return false;
    std::string temporary = path + ".tmp";
    {
        std::ofstream output(temporary, std::ios::binary | std::ios::trunc);
        if (!output) return false;
        output.write(data.data(), static_cast<std::streamsize>(data.size()));
        output.close();
        if (!output) {
            std::remove(temporary.c_str());
            return false;
        }
    }
    if (std::rename(temporary.c_str(), path.c_str()) != 0) {
        std::remove(temporary.c_str());
        return false;
    }
    return true;
}

static void write_resume_data_to_directory(std::string const& directory,
                                           lt::add_torrent_params const& params) {
    std::string hash = info_hash_to_hex(params.info_hashes);
    if (hash.empty()) return;
    try {
        std::vector<char> buffer = lt::write_resume_data_buf(params);
        if (buffer.empty()) return;
        write_file_atomic(resume_path(directory, hash), buffer);
    } catch (std::exception const& e) {
        NSLog(@"Failed to serialize resume data: %s", e.what());
    }
}

// Merges saved fast-resume data into the add_torrent_params created from a
// magnet or .torrent file. The fresh torrent_info (if any), info hashes and
// save path win over the stored values.
static bool merge_resume_data(std::string const& directory,
                              std::string const& infoHash,
                              lt::add_torrent_params& params) {
    if (infoHash.empty()) return false;
    std::vector<char> buffer = read_file(resume_path(directory, infoHash));
    if (buffer.empty()) return false;

    try {
        lt::error_code ec;
        lt::add_torrent_params resume = lt::read_resume_data(
            lt::span<char const>(buffer.data(), buffer.size()), ec);
        if (ec) return false;

        resume.info_hashes = params.info_hashes;
        resume.save_path = params.save_path;
        if (params.ti) resume.ti = params.ti;
        if (resume.name.empty()) resume.name = params.name;
        if (resume.trackers.empty()) resume.trackers = params.trackers;

        params = std::move(resume);
        return true;
    } catch (std::exception const& e) {
        NSLog(@"Failed to read resume data for %s: %s", infoHash.c_str(), e.what());
        return false;
    }
}

static lt::settings_pack make_default_settings() {
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
    return settings;
}

static NSArray<NSDictionary<NSString *, id> *> *extract_files(lt::torrent_handle const& handle) {
    if (!handle.is_valid()) return @[];
    auto info = handle.torrent_file();
    if (!info) return @[];

    try {
        auto const& files = info->files();
        NSMutableArray<NSDictionary<NSString *, id> *> *result =
            [NSMutableArray arrayWithCapacity:static_cast<NSUInteger>(files.num_files())];

        std::vector<std::int64_t> progress;
        handle.file_progress(progress);
        std::vector<lt::download_priority_t> priorities = handle.get_file_priorities();

        for (int index = 0; index < files.num_files(); ++index) {
            lt::file_index_t fileIndex(index);
            std::string path = files.file_path(fileIndex);
            std::int64_t size = files.file_size(fileIndex);
            double fileProgress = 0.0;
            if (size > 0 && index < static_cast<int>(progress.size())) {
                fileProgress = static_cast<double>(progress[static_cast<std::size_t>(index)])
                             / static_cast<double>(size);
            }

            int priority = 4;
            if (index < static_cast<int>(priorities.size())) {
                priority = static_cast<int>(
                    static_cast<std::uint8_t>(priorities[static_cast<std::size_t>(index)]));
            }

            [result addObject:@{
                @"index": @(index),
                @"path": nsstring(path),
                @"size": @(size),
                @"progress": @(fileProgress),
                @"priority": @(priority)
            }];
        }
        return result;
    } catch (std::exception const& e) {
        NSLog(@"Failed to read file list: %s", e.what());
        return @[];
    }
}

// MARK: - Private interface

@interface TorrentWrapper ()
- (void)setupSupportDirectories;
- (void)saveAllResumeData;
- (void)saveSessionState;
- (void)setLastAddError:(nullable NSString *)message;
@end

// MARK: - Implementation

@implementation TorrentWrapper {
    std::shared_ptr<lt::session> _session;
    std::thread _alertThread;
    std::atomic<bool> _running;
    std::atomic<bool> _stopped;
    std::atomic<bool> _autoStartNewTorrents;

    TorrentProgressBlock _progressCb;
    TorrentErrorBlock _errorCb;
    TorrentMetadataBlock _metaCb;
    TorrentFinishedBlock _finishedCb;
    TorrentRemovedBlock _removedCb;

    std::mutex _cbMutex;
    std::mutex _handleMutex;
    std::mutex _addErrorMutex;
    NSString *_lastAddError;
    std::map<std::string, lt::torrent_handle> _handles;

    std::string _supportDir;
    std::string _resumeDir;
    std::string _sessionStatePath;
}

- (instancetype)init {
    self = [super init];
    if (self == nil) return nil;

    _running = false;
    _stopped = false;
    _autoStartNewTorrents = true;

    [self setupSupportDirectories];

    lt::session_params params(make_default_settings());

    // Restore DHT routing table and session settings from the previous run.
    std::vector<char> stateBuffer = read_file(_sessionStatePath);
    if (!stateBuffer.empty()) {
        try {
            auto saved = lt::read_session_params(
                lt::span<char const>(stateBuffer.data(), stateBuffer.size()));
            params = std::move(saved);
        } catch (std::exception const& e) {
            NSLog(@"Failed to restore session state: %s", e.what());
        }
    }

    // Ensure alerts and identification are always configured, even if the
    // saved state predates a change to these defaults.
    params.settings.set_int(lt::settings_pack::alert_mask,
                            lt::alert_category::status |
                            lt::alert_category::error |
                            lt::alert_category::storage);
    params.settings.set_str(lt::settings_pack::user_agent, "FetchFlow/1.0");

    // Never let a stale session-state file make the initial session bind a
    // privileged or half-typed port. Use OS-assigned ports until Swift applies
    // the live UI settings via applySettings: (immediately after init).
    params.settings.set_str(lt::settings_pack::listen_interfaces,
                            "0.0.0.0:0,[::]:0");

    _session = std::make_shared<lt::session>(std::move(params));
    _running = true;

    __weak TorrentWrapper *weakSelf = self;
    _alertThread = std::thread([weakSelf]() {
        auto lastUpdate = std::chrono::steady_clock::now();
        auto lastResumeSnapshot = std::chrono::steady_clock::now();

        while (true) {
            TorrentWrapper *strongSelf = weakSelf;
            if (strongSelf == nil || !strongSelf->_running.load()) break;
            if (!strongSelf->_session) break;

            auto now = std::chrono::steady_clock::now();
            if (std::chrono::duration_cast<std::chrono::milliseconds>(now - lastUpdate).count() >= 500) {
                strongSelf->_session->post_torrent_updates();
                lastUpdate = now;
            }

            // Periodically snapshot active torrents so an unexpected exit
            // loses at most about a minute of resume state.
            if (std::chrono::duration_cast<std::chrono::seconds>(now - lastResumeSnapshot).count() >= 60) {
                std::vector<lt::torrent_handle> handles;
                {
                    std::lock_guard<std::mutex> lock(strongSelf->_handleMutex);
                    handles.reserve(strongSelf->_handles.size());
                    for (auto const& entry : strongSelf->_handles) {
                        handles.push_back(entry.second);
                    }
                }

                for (auto const& handle : handles) {
                    if (!handle.is_valid()) continue;
                    try {
                        if (handle.need_save_resume_data(lt::torrent_handle::only_if_modified)) {
                            handle.save_resume_data(lt::torrent_handle::only_if_modified
                                | lt::torrent_handle::save_info_dict);
                        }
                    } catch (std::exception const& e) {
                        NSLog(@"periodic save_resume_data failed: %s", e.what());
                    }
                }
                lastResumeSnapshot = now;
            }

            std::vector<lt::alert *> alerts;
            strongSelf->_session->wait_for_alert(std::chrono::milliseconds(500));
            strongSelf->_session->pop_alerts(&alerts);

            @autoreleasepool {
                for (lt::alert *alert : alerts) {
                    auto postError = [strongSelf](std::string const& hash, std::string const& message) {
                        TorrentErrorBlock callback = nil;
                        {
                            std::lock_guard<std::mutex> lock(strongSelf->_cbMutex);
                            if (strongSelf->_errorCb) callback = [strongSelf->_errorCb copy];
                        }
                        if (callback == nil) return;
                        NSString *hashString = nsstring(hash);
                        NSString *messageString = nsstring(message);
                        dispatch_async(dispatch_get_main_queue(), ^{
                            callback(hashString, messageString);
                        });
                    };

                    auto postRemoved = [strongSelf](std::string const& hash) {
                        TorrentRemovedBlock callback = nil;
                        {
                            std::lock_guard<std::mutex> lock(strongSelf->_cbMutex);
                            if (strongSelf->_removedCb) callback = [strongSelf->_removedCb copy];
                        }
                        if (callback == nil) return;
                        NSString *hashString = nsstring(hash);
                        dispatch_async(dispatch_get_main_queue(), ^{
                            callback(hashString);
                        });
                    };

                    if (auto added = lt::alert_cast<lt::add_torrent_alert>(alert)) {
                        std::string hash = info_hash_to_hex(added->params.info_hashes);
                        if (hash.empty()) hash = handle_hash(added->handle);

                        if (added->error) {
                            postError(hash, added->error.message());
                            continue;
                        }

                        if (hash.empty()) {
                            NSLog(@"add_torrent_alert without a usable info hash");
                            continue;
                        }

                        if (added->handle.is_valid()) {
                            std::lock_guard<std::mutex> lock(strongSelf->_handleMutex);
                            strongSelf->_handles[hash] = added->handle;
                        }

                        auto info = added->handle.torrent_file();
                        if (info) {
                            NSArray *files = extract_files(added->handle);
                            std::int64_t totalSize = info->total_size();
                            std::string name = !info->name().empty() ? info->name() : hash;

                            TorrentMetadataBlock callback = nil;
                            {
                                std::lock_guard<std::mutex> lock(strongSelf->_cbMutex);
                                if (strongSelf->_metaCb) callback = [strongSelf->_metaCb copy];
                            }
                            if (callback) {
                                NSString *hashString = nsstring(hash);
                                NSString *nameString = nsstring(name);
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    callback(hashString, nameString, totalSize, files);
                                });
                            }

                            // Persist an initial resume record as soon as we have
                            // metadata. This also makes an unexpected exit much
                            // cheaper to recover from.
                            try {
                                added->handle.save_resume_data(lt::torrent_handle::save_info_dict);
                            } catch (std::exception const& e) {
                                NSLog(@"save_resume_data(add) failed: %s", e.what());
                            }
                        }
                    }
                    else if (auto metadata = lt::alert_cast<lt::metadata_received_alert>(alert)) {
                        std::string hash = handle_hash(metadata->handle);
                        NSArray *files = extract_files(metadata->handle);
                        auto info = metadata->handle.torrent_file();
                        std::int64_t totalSize = info ? info->total_size() : 0;
                        std::string name = (info && !info->name().empty()) ? info->name() : hash;

                        TorrentMetadataBlock callback = nil;
                        {
                            std::lock_guard<std::mutex> lock(strongSelf->_cbMutex);
                            if (strongSelf->_metaCb) callback = [strongSelf->_metaCb copy];
                        }
                        if (callback) {
                            NSString *hashString = nsstring(hash);
                            NSString *nameString = nsstring(name);
                            dispatch_async(dispatch_get_main_queue(), ^{
                                callback(hashString, nameString, totalSize, files);
                            });
                        }

                        // Persist the info-dict as soon as metadata arrives, so
                        // the next launch can add the torrent from resume data
                        // alone (and keeps file priorities/trackers).
                        try {
                            metadata->handle.save_resume_data(lt::torrent_handle::save_info_dict);
                        } catch (std::exception const& e) {
                            NSLog(@"save_resume_data(metadata) failed: %s", e.what());
                        }
                    }
                    else if (auto finished = lt::alert_cast<lt::torrent_finished_alert>(alert)) {
                        std::string hash = handle_hash(finished->handle);

                        TorrentFinishedBlock callback = nil;
                        {
                            std::lock_guard<std::mutex> lock(strongSelf->_cbMutex);
                            if (strongSelf->_finishedCb) callback = [strongSelf->_finishedCb copy];
                        }
                        if (callback) {
                            NSString *hashString = nsstring(hash);
                            dispatch_async(dispatch_get_main_queue(), ^{
                                callback(hashString);
                            });
                        }

                        try {
                            finished->handle.save_resume_data(lt::torrent_handle::save_info_dict);
                        } catch (std::exception const& e) {
                            NSLog(@"save_resume_data(finished) failed: %s", e.what());
                        }
                    }
                    else if (auto stateUpdate = lt::alert_cast<lt::state_update_alert>(alert)) {
                        TorrentProgressBlock callback = nil;
                        {
                            std::lock_guard<std::mutex> lock(strongSelf->_cbMutex);
                            if (strongSelf->_progressCb) callback = [strongSelf->_progressCb copy];
                        }
                        if (callback == nil) continue;

                        struct StatusItem {
                            std::string hash;
                            std::string name;
                            double progress;
                            std::int64_t downloadRate;
                            std::int64_t uploadRate;
                            std::int64_t totalDone;
                            std::int64_t totalUploaded;
                            std::int64_t totalSize;
                            std::int64_t totalWanted;
                            std::int64_t totalWantedDone;
                            std::string state;
                            int peers;
                            int seeds;
                        };

                        std::vector<StatusItem> items;
                        items.reserve(stateUpdate->status.size());

                        for (auto const& status : stateUpdate->status) {
                            std::string hash = info_hash_to_hex(status.info_hashes);
                            bool paused = static_cast<bool>(status.flags & lt::torrent_flags::paused);
                            bool autoManaged = static_cast<bool>(status.flags & lt::torrent_flags::auto_managed);
                            bool hasError = static_cast<bool>(status.errc);

                            std::string state;
                            if (hasError) {
                                // Keep the paused state; the Swift layer keeps
                                // the error message visible in this case.
                                state = "Paused";
                            } else if (paused && autoManaged) {
                                // Auto-managed torrents are paused by the
                                // session's queue when their limits are reached.
                                state = "Queued";
                            } else if (paused) {
                                state = "Paused";
                            } else {
                                state = state_to_string(status.state);
                            }

                            items.push_back({
                                hash,
                                status.name.empty() ? hash : status.name,
                                status.progress,
                                status.download_payload_rate,
                                status.upload_payload_rate,
                                status.total_done,
                                status.total_upload,
                                status.total,
                                status.total_wanted,
                                status.total_wanted_done,
                                state,
                                status.num_peers,
                                status.num_seeds
                            });
                        }

                        dispatch_async(dispatch_get_main_queue(), ^{
                            for (auto const& item : items) {
                                callback(nsstring(item.hash),
                                         nsstring(item.name),
                                         item.progress,
                                         item.downloadRate,
                                         item.uploadRate,
                                         item.totalDone,
                                         item.totalUploaded,
                                         item.totalSize,
                                         item.totalWanted,
                                         item.totalWantedDone,
                                         nsstring(item.state),
                                         item.peers,
                                         item.seeds);
                            }
                        });
                    }
                    else if (auto error = lt::alert_cast<lt::torrent_error_alert>(alert)) {
                        postError(handle_hash(error->handle), error->error.message());
                    }
                    else if (auto fileError = lt::alert_cast<lt::file_error_alert>(alert)) {
                        std::string message = fileError->error.message();
                        char const *filename = fileError->filename();
                        if (filename != nullptr && *filename != '\0') {
                            message += " (";
                            message += filename;
                            message += ")";
                        }
                        postError(handle_hash(fileError->handle), message);
                    }
                    else if (auto metadataError = lt::alert_cast<lt::metadata_failed_alert>(alert)) {
                        postError(handle_hash(metadataError->handle), metadataError->error.message());
                    }
                    else if (auto removed = lt::alert_cast<lt::torrent_removed_alert>(alert)) {
                        std::string hash = info_hash_to_hex(removed->info_hashes);
                        if (hash.empty()) hash = handle_hash(removed->handle);

                        bool newerTorrentExists = false;
                        {
                            std::lock_guard<std::mutex> lock(strongSelf->_handleMutex);
                            auto found = strongSelf->_handles.find(hash);
                            if (found != strongSelf->_handles.end()) {
                                if (removed->handle.is_valid()
                                    && found->second.is_valid()
                                    && found->second.id() != removed->handle.id()) {
                                    // The same torrent was removed and re-added
                                    // before this alert arrived. Keep the new handle.
                                    newerTorrentExists = true;
                                } else {
                                    strongSelf->_handles.erase(found);
                                }
                            }
                        }

                        if (newerTorrentExists) continue;

                        if (!hash.empty() && !strongSelf->_resumeDir.empty()) {
                            std::remove(resume_path(strongSelf->_resumeDir, hash).c_str());
                        }
                        postRemoved(hash);
                    }
                    else if (auto deleteError = lt::alert_cast<lt::torrent_delete_failed_alert>(alert)) {
                        std::string hash = info_hash_to_hex(deleteError->info_hashes);
                        if (hash.empty()) hash = handle_hash(deleteError->handle);
                        postError(hash, deleteError->error.message());
                    }
                    else if (auto listenError = lt::alert_cast<lt::listen_failed_alert>(alert)) {
                        std::string message = listenError->message();
                        std::string errorMessage = listenError->error.message();
                        NSLog(@"libtorrent listen_failed: %s", message.c_str());

                        // IPv6 link-local/VPN interfaces can reject a bind for
                        // reasons that do not affect the main IPv4 listener
                        // (for example utun link-local addresses). Log those,
                        // but only surface a real port conflict in the UI.
                        bool critical = errorMessage.find("in use") != std::string::npos;
                        if (critical) {
                            postError("", "Network listener: " + message);
                        }
                    }
                    else if (auto resumeData = lt::alert_cast<lt::save_resume_data_alert>(alert)) {
                        write_resume_data_to_directory(strongSelf->_resumeDir, resumeData->params);
                    }
                    else if (auto resumeError = lt::alert_cast<lt::save_resume_data_failed_alert>(alert)) {
                        NSLog(@"save_resume_data failed: %s", resumeError->error.message().c_str());
                    }
                    else if (auto fastresume = lt::alert_cast<lt::fastresume_rejected_alert>(alert)) {
                        NSLog(@"fastresume rejected: %s", fastresume->error.message().c_str());
                    }
                    else if (auto trackerError = lt::alert_cast<lt::tracker_error_alert>(alert)) {
                        NSLog(@"tracker error: %s", trackerError->message().c_str());
                    }
                    else if (auto portmapError = lt::alert_cast<lt::portmap_error_alert>(alert)) {
                        NSLog(@"port mapping error: %s", portmapError->message().c_str());
                    }
                    else if (auto dropped = lt::alert_cast<lt::alerts_dropped_alert>(alert)) {
                        NSLog(@"libtorrent dropped alerts: %s", dropped->message().c_str());
                    }
                }
            }
        }
    });

    return self;
}

- (void)setupSupportDirectories {
    NSString *support = nil;

    const char *override = std::getenv("FETCHFLOW_SUPPORT_DIR");
    if (override != nullptr && *override != '\0') {
        support = [NSString stringWithUTF8String:override];
    }

    if (support == nil || support.length == 0) {
        NSArray<NSString *> *paths = NSSearchPathForDirectoriesInDomains(
            NSApplicationSupportDirectory, NSUserDomainMask, YES);
        NSString *base = paths.firstObject;
        if (base == nil) base = NSTemporaryDirectory();
        NSString *bundle = [[NSBundle mainBundle] bundleIdentifier];
        if (bundle == nil || bundle.length == 0) bundle = @"com.ios.FetchFlow";
        support = [base stringByAppendingPathComponent:bundle];
    }

    NSString *resume = [support stringByAppendingPathComponent:@"resume"];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error = nil;
    if (![fileManager createDirectoryAtPath:resume
                withIntermediateDirectories:YES
                                 attributes:nil
                                      error:&error]) {
        NSLog(@"Failed to create resume directory %@: %@", resume, error);
        NSString *fallback = [NSTemporaryDirectory() stringByAppendingPathComponent:@"FetchFlow"];
        support = fallback;
        resume = [fallback stringByAppendingPathComponent:@"resume"];
        [fileManager createDirectoryAtPath:resume
               withIntermediateDirectories:YES
                                attributes:nil
                                     error:nil];
    }

    _supportDir = utf8(support);
    _resumeDir = utf8(resume);
    _sessionStatePath = utf8([support stringByAppendingPathComponent:@"session.state"]);
}

// MARK: - Settings

- (void)applySettings:(NSDictionary<NSString *, id> *)settings {
    if (settings == nil) return;

    lt::settings_pack pack;

    bool enableDHT = bool_setting(settings, @"enableDHT", true);
    bool enableLSD = bool_setting(settings, @"enableLSD", true);
    bool enableUPnP = bool_setting(settings, @"enableUPnP", true);
    bool randomPort = bool_setting(settings, @"randomPort", true);
    bool limitDownload = bool_setting(settings, @"limitDownloadRate", false);
    bool limitUpload = bool_setting(settings, @"limitUploadRate", false);
    bool autoStart = bool_setting(settings, @"autoStartDownloads", true);

    int port = int_setting(settings, @"customPort", 6881);
    // Ports below 1024 require root; fall back instead of provoking a
    // permission-denied listen failure while the user is still typing.
    if (port < 1024 || port > 65535) port = 6881;

    int maxActive = int_setting(settings, @"maxActiveTorrents", 5);
    maxActive = std::clamp(maxActive, 1, 50);

    long long downloadKB = std::max<long long>(0, int_setting(settings, @"maxDownloadRateKB", 5000));
    long long uploadKB = std::max<long long>(0, int_setting(settings, @"maxUploadRateKB", 1000));
    long long downloadBytes = std::min<long long>(downloadKB * 1024, INT_MAX);
    long long uploadBytes = std::min<long long>(uploadKB * 1024, INT_MAX);

    pack.set_int(lt::settings_pack::alert_mask,
                 lt::alert_category::status |
                 lt::alert_category::error |
                 lt::alert_category::storage);
    pack.set_str(lt::settings_pack::user_agent, "FetchFlow/1.0");
    pack.set_bool(lt::settings_pack::enable_dht, enableDHT);
    pack.set_bool(lt::settings_pack::enable_lsd, enableLSD);
    pack.set_bool(lt::settings_pack::enable_upnp, enableUPnP);
    pack.set_bool(lt::settings_pack::enable_natpmp, enableUPnP);

    if (randomPort) {
        pack.set_str(lt::settings_pack::listen_interfaces, "0.0.0.0:0,[::]:0");
    } else {
        std::ostringstream interfaces;
        interfaces << "0.0.0.0:" << port << ",[::]:" << port;
        pack.set_str(lt::settings_pack::listen_interfaces, interfaces.str());
    }

    pack.set_int(lt::settings_pack::download_rate_limit,
                 limitDownload ? static_cast<int>(downloadBytes) : 0);
    pack.set_int(lt::settings_pack::upload_rate_limit,
                 limitUpload ? static_cast<int>(uploadBytes) : 0);

    pack.set_int(lt::settings_pack::active_downloads, maxActive);
    pack.set_int(lt::settings_pack::active_limit, std::max(15, maxActive + 5));

    _autoStartNewTorrents = autoStart;

    if (_session) {
        _session->apply_settings(std::move(pack));
    }
}

// MARK: - Add errors

- (void)setLastAddError:(nullable NSString *)message {
    std::lock_guard<std::mutex> lock(_addErrorMutex);
    _lastAddError = [message copy];
}

- (nullable NSString *)lastAddError {
    std::lock_guard<std::mutex> lock(_addErrorMutex);
    return [_lastAddError copy];
}

// MARK: - Callbacks

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

- (void)setRemovedCallback:(TorrentRemovedBlock)cb {
    std::lock_guard<std::mutex> lock(_cbMutex);
    _removedCb = [cb copy];
}

// MARK: - Adding torrents

- (nullable NSString *)addMagnet:(NSString *)magnet savePath:(NSString *)path {
    [self setLastAddError:nil];

    if (magnet == nil || magnet.length == 0) {
        [self setLastAddError:@"Magnet link is empty."];
        return nil;
    }
    if (_session == nil) {
        [self setLastAddError:@"The torrent session is not available."];
        return nil;
    }

    try {
        lt::add_torrent_params params = lt::parse_magnet_uri(utf8(magnet));
        params.save_path = utf8(path);

        std::string hash = info_hash_to_hex(params.info_hashes);
        if (hash.empty()) {
            [self setLastAddError:@"The magnet link has no usable info hash."];
            return nil;
        }

        bool restored = merge_resume_data(_resumeDir, hash, params);
        if (!restored && !_autoStartNewTorrents.load()) {
            params.flags |= lt::torrent_flags::paused;
            params.flags &= ~lt::torrent_flags::auto_managed;
        }

        hash = info_hash_to_hex(params.info_hashes);
        lt::torrent_handle handle = _session->add_torrent(std::move(params));
        {
            std::lock_guard<std::mutex> lock(_handleMutex);
            _handles[hash] = handle;
        }
        return nsstring(hash);
    } catch (std::exception const& e) {
        NSLog(@"addMagnet failed: %s", e.what());
        [self setLastAddError:[NSString stringWithFormat:@"%s", e.what()]];
        return nil;
    }
}

- (nullable NSString *)addTorrentFile:(NSString *)filePath savePath:(NSString *)path {
    [self setLastAddError:nil];

    if (filePath == nil || filePath.length == 0) {
        [self setLastAddError:@"Torrent file path is empty."];
        return nil;
    }
    if (_session == nil) {
        [self setLastAddError:@"The torrent session is not available."];
        return nil;
    }

    try {
        lt::add_torrent_params params;
        params.ti = std::make_shared<lt::torrent_info>(utf8(filePath));
        params.save_path = utf8(path);
        params.info_hashes = params.ti->info_hashes();

        std::string hash = info_hash_to_hex(params.info_hashes);
        if (hash.empty()) {
            [self setLastAddError:@"The torrent file has no usable info hash."];
            return nil;
        }

        bool restored = merge_resume_data(_resumeDir, hash, params);
        if (!restored && !_autoStartNewTorrents.load()) {
            params.flags |= lt::torrent_flags::paused;
            params.flags &= ~lt::torrent_flags::auto_managed;
        }

        hash = info_hash_to_hex(params.info_hashes);
        lt::torrent_handle handle = _session->add_torrent(std::move(params));
        {
            std::lock_guard<std::mutex> lock(_handleMutex);
            _handles[hash] = handle;
        }
        return nsstring(hash);
    } catch (std::exception const& e) {
        NSLog(@"addTorrentFile failed: %s", e.what());
        [self setLastAddError:[NSString stringWithFormat:@"%s", e.what()]];
        return nil;
    }
}

// MARK: - Torrent actions

- (void)pauseTorrent:(NSString *)infoHash {
    lt::torrent_handle handle;
    {
        std::lock_guard<std::mutex> lock(_handleMutex);
        auto found = _handles.find(utf8(infoHash));
        if (found == _handles.end()) return;
        handle = found->second;
    }
    if (!handle.is_valid()) return;

    handle.unset_flags(lt::torrent_flags::auto_managed);
    handle.pause();
    try {
        handle.save_resume_data(lt::torrent_handle::save_info_dict);
    } catch (std::exception const& e) {
        NSLog(@"save_resume_data(pause) failed: %s", e.what());
    }
}

- (void)resumeTorrent:(NSString *)infoHash {
    lt::torrent_handle handle;
    {
        std::lock_guard<std::mutex> lock(_handleMutex);
        auto found = _handles.find(utf8(infoHash));
        if (found == _handles.end()) return;
        handle = found->second;
    }
    if (!handle.is_valid()) return;

    handle.clear_error();
    handle.resume();
    handle.set_flags(lt::torrent_flags::auto_managed);
    try {
        handle.save_resume_data(lt::torrent_handle::save_info_dict);
    } catch (std::exception const& e) {
        NSLog(@"save_resume_data(resume) failed: %s", e.what());
    }
}

- (void)removeTorrent:(NSString *)infoHash deleteFiles:(BOOL)deleteFiles {
    std::string hash = utf8(infoHash);
    lt::torrent_handle handle;
    {
        std::lock_guard<std::mutex> lock(_handleMutex);
        auto found = _handles.find(hash);
        if (found != _handles.end()) {
            handle = found->second;
            _handles.erase(found);
        }
    }

    if (!hash.empty() && !_resumeDir.empty()) {
        std::remove(resume_path(_resumeDir, hash).c_str());
    }

    if (_session && handle.is_valid()) {
        _session->remove_torrent(handle, deleteFiles
            ? lt::session::delete_files
            : lt::remove_flags_t{});
    }
}

- (void)setFilePriority:(int)fileIndex priority:(int)priority infoHash:(NSString *)infoHash {
    if (fileIndex < 0) return;

    lt::torrent_handle handle;
    {
        std::lock_guard<std::mutex> lock(_handleMutex);
        auto found = _handles.find(utf8(infoHash));
        if (found == _handles.end()) return;
        handle = found->second;
    }
    if (!handle.is_valid()) return;

    int clamped = std::clamp(priority, 0, 7);
    try {
        handle.file_priority(lt::file_index_t(fileIndex),
                             lt::download_priority_t(
                                 static_cast<std::uint8_t>(clamped)));
    } catch (std::exception const& e) {
        NSLog(@"file_priority failed: %s", e.what());
    }
}

- (void)setQueuePriority:(int)priority infoHash:(NSString *)infoHash {
    if (priority < 0 || priority > 2 || priority == 1) return;

    lt::torrent_handle handle;
    {
        std::lock_guard<std::mutex> lock(_handleMutex);
        auto found = _handles.find(utf8(infoHash));
        if (found == _handles.end()) return;
        handle = found->second;
    }
    if (!handle.is_valid()) return;

    try {
        if (priority == 0) {
            handle.queue_position_top();
        } else {
            handle.queue_position_bottom();
        }
    } catch (std::exception const& e) {
        NSLog(@"queue priority change failed: %s", e.what());
    }
}

- (void)saveResumeDataForTorrent:(NSString *)infoHash {
    lt::torrent_handle handle;
    {
        std::lock_guard<std::mutex> lock(_handleMutex);
        auto found = _handles.find(utf8(infoHash));
        if (found == _handles.end()) return;
        handle = found->second;
    }
    if (!handle.is_valid()) return;

    try {
        handle.save_resume_data(lt::torrent_handle::save_info_dict);
    } catch (std::exception const& e) {
        NSLog(@"save_resume_data(request) failed: %s", e.what());
    }
}

- (nullable NSArray<NSNumber *> *)fileProgressForTorrent:(NSString *)infoHash {
    lt::torrent_handle handle;
    {
        std::lock_guard<std::mutex> lock(_handleMutex);
        auto found = _handles.find(utf8(infoHash));
        if (found == _handles.end()) return nil;
        handle = found->second;
    }
    if (!handle.is_valid()) return nil;

    try {
        auto info = handle.torrent_file();
        if (!info) return nil;

        std::vector<std::int64_t> progress;
        handle.file_progress(progress, lt::torrent_handle::piece_granularity);

        int count = info->files().num_files();
        NSMutableArray<NSNumber *> *result =
            [NSMutableArray arrayWithCapacity:static_cast<NSUInteger>(count)];

        for (int index = 0; index < count; ++index) {
            lt::file_index_t fileIndex(index);
            std::int64_t size = info->files().file_size(fileIndex);
            double value = 0.0;
            if (size > 0 && index < static_cast<int>(progress.size())) {
                value = static_cast<double>(progress[static_cast<std::size_t>(index)])
                      / static_cast<double>(size);
            }
            [result addObject:@(std::clamp(value, 0.0, 1.0))];
        }
        return result;
    } catch (std::exception const& e) {
        NSLog(@"file_progress failed: %s", e.what());
        return nil;
    }
}

// MARK: - Shutdown / persistence

- (void)saveAllResumeData {
    if (!_session) return;

    std::vector<lt::torrent_handle> handles;
    try {
        handles = _session->get_torrents();
    } catch (std::exception const& e) {
        NSLog(@"get_torrents failed during shutdown: %s", e.what());
        return;
    }

    int outstanding = 0;
    for (auto const& handle : handles) {
        try {
            handle.save_resume_data(lt::torrent_handle::save_info_dict);
            ++outstanding;
        } catch (std::exception const& e) {
            NSLog(@"save_resume_data(shutdown) failed: %s", e.what());
        }
    }

    auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(5);
    while (outstanding > 0 && std::chrono::steady_clock::now() < deadline) {
        _session->wait_for_alert(std::chrono::milliseconds(100));

        std::vector<lt::alert *> alerts;
        _session->pop_alerts(&alerts);

        for (lt::alert *alert : alerts) {
            if (auto resumeData = lt::alert_cast<lt::save_resume_data_alert>(alert)) {
                write_resume_data_to_directory(_resumeDir, resumeData->params);
                --outstanding;
            } else if (auto resumeError = lt::alert_cast<lt::save_resume_data_failed_alert>(alert)) {
                NSLog(@"save_resume_data failed during shutdown: %s",
                      resumeError->error.message().c_str());
                --outstanding;
            }
        }
    }

    if (outstanding > 0) {
        NSLog(@"Shutdown: %d resume-data alerts timed out", outstanding);
    }
}

- (void)saveSessionState {
    if (!_session) return;
    try {
        lt::session_params state = _session->session_state();
        std::vector<char> buffer = lt::write_session_params_buf(state);
        if (!buffer.empty()) {
            write_file_atomic(_sessionStatePath, buffer);
        }
    } catch (std::exception const& e) {
        NSLog(@"Failed to save session state: %s", e.what());
    }
}

- (void)stopAll {
    if (_stopped.exchange(true)) return;

    _running = false;
    if (_alertThread.joinable()) {
        _alertThread.join();
    }

    {
        std::lock_guard<std::mutex> lock(_cbMutex);
        _progressCb = nil;
        _errorCb = nil;
        _metaCb = nil;
        _finishedCb = nil;
        _removedCb = nil;
    }

    if (_session) {
        [self saveAllResumeData];
        [self saveSessionState];

        {
            std::lock_guard<std::mutex> lock(_handleMutex);
            _handles.clear();
        }
        _session.reset();
    }
}

- (void)dealloc {
    [self stopAll];
}

@end
