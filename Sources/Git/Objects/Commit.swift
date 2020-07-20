import Clibgit2

/// A commit object.
public final class Commit: Object {
    class override var type: git_object_t { return GIT_OBJECT_COMMIT }

    /// The tree containing the commit, if any.
    public var tree: Tree? {
        let id = Object.ID(rawValue: git_commit_tree_id(pointer).pointee)
        return try? owner.lookup(id)
    }

    /// The parents of the commit.
    public var parents: [Commit] {
        var parents: [Commit] = []
        for n in 0..<git_commit_parentcount(pointer) {
            let id = Object.ID(rawValue: git_commit_parent_id(pointer, n).pointee)
            guard let commit = try? owner.lookup(id) as? Commit else { continue }
            parents.append(commit)
        }

        return parents
    }

    /// The commit message, if any.
    public var message: String? {
        return String(validatingUTF8: git_commit_message(pointer))
    }

    /// The signature of the author.
    public var author: Signature {
        return Signature(rawValue: git_commit_author(pointer).pointee)
    }

    /// The signature of the committer.
    public var committer: Signature {
        return Signature(rawValue: git_commit_committer(pointer).pointee)
    }

    /**
     Calculates the number of unique revisions to another commit.

     - Parameters:
        - upstream: The upstream commit.
     - Returns: A tuple with the number of commits `ahead` and `behind`.
     */
    public func distance(to upstream: Commit) throws -> (ahead: Int, behind: Int) {
        var ahead: Int = 0, behind: Int = 0
        var localOID = self.id.rawValue, upstreamOID = upstream.id.rawValue
        try wrap { git_graph_ahead_behind(&ahead, &behind, pointer, &localOID, &upstreamOID) }
        return (ahead, behind)
    }

    /**
     Determines whether the commit is a descendent of another commit.

     - Parameters:
        - ancestor: The presumptive ancestor.
     */
    public func isDescendent(of ancestor: Commit) throws -> Bool {
        var commitOID = self.id.rawValue, ancestorOID = ancestor.id.rawValue
        let result = git_graph_descendant_of(owner.pointer, &commitOID, &ancestorOID)
        switch result {
        case 0: return false
        case 1: return true
        case let code:
            throw Error(code: code)
        }
    }
}
