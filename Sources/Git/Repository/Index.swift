import Clibgit2
import Foundation

extension Repository {
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
            try attempt { git_index_read(pointer, force ? 1 : 0)}
        }

        public func add(path: String, force: Bool = false) throws {
            try path.withCString { cString in
                try attempt { git_index_add_bypath(pointer, cString) }
            }
        }

        // TODO: Add dry-run option
        public func add(paths: [String], update: Bool = false, force: Bool = false, disableGlobExpansion: Bool = false) throws {
            let options = (force ? GIT_INDEX_ADD_FORCE.rawValue : 0) |
                            (disableGlobExpansion ? GIT_INDEX_ADD_DISABLE_PATHSPEC_MATCH.rawValue : 0)

            try paths.withGitStringArray { array in
                try withUnsafePointer(to: array) { paths in
                    if update {
                        try attempt { git_index_update_all(pointer, paths, nil, nil) }
                    } else {
                        try attempt { git_index_add_all(pointer, paths, options, nil, nil) }
                    }
                }
            }

            try attempt { git_index_write(pointer) }
        }
    }
}

extension Repository.Index {
    public enum Stage /* : internal RawRepresentable */ {
        case normal
        case ancestor
        case ours
        case theirs

        init(rawValue: git_index_stage_t) {
            switch rawValue {
            case GIT_INDEX_STAGE_ANCESTOR:
                self = .ancestor
            case GIT_INDEX_STAGE_OURS:
                self = .ours
            case GIT_INDEX_STAGE_THEIRS:
                self = .theirs
            default:
                self = .normal
            }
        }

        var rawValue: git_index_stage_t {
            switch self {
            case .normal:
                return GIT_INDEX_STAGE_NORMAL
            case .ancestor:
                return GIT_INDEX_STAGE_ANCESTOR
            case .ours:
                return GIT_INDEX_STAGE_OURS
            case .theirs:
                return GIT_INDEX_STAGE_THEIRS
            }
        }
    }
}

extension Repository.Index {
    /// An entry in the index.
    public final class Entry: Equatable, Comparable, Hashable {
        weak var index: Repository.Index?
        private(set) var rawValue: git_index_entry

        required init(rawValue: git_index_entry) {
            self.rawValue = rawValue
        }

        convenience init?(in index: Repository.Index, at n: Int) {
            let pointer = git_index_get_byindex(index.pointer, n)
            guard let rawValue = pointer?.pointee else { return nil }

            self.init(rawValue: rawValue)
            self.index = index
        }

        convenience init?(in index: Repository.Index, at path: String, stage: Stage) {
            let pointer = path.withCString { cString in
                git_index_get_bypath(index.pointer, cString, stage.rawValue.rawValue)
            }
            guard let rawValue = pointer?.pointee else { return nil }

            self.init(rawValue: rawValue)
            self.index = index
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

        public var isConflict: Bool {
            git_index_entry_is_conflict(&rawValue) != 0
        }

        public var stage: Stage {
            Stage(rawValue: git_index_stage_t(git_index_entry_stage(&rawValue)))
        }

        // MARK: - Equatable

        public static func == (lhs: Repository.Index.Entry, rhs: Repository.Index.Entry) -> Bool {
            var loid = lhs.rawValue.id, roid = rhs.rawValue.id
            return git_oid_cmp(&loid, &roid) == 0
        }

        // MARK: - Comparable

        public static func < (lhs: Repository.Index.Entry, rhs: Repository.Index.Entry) -> Bool {
            return lhs.path < rhs.path
        }

        // MARK: - Hashable

        public func hash(into hasher: inout Hasher) {
            hasher.combine(rawValue.uid)
        }
    }

    final class Entries: Sequence, IteratorProtocol {
        private weak var index: Repository.Index?
        private(set) var pointer: OpaquePointer!

        init(_ index: Repository.Index) throws {
            try attempt { git_index_iterator_new(&pointer, index.pointer) }
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
                try attempt { git_index_iterator_next(&pointer, self.pointer) }
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

// MARK: - RandomAccessCollection

extension Repository.Index: RandomAccessCollection {
    public typealias Element = Entry

    public var startIndex: Int { 0 }
    public var endIndex: Int { git_index_entrycount(pointer) }

    public subscript(_ index: Int) -> Entry {
        precondition(indices.contains(index))
        return Entry(in: self, at: index)!
    }

    public subscript(_ path: String, stage: Stage = .normal) -> Entry? {
        return Entry(in: self, at: path, stage: stage)
    }
}
