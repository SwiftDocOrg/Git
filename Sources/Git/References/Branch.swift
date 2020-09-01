import Clibgit2

/// A named reference to a commit.
public final class Branch: Reference {
    /// The referenced commit.
    public var commit: Commit? {
        let id: Object.ID
        switch git_reference_type(pointer) {
        case GIT_REFERENCE_SYMBOLIC:
            var resolved: OpaquePointer?
            guard case .success = result(of: { git_reference_resolve(&resolved, pointer) }) else { return nil }
            defer { git_reference_free(resolved) }
            id = Object.ID(rawValue: git_reference_target(resolved).pointee)
        default:
            id = Object.ID(rawValue: git_reference_target(pointer).pointee)
        }

        return try? owner.lookup(type: Commit.self, with: id)
    }

    /// The short name of the branch.
    public var shortName: String {
        var pointer: UnsafePointer<Int8>?
        guard case .success = result(of: { git_branch_name(&pointer, self.pointer) }),
              let string = String(validatingUTF8: pointer!)
        else { return name }

        return string
    }

    /// Whether `HEAD` points to the branch.
    public var isHEAD: Bool {
        return git_branch_is_head(pointer) != 0
    }

    /// Whether the branch is checked out.
    public var isCheckedOut: Bool {
        return git_branch_is_checked_out(pointer) != 0
    }

    /// Whether the branch is a remote tracking branch.
    public var isRemote: Bool {
        return git_reference_is_remote(pointer) != 0
    }

    /// Whether the branch is local.
    public var isLocal: Bool {
        return !isRemote
    }
}
