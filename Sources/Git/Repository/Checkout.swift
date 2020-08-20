import Clibgit2
import Foundation

extension Repository {
    public enum Checkout {
        public enum Strategy {
            case force
            case safe
        }

        public enum ConflictResolution{
            case skipUnmerged
            case useOurs
            case useTheirs
        }

        public struct Configuration {
            var rawValue: git_checkout_options

            public static var `default` = try! Configuration()

            init() throws {
                let pointer = UnsafeMutablePointer<git_checkout_options>.allocate(capacity: 1)
                defer { pointer.deallocate() }
                try wrap { git_checkout_options_init(pointer, numericCast(GIT_CHECKOUT_OPTIONS_VERSION)) }
                rawValue = pointer.pointee
            }

            init(rawValue: git_checkout_options) {
                self.rawValue = rawValue
            }

            /// Don't apply filters like CRLF conversion
            public var disableFilters: Bool {
                get {
                    return rawValue.disable_filters != 0
                }

                set {
                    rawValue.disable_filters = newValue ? 1 : 0
                }
            }

            /// Default is 0755
            public var directoryMode: Int {
                get {
                    return numericCast(rawValue.dir_mode)
                }

                set {
                    rawValue.dir_mode = numericCast(newValue)
                }
            }

            /// Default is 0644 or 0755 as dictated by blob
            public var fileMode: Int {
                get {
                    return numericCast(rawValue.file_mode)
                }

                set {
                    rawValue.file_mode = numericCast(newValue)
                }
            }

            // MARK: Strategy

            /// Default will be a safe checkout
            public var strategy: Strategy? {
                get {
                    return Strategy?(rawValue: rawValue.checkout_strategy)
                }

                set {
                    rawValue.checkout_strategy = newValue.rawValue | conflictResolution.rawValue |
                        (allowConflicts ? GIT_CHECKOUT_ALLOW_CONFLICTS.rawValue : 0) |
                        (removeUntracked ? GIT_CHECKOUT_REMOVE_UNTRACKED.rawValue : 0) |
                        (removeIgnored ? GIT_CHECKOUT_REMOVE_IGNORED.rawValue : 0) |
                        (updateOnly ? GIT_CHECKOUT_UPDATE_ONLY.rawValue : 0) |
                        (updateIndex ? 0 : GIT_CHECKOUT_DONT_UPDATE_INDEX.rawValue) |
                        (refreshIndex ? 0 : GIT_CHECKOUT_NO_REFRESH.rawValue) |
                        (overwriteIgnored ? 0 : GIT_CHECKOUT_DONT_OVERWRITE_IGNORED.rawValue) |
                        (removeExisting ? 0 : GIT_CHECKOUT_DONT_REMOVE_EXISTING.rawValue)
                }
            }

            /// makes SAFE mode apply safe file updates even if there are conflicts (instead of cancelling the checkout).
            public var allowConflicts: Bool {
                get {
                    rawValue.checkout_strategy & GIT_CHECKOUT_ALLOW_CONFLICTS.rawValue != 0
                }

                set {
                    rawValue.checkout_strategy |= GIT_CHECKOUT_ALLOW_CONFLICTS.rawValue
                }
            }

            public var conflictResolution: ConflictResolution? {
                get {
                    return ConflictResolution?(rawValue: rawValue.checkout_strategy)
                }

                set {
                    rawValue.checkout_strategy = strategy.rawValue | newValue.rawValue |
                        (allowConflicts ? GIT_CHECKOUT_ALLOW_CONFLICTS.rawValue : 0) |
                        (removeUntracked ? GIT_CHECKOUT_REMOVE_UNTRACKED.rawValue : 0) |
                        (removeIgnored ? GIT_CHECKOUT_REMOVE_IGNORED.rawValue : 0) |
                        (updateOnly ? GIT_CHECKOUT_UPDATE_ONLY.rawValue : 0) |
                        (updateIndex ? 0 : GIT_CHECKOUT_DONT_UPDATE_INDEX.rawValue) |
                        (refreshIndex ? 0 : GIT_CHECKOUT_NO_REFRESH.rawValue) |
                        (overwriteIgnored ? 0 : GIT_CHECKOUT_DONT_OVERWRITE_IGNORED.rawValue) |
                        (removeExisting ? 0 : GIT_CHECKOUT_DONT_REMOVE_EXISTING.rawValue)
                }
            }

            /// means remove untracked files (i.e. not in target, baseline, or index, and not ignored) from the working dir.
            public var removeUntracked: Bool {
                get {
                    rawValue.checkout_strategy & GIT_CHECKOUT_REMOVE_UNTRACKED.rawValue != 0
                }

                set {
                    if newValue {
                        rawValue.checkout_strategy |= GIT_CHECKOUT_REMOVE_UNTRACKED.rawValue
                    } else {
                        rawValue.checkout_strategy &= ~GIT_CHECKOUT_REMOVE_UNTRACKED.rawValue
                    }
                }
            }

            ///  means remove ignored files (that are also untracked) from the working directory as well.
            public var removeIgnored: Bool {
                get {
                    rawValue.checkout_strategy & GIT_CHECKOUT_REMOVE_IGNORED.rawValue != 0
                }

                set {
                    if newValue {
                        rawValue.checkout_strategy |= GIT_CHECKOUT_REMOVE_IGNORED.rawValue
                    } else {
                        rawValue.checkout_strategy &= ~GIT_CHECKOUT_REMOVE_IGNORED.rawValue
                    }
                }
            }

            /// means to only update the content of files that already exist. Files will not be created nor deleted. This just skips applying adds, deletes, and typechanges.
            public var updateOnly: Bool {
                get {
                    rawValue.checkout_strategy & GIT_CHECKOUT_UPDATE_ONLY.rawValue != 0
                }

                set {
                    if newValue {
                        rawValue.checkout_strategy |= GIT_CHECKOUT_UPDATE_ONLY.rawValue
                    } else {
                        rawValue.checkout_strategy &= ~GIT_CHECKOUT_UPDATE_ONLY.rawValue
                    }
                }
            }

            /// !prevents checkout from writing the updated files' information to the index.
            public var updateIndex: Bool {
                get {
                    rawValue.checkout_strategy & GIT_CHECKOUT_DONT_UPDATE_INDEX.rawValue == 0
                }

                set {
                    if newValue {
                        rawValue.checkout_strategy &= ~GIT_CHECKOUT_DONT_UPDATE_INDEX.rawValue
                    } else {
                        rawValue.checkout_strategy |= GIT_CHECKOUT_DONT_UPDATE_INDEX.rawValue
                    }
                }
            }

            /// checkout will reload the index and git attributes from disk before any operations.
            /// Set to false to disable.
            public var refreshIndex: Bool {
                get {
                    rawValue.checkout_strategy & GIT_CHECKOUT_NO_REFRESH.rawValue == 0
                }

                set {
                    if newValue {
                        rawValue.checkout_strategy &= ~GIT_CHECKOUT_NO_REFRESH.rawValue
                    } else {
                        rawValue.checkout_strategy |= GIT_CHECKOUT_NO_REFRESH.rawValue
                    }
                }
            }

            /// !prevents ignored files from being overwritten. Normally, files that are ignored in the working directory are not considered "precious" and may be overwritten if the checkout target contains that file.
            public var overwriteIgnored: Bool {
                get {
                    rawValue.checkout_strategy & GIT_CHECKOUT_DONT_OVERWRITE_IGNORED.rawValue == 0
                }

                set {
                    if newValue {
                        rawValue.checkout_strategy &= ~GIT_CHECKOUT_DONT_OVERWRITE_IGNORED.rawValue
                    } else {
                        rawValue.checkout_strategy |= GIT_CHECKOUT_DONT_OVERWRITE_IGNORED.rawValue
                    }
                }
            }

            /// !prevents checkout from removing files or folders that fold to the same name on case insensitive filesystems. This can cause files to retain their existing names and write through existing symbolic links.
            public var removeExisting: Bool {
                get {
                    rawValue.checkout_strategy & GIT_CHECKOUT_DONT_REMOVE_EXISTING.rawValue == 0
                }

                set {
                    if newValue {
                        rawValue.checkout_strategy &= ~GIT_CHECKOUT_ALLOW_CONFLICTS.rawValue
                    } else {
                        rawValue.checkout_strategy |= GIT_CHECKOUT_ALLOW_CONFLICTS.rawValue
                    }
                }
            }
        }
    }
}

extension Optional /*: internal RawRepresentable */ where Wrapped == Repository.Checkout.Strategy {
    init(rawValue: UInt32) {
        if rawValue & GIT_CHECKOUT_FORCE.rawValue != 0 {
            self = .force
        } else if rawValue & GIT_CHECKOUT_SAFE.rawValue != 0 {
            self = .safe
        } else {
            self = .none
        }
    }

    var rawValue: UInt32 {
        switch self {
        case .force?:
            return GIT_CHECKOUT_FORCE.rawValue
        case .safe?:
            return GIT_CHECKOUT_SAFE.rawValue
        default:
            return GIT_CHECKOUT_NONE.rawValue
        }
    }
}

extension Optional /*: internal RawRepresentable */ where Wrapped == Repository.Checkout.ConflictResolution {
    init(rawValue: UInt32) {
        if rawValue & GIT_CHECKOUT_SKIP_UNMERGED.rawValue != 0 {
            self = .skipUnmerged
        } else if rawValue & GIT_CHECKOUT_USE_OURS.rawValue != 0 {
            self = .useOurs
        } else if rawValue & GIT_CHECKOUT_USE_THEIRS.rawValue != 0 {
            self = .useTheirs
        } else {
            self = .none
        }
    }

    var rawValue: UInt32 {
        switch self {
        case .skipUnmerged?:
            return GIT_CHECKOUT_SKIP_UNMERGED.rawValue
        case .useOurs?:
            return GIT_CHECKOUT_USE_OURS.rawValue
        case .useTheirs?:
            return GIT_CHECKOUT_USE_THEIRS.rawValue
        default:
            return GIT_CHECKOUT_NONE.rawValue
        }
    }
}
