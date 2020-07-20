import Clibgit2
import Foundation

/// A file revision object.
public final class Blob: Object {
    class override var type: git_object_t { return GIT_OBJECT_BLOB }

    /// The blob contents.
    public var data: Data {
        let length = Int(git_blob_rawsize(pointer))
        return Data(bytes: git_blob_rawcontent(pointer), count: length)
    }
}
