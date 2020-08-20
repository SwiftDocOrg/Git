import Clibgit2

/**
 A branch, note, or tag.

 - SeeAlso: `Branch`
 - SeeAlso: `Note`
 - SeeAlso: `Tag`
 */
public class Reference/*: Identifiable */ {
    private(set) var pointer: OpaquePointer!

    private var managed: Bool = false

    required init(_ pointer: OpaquePointer) {
        self.pointer = pointer
    }

    deinit {
        guard managed else { return }
        git_reference_free(pointer)
    }

    // MARK: -

    /// Normalization options for reference lookup.
    public enum Format {
        /// No particular normalization.
        case normal

        /**
         Control whether one-level refnames are accepted
         (i.e., refnames that do not contain multiple `/`-separated components).

         Those are expected to be written only using
         uppercase letters and underscore (`FETCH_HEAD`, ...)
         */
        case allowOneLevel

        /**
         Interpret the provided name as a reference pattern for a refspec
         (as used with remote repositories).

         If this option is enabled,
         the name is allowed to contain a single `*` (<star>)
         in place of a one full pathname component
         (e.g., `foo/<star>/bar` but not `foo/bar<star>`).
         */
        case refspecPattern

        /**
         Interpret the name as part of a refspec in shorthand form
         so the `ONELEVEL` naming rules aren't enforced
         and 'master' becomes a valid name.
         */
        case refspecShorthand

        var rawValue: git_reference_format_t {
            switch self {
            case .normal:
                return GIT_REFERENCE_FORMAT_NORMAL
            case .allowOneLevel:
                return GIT_REFERENCE_FORMAT_ALLOW_ONELEVEL
            case .refspecPattern:
                return GIT_REFERENCE_FORMAT_REFSPEC_PATTERN
            case .refspecShorthand:
                return GIT_REFERENCE_FORMAT_REFSPEC_SHORTHAND
            }
        }
    }

    public static func normalize(name: String, format: Format = .normal) throws -> String {
        let length = name.underestimatedCount * 2
        let cString = UnsafeMutablePointer<Int8>.allocate(capacity: length)
        defer { cString.deallocate() }
        try attempt { git_reference_normalize_name(cString, length, name, format.rawValue.rawValue) }
        return String(validatingUTF8: cString)!
    }

    /// The reference name.
    public var name: String {
        return String(validatingUTF8: git_reference_name(pointer))!
    }

    /// The repository containing the reference.
    public var owner: Repository {
        return Repository(git_reference_owner(pointer))
    }
}

// MARK: - Equatable

extension Reference: Equatable {
    public static func == (lhs: Reference, rhs: Reference) -> Bool {
        return git_reference_cmp(lhs.pointer, lhs.pointer) == 0
    }
}
