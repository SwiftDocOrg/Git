import Clibgit2

/// A named reference to a commit.
public final class Branch: Reference {
    /// A pointer to the referenced commit.
    public var commit: Commit? {
        guard let target = target else { return nil }
        return try? owner.lookup(target)
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
