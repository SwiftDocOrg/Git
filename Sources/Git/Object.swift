import Clibgit2
import struct Foundation.Data

///

/**
 A blob, commit, tree, or tag annotation.

 - SeeAlso: `Blob`
 - SeeAlso: `Commit`
 - SeeAlso: `Tree`
 - SeeAlso: `Tag.Revision`
 */
public class Object: Identifiable {
    class var type: git_object_t { return GIT_OBJECT_ANY }

    private(set) var pointer: OpaquePointer!

    private var managed: Bool = false

    required init(_ pointer: OpaquePointer) {
        self.pointer = pointer
        assert(Swift.type(of: self) != Object.self)
        assert(git_object_type(pointer) == Swift.type(of: self).type)
    }

    deinit {
        if managed {
            git_repository_free(pointer)
        }
    }

    class func type(of value: git_object_t?) -> Object.Type? {
        switch value {
        case GIT_OBJECT_ANY?:
            return Object.self
        case GIT_OBJECT_COMMIT?:
            return Commit.self
        case GIT_OBJECT_TREE?:
            return Tree.self
        case GIT_OBJECT_BLOB?:
            return Blob.self
        case GIT_OBJECT_TAG?:
            return Tag.Annotation.self
        // TODO:
        //        case GIT_OBJECT_OFS_DELTA,
        //             GIT_OBJECT_REF_DELTA:
        //            return Delta.self
        default:
            return nil
        }
    }

    /// The object's ID.
    public var id: ID {
        return ID(rawValue: git_object_id(pointer).pointee)
    }

    /// The repository containing the object.
    public var owner: Repository {
        return Repository(git_commit_owner(pointer))
    }

    /// The note attached to the object, if any.
    public var note: Note? {
        do {
            var pointer: OpaquePointer?
            let owner = git_commit_owner(self.pointer)
            var oid = id.rawValue
            try wrap { git_note_read(&pointer, owner, nil, &oid) }
            return Note(pointer!)
        } catch {
            return nil
        }
    }
}

// MARK: - Equatable

extension Object: Equatable {
    public static func == (lhs: Object, rhs: Object) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Hashable

extension Object: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}


// MARK: -

extension Object {
    /// An object ID.
    public struct ID: Equatable, Hashable, CustomStringConvertible, ExpressibleByStringLiteral /*: internal RawRepresentable*/ {
        let rawValue: git_oid

        init(rawValue: git_oid) {
            self.rawValue = rawValue
        }

        public init() {
            self.init(rawValue: git_oid())
        }

        public init<T>(_ body: (UnsafeMutablePointer<git_oid>) throws -> T) rethrows {
            var pointer = git_oid()
            _ = try body(&pointer)
            self.init(rawValue: pointer)
        }

        /// Creates an Object ID from a string.
        public init(string: String) throws {
            precondition(string.lengthOfBytes(using: .ascii) <= 40)
            let pointer = UnsafeMutablePointer<git_oid>.allocate(capacity: 1)
            defer { pointer.deallocate() }
            try wrap { git_oid_fromstr(pointer, string) }
            rawValue = pointer.pointee
        }

        /// Creates an Object ID from a byte array.
        public init(bytes: [UInt8]) throws {
            precondition(bytes.count <= 40)
            let pointer = UnsafeMutablePointer<git_oid>.allocate(capacity: 1)
            defer { pointer.deallocate() }
            try wrap { git_oid_fromraw(pointer, bytes) }
            rawValue = pointer.pointee
        }

        /// Creates an Object ID from data.
        public init(data: Data) throws {
            precondition(data.underestimatedCount <= 40)
            let bytes = data.withUnsafeBytes { $0.load(as: [UInt8].self) }
            try self.init(bytes: bytes)
        }

        // MARK: - Equatable

        public static func == (lhs: Object.ID, rhs: Object.ID) -> Bool {
            var loid = lhs.rawValue, roid = rhs.rawValue
            return git_oid_cmp(&loid, &roid) == 0
        }

        // MARK: - Hashable

        public func hash(into hasher: inout Hasher) {
            withUnsafeBytes(of: rawValue.id) {
                hasher.combine(bytes: $0)
            }
        }

        // MARK: - CustomStringConvertible

        public var description: String {
            let length = Int(GIT_OID_HEXSZ)
            let string = UnsafeMutablePointer<Int8>.allocate(capacity: length)
            var oid = self.rawValue
            git_oid_fmt(string, &oid)

            return String(bytesNoCopy: string, length: length, encoding: .ascii, freeWhenDone: true)!
        }

        // MARK: - ExpressibleByStringLiteral

        public init(stringLiteral value: StringLiteralType) {
            try! self.init(string: value)
        }
    }
}
