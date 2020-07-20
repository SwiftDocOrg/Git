import Clibgit2

/// A tree (directory listing) object.
public final class Tree: Object {
    class override var type: git_object_t { return GIT_OBJECT_TREE }

    /// A tree entry.
    public struct Entry: Hashable {
        private(set) var pointer: OpaquePointer!

        /// The file attributes of a tree entry
        public var attributes: Int32 {
            return Int32(git_tree_entry_filemode(pointer).rawValue)
        }

        /// The filename of the tree entry.
        public var name: String {
            return String(validatingUTF8: git_tree_entry_name(pointer))!
        }

        /// The object corresponding to the tree entry.
        public var object: Object? {
            return Object.type(of: pointer)?.init(pointer)
        }

        init(_ pointer: OpaquePointer) {
            self.pointer = pointer
        }

        public init(_ object: Object) {
            self.pointer = object.pointer
        }
    }

    public var entries: [String: Entry] {
        var entries: [String: Entry] = [:]
        for index in 0..<git_tree_entrycount(pointer) {
            let entry = Entry(git_tree_entry_byindex(pointer, index)!)
            entries[entry.name] = entry
        }

        return entries
    }
}
