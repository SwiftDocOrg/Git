import Clibgit2

/**
 Options for the order of the sequence returned by
 `Repository.revisions(with:)`.

 - SeeAlso: `Repository.revisions(with:)`
 */
public struct RevisionSortingOptions: OptionSet {
    public var rawValue: UInt32
    
    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    /**
     Sort the repository contents by commit time.
     */
    public static var time = RevisionSortingOptions(rawValue: GIT_SORT_TIME.rawValue)

    /**
     Sort the repository contents in topological order
     (no parents before all of its children are shown).
     */
    public static var topological = RevisionSortingOptions(rawValue: GIT_SORT_TOPOLOGICAL.rawValue)

    /**
     Iterate through the repository contents in reverse order.
     */
    public static var reverse = RevisionSortingOptions(rawValue: GIT_SORT_REVERSE.rawValue)
}

/**
 An interface for configuring which revisions are returned by
 `Repository.revisions(with:)`.

 - SeeAlso: `Repository.revisions(with:)`
 */
public protocol RevisionWalker {
    /// Push the repository's `HEAD`.
    func pushHead() throws

    /// Push matching references.
    func pushGlob(_ glob: String) throws

    /// Push a range of references.
    func pushRange(_ range: String) throws

    /// Push a reference by name.
    func pushReference(named name: String) throws

    /// Hide the repository's `HEAD`.
    func hideHead() throws

    /// Hide matching references.
    func hideGlob(_ glob: String) throws

    /// Hide a commit by ID.
    func hideCommit(with id: Commit.ID) throws

    /// Hide a reference by name.
    func hideReference(named name: String) throws

    /// Sort revisions with the provided options.
    func sort(with options: RevisionSortingOptions) throws

    /**
     Simplify the history such that
     no parents other than the first for each commit will be enqueued.
     */
    func simplifyFirstParent() throws
}

extension Repository {
    final class Revisions: Sequence, IteratorProtocol, RevisionWalker {
        private(set) var pointer: OpaquePointer!

        init(_ repository: Repository) throws {
            try wrap { git_revwalk_new(&pointer, repository.pointer) }
        }

        deinit {
            git_revwalk_free(pointer)
        }

        var repository: Repository {
            return Repository(git_revwalk_repository(pointer))
        }

        // MARK: - Sequence

        func next() -> Commit? {
            do {
                let pointer = UnsafeMutablePointer<git_oid>.allocate(capacity: 1)
                defer { pointer.deallocate() }
                try wrap { git_revwalk_next(pointer, self.pointer) }
                let id = Object.ID(rawValue: pointer.pointee)
                return try repository.lookup(id)
            } catch {
                return nil
            }
        }

        // MARK: - RevisionWalker

        func pushHead() throws {
            try wrap { git_revwalk_push_head(pointer) }
        }

        func pushGlob(_ glob: String) throws {
            try glob.withCString { string in
                try wrap { git_revwalk_push_glob(pointer, string) }
            }
        }

        func pushRange(_ range: String) throws {
            try range.withCString { string in
                try wrap { git_revwalk_push_range(pointer, string) }
            }
        }

        func pushReference(named name: String) throws {
            try name.withCString { string in
                try wrap { git_revwalk_push_ref(pointer, string) }
            }
        }

        func hideGlob(_ glob: String) throws {
            try glob.withCString { string in
                try wrap { git_revwalk_hide_glob(pointer, string) }
            }
        }

        func hideHead() throws {
            try wrap { git_revwalk_hide_head(pointer) }
        }

        func hideCommit(with id: Commit.ID) throws {
            var oid = id.rawValue
            try wrap { git_revwalk_hide(pointer, &oid) }
        }

        func hideReference(named name: String) throws {
            try name.withCString { string in
                try wrap { git_revwalk_hide_ref(pointer, string) }
            }
        }

        func sort(with options: RevisionSortingOptions) throws {
            try wrap { git_revwalk_sorting(pointer, options.rawValue) }
        }

        func simplifyFirstParent() throws {
            try wrap { git_revwalk_simplify_first_parent(pointer) }
        }

        func reset() throws {
            try wrap { git_revwalk_reset(pointer) }
        }
    }

    /**
     Returns a sequence of revisions according to the specified configuration.

     - Parameters:
        - configuration: A closure whose argument can be modified to
                         change which revisions are returned by the sequence,
                         and the order in which they appear.
     - Throws: Any error that occured during configuration.
     - Returns: A sequence of revisions.
     */
    public func revisions(with configuration: (RevisionWalker) throws -> Void ) throws -> AnySequence<Commit> {
        let revisions = try Revisions(self)
        try configuration(revisions)
        return AnySequence(revisions)
    }
}
