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
        try attempt { git_repository_open(&pointer, url.path) }
        return Repository(pointer!)
    }

    public class func create(at url: URL, bare: Bool = false) throws -> Repository {
        var pointer: OpaquePointer?
        try attempt { git_repository_init(&pointer, url.path, bare ? 1 : 0) }
        return Repository(pointer!)
    }

    public class func discover(at url: URL, acrossFileSystems: Bool = true, stoppingAt ceilingDirectories: [String] = []) throws -> Repository {
        var buffer = git_buf()
        defer { git_buf_free(&buffer) }

        try url.withUnsafeFileSystemRepresentation { path in
            try attempt { git_repository_discover(&buffer, path, acrossFileSystems ? 1 : 0, ceilingDirectories.joined(separator: pathListSeparator).cString(using: .utf8)) }
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
            try attempt { git_clone(&pointer, remoteURLString, path, &options) }
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
        guard case .success = result(of: { git_repository_index(&pointer, self.pointer) }),
              pointer != nil else { return nil }
        let index = Index(pointer!)
        index.managed = true

        return index
    }

    /// The `HEAD` of the repository.
    public var head: Head? {
        var pointer: OpaquePointer?
        guard case .success = result(of: { git_repository_head(&pointer, self.pointer) }) else { return nil }

        if git_repository_head_detached(self.pointer) != 0 {
            return .detached(Commit(pointer!))
        } else {
            return .attached(Branch(pointer!))
        }
    }

    /// Returns a branch by name.
    public func branch(named name: String) throws -> Branch? {
        var pointer: OpaquePointer?
        try attempt { git_reference_lookup(&pointer, self.pointer, name) }

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
        try attempt { git_object_lookup(&result, self.pointer, &oid, T.type) }
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
            try attempt { git_reference_lookup(&result, self.pointer, cString) }
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
            try attempt { git_revparse_ext(&commitPointer, &referencePointer, pointer, string) }
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
        try attempt { git_graph_ahead_behind(&ahead, &behind, pointer, &localOID, &upstreamOID) }
        return (ahead, behind)
    }

    public func add(path: String, force: Bool = false) throws {
        try path.withCString { cString in
            try attempt { git_index_add_bypath(index?.pointer, cString) }
        }
    }

    // TODO: Add dry-run option
    public func add(paths: [String], update: Bool = false, force: Bool = false, disableGlobExpansion: Bool = false) throws {
        let options = (force ? GIT_INDEX_ADD_FORCE.rawValue : 0) |
                        (disableGlobExpansion ? GIT_INDEX_ADD_DISABLE_PATHSPEC_MATCH.rawValue : 0)

        try paths.withGitStringArray { array in
            try withUnsafePointer(to: array) { paths in
                if update {
                    try attempt { git_index_update_all(index?.pointer, paths, nil, nil) }
                } else {
                    try attempt { git_index_add_all(index?.pointer, paths, options, nil, nil) }
                }
            }
        }
    }

    @discardableResult
    public func commit(message: String, author: Signature? = nil, committer: Signature? = nil) throws -> Commit {
        let tree = try lookup(try Object.ID { oid in
            try attempt { git_index_write_tree(oid, index?.pointer) }
        }) as Tree?

        var committer = (try committer ?? author ?? Signature.default(for: self)).rawValue
        var author = (try author ?? Signature.default(for: self)).rawValue

        var parents = [head?.commit].compactMap { $0?.pointer } as [OpaquePointer?]

        return try lookup(try Object.ID { oid in
            try attempt { git_commit_create(oid, pointer, "HEAD", &author, &committer, "UTF-8", message, tree?.pointer, parents.count, &parents) }
        })!
    }
}
