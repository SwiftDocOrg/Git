import Clibgit2
import Foundation

/// A file revision object.
public final class Blob: Object {
    class override var type: git_object_t { return GIT_OBJECT_BLOB }

    /// The repository containing the blob.
    public override var owner: Repository {
        return Repository(git_blob_owner(pointer))
    }

    /// Whether the blob is binary.
    public var isBinary: Bool {
        git_blob_is_binary(pointer) != 0
    }

    /// The size in bytes of the content
    public var size: Int {
        Int(git_blob_rawsize(pointer))
    }

    /// The blob contents.
    public var data: Data {
        return Data(bytes: git_blob_rawcontent(pointer), count: size)
    }
}
