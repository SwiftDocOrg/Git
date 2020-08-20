import Clibgit2
import Foundation

extension Repository {
//    /**
//     * Check attribute flags: Reading values from index and working directory.
//     *
//     * When checking attributes, it is possible to check attribute files
//     * in both the working directory (if there is one) and the index (if
//     * there is one).  You can explicitly choose where to check and in
//     * which order using the following flags.
//     *
//     * Core git usually checks the working directory then the index,
//     * except during a checkout when it checks the index first.  It will
//     * use index only for creating archives or for a bare repo (if an
//     * index has been specified for the bare repo).
//     */
//    public var GIT_ATTR_CHECK_FILE_THEN_INDEX: Int32 { get }
//    public var GIT_ATTR_CHECK_INDEX_THEN_FILE: Int32 { get }
//    public var GIT_ATTR_CHECK_INDEX_ONLY: Int32 { get }
//
//    /**
//     * Check attribute flags: controlling extended attribute behavior.
//     *
//     * Normally, attribute checks include looking in the /etc (or system
//     * equivalent) directory for a `gitattributes` file.  Passing this
//     * flag will cause attribute checks to ignore that file.
//     * equivalent) directory for a `gitattributes` file.  Passing the
//     * `GIT_ATTR_CHECK_NO_SYSTEM` flag will cause attribute checks to
//     * ignore that file.
//     *
//     * Passing the `GIT_ATTR_CHECK_INCLUDE_HEAD` flag will use attributes
//     * from a `.gitattributes` file in the repository at the HEAD revision.
//     */
//    public var GIT_ATTR_CHECK_NO_SYSTEM: Int32 { get }
//    public var GIT_ATTR_CHECK_INCLUDE_HEAD: Int32 { get }

    public final class Attributes {
        public enum Value: Equatable, Hashable {
            case boolean(Bool)
            case string(String)
        }

        private weak var repository: Repository?

        init(_ repository: Repository) {
            self.repository = repository
        }

        public subscript(_ name: String) -> Value? {
            var pointer: UnsafePointer<Int8>?
            return name.withCString { cString in
                guard case .success = result(of: { git_attr_get(&pointer, repository?.pointer, 0, ".gitattributes", cString) }) else { return nil }

                switch git_attr_value(pointer) {
                case GIT_ATTR_VALUE_TRUE:
                    return .boolean(true)
                case GIT_ATTR_VALUE_FALSE:
                    return .boolean(false)
                case GIT_ATTR_VALUE_STRING:
                    return .string(String(validatingUTF8: pointer!) ?? "")
                default:
                    return nil
                }
            }
        }
    }

    public var attributes: Attributes {
        return Attributes(self)
    }
}

extension Repository.Attributes.Value: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) {
        self = .boolean(value)
    }
}

extension Repository.Attributes.Value: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .string(value)
    }
}
