import Clibgit2
import Foundation

public final class Repository {
    private(set) var pointer: OpaquePointer!
    private var managed: Bool = false

    init(_ pointer: OpaquePointer) {
        self.pointer = pointer
    }

    deinit {
        guard managed else { return }
        git_repository_free(pointer)
    }

    // MARK: -

    public class func open(at url: URL) throws -> Repository {
        var pointer: OpaquePointer?
        try wrap { git_repository_open(&pointer, url.path) }
        return Repository(pointer!)
    }

    public class func create(at url: URL, bare: Bool = false) throws -> Repository {
        var pointer: OpaquePointer?
        try wrap { git_repository_init(&pointer, url.path, bare ? 1 : 0) }
        return Repository(pointer!)
    }

    public class func discover(at url: URL, acrossFileSystems: Bool = true, stoppingAt ceilingDirectories: [String] = []) throws -> Repository {
        var buffer = git_buf()
        defer { git_buf_free(&buffer) }

        try url.withUnsafeFileSystemRepresentation { path in
            try wrap { git_repository_discover(&buffer, path, acrossFileSystems ? 1 : 0, ceilingDirectories.joined(separator: pathListSeparator).cString(using: .utf8)) }
        }

        let discoveredURL = URL(fileURLWithPath: String(cString: buffer.ptr))
        
        return try Repository.open(at: discoveredURL)
    }

    @discardableResult
    public static func clone(from remoteURL: URL,
                             to localURL: URL,
                             configuration: Clone.Configuration = .default) throws -> Repository {
        var pointer: OpaquePointer? = nil

        var options = configuration.rawValue
        let remoteURLString = remoteURL.isFileURL ? remoteURL.path : remoteURL.absoluteString
        try localURL.withUnsafeFileSystemRepresentation { path in
            try wrap { git_clone(&pointer, remoteURLString, path, &options) }
        }

        return try Repository.open(at: localURL)
    }

    // MARK: -

    /**
     The repository's working directory.

     For example, `path/to/repository/.git`.
     */
    public var commonDirectory: URL? {
        let path = String(cString: git_repository_commondir(pointer))
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    /**
     The repository's working directory,
     or `nil` if the repository is bare.

     For example, `path/to/repository`.
     */
    public var workingDirectory: URL? {
        let path = String(cString: git_repository_workdir(pointer))
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    /// The repository index, if any.
    public var index: Index? {
        var pointer: OpaquePointer?
        do {
            try wrap { git_repository_index(&pointer, self.pointer) }
        } catch {
            return nil
        }

        let index = Index(pointer!)
        index.managed = true

        return index
    }

    /// The `HEAD` of the repository.
    public var head: Head? {
        var pointer: OpaquePointer?
        do {
            try wrap { git_repository_head(&pointer, self.pointer) }
            if git_repository_head_detached(self.pointer) != 0 {
                return .detached(Commit(pointer!))
            } else {
                return .attached(Branch(pointer!))
            }
        } catch {
            return nil
        }
    }

    /// Returns a branch by name.
    public func branch(named name: String) throws -> Branch? {
        var pointer: OpaquePointer?
        try wrap { git_reference_lookup(&pointer, self.pointer, name) }

        guard git_reference_is_branch(pointer) != 0 ||
                git_reference_is_remote(pointer) != 0
        else {
            return nil
        }

        return Branch(pointer!)
    }

    /**
     Lookup an object by ID.

     - Parameters:
        - id: The object ID.
     - Throws: An error if no object exists for the
     - Returns: The corresponding object.
     */
    public func lookup<T: Object>(_ id: Object.ID) throws -> T? {
        var result: OpaquePointer? = nil
        var oid = id.rawValue
        try wrap { git_object_lookup(&result, self.pointer, &oid, T.type) }
//        defer { git_object_free(pointer) }
        guard let pointer = result else { return nil }

        return T(pointer)
    }

    /**
     Lookup a reference by name.

     - Parameters:
        - name: The reference name.
     - Throws: An error if no object exists for the
     - Returns: The corresponding object.
     */
    public func lookup<T: Reference>(_ name: String) throws -> T? {
        var result: OpaquePointer?
        try name.withCString { cString in
            try wrap { git_reference_lookup(&result, self.pointer, cString) }
        }
//        defer { git_object_free(pointer) }
        guard let pointer = result else { return nil }

        return T(pointer)
    }

    /**
     Returns the revision matching the provided specification.

     - Parameters:
     - specification: A revision specification.
     - Returns: A tuple containing the commit and/or reference
     matching the specification.
     */
    public func revision(matching specification: String) throws -> (Commit?, Reference?) {
        var commitPointer: OpaquePointer?
        var referencePointer: OpaquePointer?

        try specification.withCString { string in
            try wrap { git_revparse_ext(&commitPointer, &referencePointer, pointer, string) }
        }

        return (commitPointer.map(Commit.init), referencePointer.map(Reference.init))
    }

    /**
     Calculates the number of unique revisions between two commits.

     - Parameters:
     - local: The local commit.
     - upstream: The upstream commit.
     - Returns: A tuple with the number of commits `ahead` and `behind`.
     */
    public func distance(from local: Commit, to upstream: Commit) throws -> (ahead: Int, behind: Int) {
        var ahead: Int = 0, behind: Int = 0
        var localOID = local.id.rawValue, upstreamOID = upstream.id.rawValue
        try wrap { git_graph_ahead_behind(&ahead, &behind, pointer, &localOID, &upstreamOID) }
        return (ahead, behind)
    }

    public func add(path: String, force: Bool = false) throws {
        try path.withCString { cString in
            try wrap { git_index_add_bypath(index?.pointer, cString) }
        }
    }

    // TODO: Add dry-run option
    public func add(paths: [String], force: Bool = false, disableGlobExpansion: Bool = false) throws {
        let options = (force ? GIT_INDEX_ADD_FORCE.rawValue : 0) |
                        (disableGlobExpansion ? GIT_INDEX_ADD_DISABLE_PATHSPEC_MATCH.rawValue : 0)

        try paths.withGitStringArray { array in
            try withUnsafePointer(to: array) { paths in
                try wrap { git_index_add_all(index?.pointer, paths, options, nil, nil) }
            }
        }

        try wrap { git_index_write(index?.pointer) }
    }

    @discardableResult
    public func commit(message: String, author: Signature? = nil, committer: Signature? = nil) throws -> Commit {
        let tree = try lookup(try Object.ID { oid in
            try wrap { git_index_write_tree(oid, index?.pointer) }
        }) as Tree?

        var author = (try author ?? Signature.default(for: self)).rawValue
        var committer = (try committer ?? Signature.default(for: self)).rawValue
        
        var parents = [head?.commit].compactMap { $0?.pointer } as [OpaquePointer?]

        return try lookup(try Object.ID { oid in
            try wrap { git_commit_create(oid, pointer, "HEAD", &author, &committer, "UTF-8", message, tree?.pointer, parents.count, &parents) }
        })!
    }
}

// MARK: -

extension Repository {
    /// The repository `HEAD` reference.
    public enum Head: Equatable {
        case attached(Branch)
        case detached(Commit)

        public var attached: Bool {
            switch self {
            case .attached:
                return true
            case .detached:
                return false
            }
        }

        public var detached: Bool {
            return !attached
        }

        public var branch: Branch? {
            switch self {
            case .attached(let branch):
                return branch
            case .detached:
                return nil
            }
        }

        public var commit: Commit? {
            switch self {
            case .attached(let branch):
                return branch.commit
            case .detached(let commit):
                return commit
            }
        }
    }
}

// MARK: -

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

// MARK: -

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

// MARK: -

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
