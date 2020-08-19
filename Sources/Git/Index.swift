import Clibgit2
import Foundation

/// A repository index.
public final class Index {
    private(set) var pointer: OpaquePointer!

    var managed: Bool = false

    init(_ pointer: OpaquePointer) {
        self.pointer = pointer
    }

    deinit {
        guard managed else { return }
        git_index_free(pointer)
    }

    // MARK: -

    /**
     The index on-disk version.

     Valid return values are 2, 3, or 4.
     If 3 is returned, an index with version 2 may be written instead,
     if the extension data in version 3 is not necessary.
     */
    public var version: Int {
        return Int(git_index_version(pointer))
    }

    /// The repository for the index.
    public var owner: Repository {
        return Repository(git_index_owner(pointer))
    }

    /// The file path to the repository index file.
    public var path: String! {
        return String(validatingUTF8: git_index_path(pointer))
    }

    /**
     Update the contents of an existing index object in memory
     by reading from disk.

     - Important: If there are changes on disk,
     unwritten in-memory changes are discarded.

     - Parameters:
     - force: If true, this performs a "hard" read
     that discards in-memory changes
     and always reloads the on-disk index data.
     If there is no on-disk version,
     the index will be cleared.
     If false,
     this does a "soft" read that reloads the index data from disk
     only if it has changed since the last time it was loaded.
     Purely in-memory index data will be untouched.
     */
    public func reload(force: Bool) throws {
        try wrap { git_index_read(pointer, force ? 1 : 0)}
    }
}

// MARK: -

extension Index {
    /// An entry in the index.
    public final class Entry: Equatable, Comparable, Hashable {
        weak var index: Index?
        private(set) var rawValue: git_index_entry

        init(rawValue: git_index_entry) {
            self.rawValue = rawValue
        }

        /// The file path of the index entry.
        public var path: String {
            return String(validatingUTF8: rawValue.path)!
        }

        /// The size of the index entry.
        public var fileSize: Int {
            return Int(rawValue.file_size)
        }

        /// The creation time of the index entry.
        public var creationTime: Date {
            return Date(timeIntervalSince1970: TimeInterval(rawValue.ctime.seconds))
        }

        /// The modification time of the index entry
        public var modificationTime: Date {
            return Date(timeIntervalSince1970: TimeInterval(rawValue.mtime.seconds))
        }

        /// The blob object for the index entry, if any.
        public var blob: Blob? {
            let id = Object.ID(rawValue: rawValue.id)
            return try? index?.owner.lookup(id)
        }

        // MARK: - Equatable

        public static func == (lhs: Index.Entry, rhs: Index.Entry) -> Bool {
            var loid = lhs.rawValue.id, roid = rhs.rawValue.id
            return git_oid_cmp(&loid, &roid) == 0
        }

        // MARK: - Comparable

        public static func < (lhs: Index.Entry, rhs: Index.Entry) -> Bool {
            return lhs.path < rhs.path
        }

        // MARK: - Hashable

        public func hash(into hasher: inout Hasher) {
            hasher.combine(rawValue.uid)
        }
    }

    final class Entries: Sequence, IteratorProtocol {
        private weak var index: Index?
        private(set) var pointer: OpaquePointer!

        init(_ index: Index) throws {
            try wrap { git_index_iterator_new(&pointer, index.pointer) }
            self.index = index
        }

        deinit {
            git_index_iterator_free(pointer)
        }

        var underestimatedCount: Int {
            guard let index = index else { return 0 }
            return git_index_entrycount(index.pointer)
        }

        // MARK: - Sequence

        func next() -> Entry? {
            do {
                var pointer: UnsafePointer<git_index_entry>?
                try wrap { git_index_iterator_next(&pointer, self.pointer) }
                let entry = Entry(rawValue: pointer!.pointee)
                entry.index = index
                return entry
            } catch {
                return nil
            }
        }
    }

    /// Returns a sequence of entries in the index.
    public var entries: AnySequence<Entry> {
        guard let entries = try? Entries(self) else { return AnySequence(EmptyCollection()) }
        return AnySequence(entries)
    }
}
