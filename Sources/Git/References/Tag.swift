import Clibgit2

/// A named reference to an object or another reference.
public final class Tag: Reference {
    /// A tag annotation.
    public final class Annotation: Object {
        class override var type: git_object_t { return GIT_OBJECT_TAG }

        /// The tag name.
        public var name: String? {
            return String(validatingUTF8: git_tag_name(pointer))
        }

        /// The signature of the tag author.
        public var tagger: Signature {
            return Signature(rawValue: git_tag_tagger(pointer).pointee)
        }

        /// The tag message, if any.
        public var message: String? {
            return String(validatingUTF8: git_tag_message(pointer))
        }
    }

    /// The tag's annotation, if any.
    public var annotation: Annotation? {
        var pointer: OpaquePointer?
        let owner = git_reference_owner(pointer)
        var oid = git_reference_target(pointer).pointee
        do {
            try wrap { git_object_lookup(&pointer, owner, &oid, GIT_OBJECT_TAG) }
        } catch {
            return nil
        }

        return Annotation(pointer!)
    }
}

