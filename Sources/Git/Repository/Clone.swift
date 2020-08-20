import Clibgit2
import Foundation

extension Repository {
    public enum Clone {
        public enum Local /* : internal RawRepresentable */ {
            /**
             * Auto-detect (default), libgit2 will bypass the git-aware
             * transport for local paths, but use a normal fetch for
             * `file://` urls.
             */
            case automatic

            /// Bypass the git-aware transport even for a `file://` url.
            case yes(useHardLinks: Bool = true)

            /// Do no bypass the git-aware transport
            case no

            init(rawValue: git_clone_local_t) {
                switch rawValue {
                case GIT_CLONE_LOCAL:
                    self = .yes(useHardLinks: true)
                case GIT_CLONE_LOCAL_NO_LINKS:
                    self = .yes(useHardLinks: false)
                case GIT_CLONE_NO_LOCAL:
                    self = .no
                default:
                    self = .automatic
                }
            }

            public var rawValue: git_clone_local_t {
                switch self {
                case .automatic:
                    return GIT_CLONE_LOCAL_AUTO
                case .yes(useHardLinks: true):
                    return GIT_CLONE_LOCAL
                case .yes(useHardLinks: false):
                    return GIT_CLONE_LOCAL_NO_LINKS
                case .no:
                    return GIT_CLONE_NO_LOCAL
                }
            }
        }

        public struct Configuration {
            var rawValue: git_clone_options

            public static var `default` = try! Configuration()

            init() throws {
                let pointer = UnsafeMutablePointer<git_clone_options>.allocate(capacity: 1)
                defer { pointer.deallocate() }
                try wrap { git_clone_options_init(pointer, numericCast(GIT_CLONE_OPTIONS_VERSION)) }
                rawValue = pointer.pointee
            }

            init(rawValue: git_clone_options) {
                self.rawValue = rawValue
            }

            public var checkoutConfiguration: Repository.Checkout.Configuration {
                get {
                    Repository.Checkout.Configuration(rawValue: rawValue.checkout_opts)
                }

                set {
                    rawValue.checkout_opts = newValue.rawValue
                }
            }

            public var fetchConfiguration: Remote.Fetch.Configuration {
                get {
                    Remote.Fetch.Configuration(rawValue: rawValue.fetch_opts)
                }

                set {
                    rawValue.fetch_opts = newValue.rawValue
                }
            }

            /// Set to zero (false) to create a standard repo, or non-zero for a bare repo
            public var bare: Bool {
                get {
                    rawValue.bare != 0
                }

                set {
                    rawValue.bare = newValue ? 1 : 0
                }
            }

            /// Whether to use a fetch or copy the object database.
            public var local: Local {
                get {
                    Local(rawValue: rawValue.local)
                }

                set {
                    rawValue.local = newValue.rawValue
                }
            }

            /// The name of the branch to checkout. NULL means use the remote's default branch.
            public var checkoutBranch: String? {
                get {
                    guard let cString = rawValue.checkout_branch else { return nil }
                    return String(validatingUTF8: cString)
                }

                set {
                    newValue?.withCString({ cString in rawValue.checkout_branch = cString })
                }
            }
        }
    }
}
