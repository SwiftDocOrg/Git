import Clibgit2
import Foundation

public final class Repository {
    private(set) var pointer: OpaquePointer!
    private var managed: Bool = false

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
            case .attached:
                return nil
            case .detached(let commit):
                return commit
            }
        }
    }

    init(_ pointer: OpaquePointer) {
        self.pointer = pointer
    }

    deinit {
        guard managed else { return }
        git_repository_free(pointer)
    }

    // MARK: -

    public init(_ url: URL) throws {
        try wrap { git_repository_open(&pointer, url.path) }
    }

    public class func create(at url: URL, bare: Bool = false) throws -> Repository {
        var pointer: OpaquePointer?
        try wrap { git_repository_init(&pointer, url.path, bare ? 1 : 0) }
        return Repository(pointer!)
    }

    // TODO: Implement
    //    public class func discover(at url: URL) throws -> Repository { }

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

        return Index(pointer!)
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
        var result: OpaquePointer?
        var oid = id.rawValue
        try wrap { git_object_lookup(&result, self.pointer, &oid, T.type) }
        //        git_object_free(pointer)
        guard let pointer = result else { return nil }

        return T(pointer) // FIXME
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
}
