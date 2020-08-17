import Clibgit2

/// A tree (directory listing) object.
public final class Tree: Object {
    class override var type: git_object_t { return GIT_OBJECT_TREE }

    /// A tree entry.
    public final class Entry {
        private(set) var tree: Tree
        private(set) var index: Int

        var pointer: OpaquePointer {
            git_tree_entry_byindex(tree.pointer, index)
        }

        /// The object corresponding to the tree entry.
        public var object: Object? {
            var pointer: OpaquePointer?
            do {
                try wrap { git_tree_entry_to_object(&pointer, tree.owner.pointer, self.pointer)}
            } catch {
                return nil
            }

            return Object.type(of: git_object_type(pointer!))?.init(pointer!)
        }

        /// The file attributes of a tree entry
        public var attributes: Int32 {
            return Int32(git_tree_entry_filemode(pointer).rawValue)
        }

        /// The filename of the tree entry.
        public var name: String {
            return String(validatingUTF8: git_tree_entry_name(pointer))!
        }

        init(in tree: Tree, at index: Int) {
            self.tree = tree
            self.index = index
        }
    }

    public var entries: [String: Entry] {
        var entries: [String: Entry] = [:]
        for index in 0..<git_tree_entrycount(pointer) {
            let entry = Entry(in: self, at: index)
            entries[entry.name] = entry
        }

        return entries
    }
}
