import Clibgit2
import Foundation

public class Remote /*: internal RawRepresentable*/ {
    private var rawValue: OpaquePointer!

    var managed: Bool = false

    init(rawValue: OpaquePointer) {
        self.rawValue = rawValue
    }

    deinit {
        guard managed else { return }
        git_remote_free(rawValue)
    }

    // MARK: -

    /**
     Creates a detatched remote with the specified name and url.

     - Parameters:
     - name: The name of the remote, if any.
     - url: The url of the remote.
     */
    public convenience init(name: String? = nil, url: URL) throws {
        fatalError() // TODO
    }
}

// MARK: -

extension Remote {
    public enum Fetch {
        public enum TagFollowing {
            /// Use the setting from the configuration.
            case `default`

            /// Ask the server for tags pointing to objects we're already downloading.
            case automatic

            /// Ask for the all the tags.
            case all
        }

        public struct Configuration {
            var rawValue: git_fetch_options

            public static var `default` = try! Configuration()

            init() throws {
                let pointer = UnsafeMutablePointer<git_fetch_options>.allocate(capacity: 1)
                defer { pointer.deallocate() }
                try wrap { git_fetch_options_init(pointer, numericCast(GIT_FETCH_OPTIONS_VERSION)) }
                rawValue = pointer.pointee
            }

            init(rawValue: git_fetch_options) {
                self.rawValue = rawValue
            }

            /// Whether to write the results to FETCH_HEAD. Defaults to on. Leave this default in order to behave like git.
            public var updateFetchHead: Bool {
                get {
                    rawValue.update_fetchhead != 0
                }

                set {
                    rawValue.update_fetchhead = newValue ? 1 : 0
                }
            }

            public var prune: Bool? {
                get {
                    switch rawValue.prune {
                    case GIT_FETCH_PRUNE: return true
                    case GIT_FETCH_NO_PRUNE: return false
                    default:
                        return nil
                    }
                }

                set {
                    switch newValue {
                    case true?:
                        rawValue.prune = GIT_FETCH_PRUNE
                    case false?:
                        rawValue.prune = GIT_FETCH_NO_PRUNE
                    case nil:
                        rawValue.prune = GIT_FETCH_PRUNE_UNSPECIFIED
                    }
                }
            }

            public var tagFollowing: TagFollowing? {
                get {
                    return TagFollowing?(rawValue: rawValue.download_tags)
                }

                set {
                    rawValue.download_tags = newValue.rawValue
                }
            }

            /// Extra headers for this fetch operation
            public var customHeaders: [String] {
                get {
                    Array<String>(rawValue.custom_headers)
                }

                // TODO: setter
            }
        }
    }
}

extension Optional /*: internal RawRepresentable */ where Wrapped == Remote.Fetch.TagFollowing {
    init(rawValue: git_remote_autotag_option_t) {
        switch rawValue {
        case GIT_REMOTE_DOWNLOAD_TAGS_UNSPECIFIED:
            self = .default
        case GIT_REMOTE_DOWNLOAD_TAGS_AUTO:
            self = .automatic
        case GIT_REMOTE_DOWNLOAD_TAGS_ALL:
            self = .all
        default:
            self = .none
        }
    }

    var rawValue: git_remote_autotag_option_t {
        switch self {
        case .default?:
            return GIT_REMOTE_DOWNLOAD_TAGS_UNSPECIFIED
        case .automatic?:
            return GIT_REMOTE_DOWNLOAD_TAGS_AUTO
        case .all?:
            return GIT_REMOTE_DOWNLOAD_TAGS_ALL
        default:
            return GIT_REMOTE_DOWNLOAD_TAGS_NONE
        }
    }
}

fileprivate extension Array where Element == String {
    init(_ git_strarray: git_strarray) {
        self.init((0..<git_strarray.count).map { String(validatingUTF8: git_strarray.strings[$0]!)! })
    }
}
