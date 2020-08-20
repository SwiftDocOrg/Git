import Clibgit2

/// A tree (directory listing) object.
public final class Tree: Object {
    class override var type: git_object_t { return GIT_OBJECT_TREE }

    /// The repository containing the tree.
    public override var owner: Repository {
        return Repository(git_tree_owner(pointer))
    }

    /// A tree entry.
    public final class Entry {
        weak var tree: Tree?

        var pointer: OpaquePointer

        /// The object corresponding to the tree entry.
        public var object: Object? {
            guard let tree = tree else { return nil }
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

        required init(_ pointer: OpaquePointer) {
            self.pointer = pointer
        }

        convenience init(in tree: Tree, at index: Int) {
            self.init(git_tree_entry_byindex(tree.pointer, index))
            self.tree = tree
        }
    }

    public subscript(_ name: String) -> Entry? {
        return indices.lazy
            .map { Entry(in: self, at: $0) }
            .first(where: { $0.name == name })
    }
}

// MARK: - Hashable

extension Tree.Entry: Hashable {
    public static func == (lhs: Tree.Entry, rhs: Tree.Entry) -> Bool {
        (lhs.name, lhs.object?.id) == (rhs.name, rhs.object?.id)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(object?.id)
    }
}

// MARK: - RandomAccessCollection

extension Tree: RandomAccessCollection {
    public typealias Element = Entry

    public var startIndex: Int { 0 }
    public var endIndex: Int { git_tree_entrycount(pointer) }

    public subscript(_ index: Int) -> Entry {
        precondition(indices.contains(index))
        return Entry(in: self, at: index)
    }
}
