import Clibgit2

/// A named reference to an object or another reference.
public final class Tag: Reference {
    /// The tag name.
    public override var name: String {
        return String(validatingUTF8: git_tag_name(pointer))!
    }

    /// The target of the reference.
    public override var target: Object? {
        var target: OpaquePointer?
        guard case .success = result(of: { git_tag_target(&target, self.pointer) }) else { return nil }
        return Object.type(of: git_tag_target_type(self.pointer))?.init(target!)
    }
}

// MARK: -

extension Tag {
    /// A tag annotation.
    public final class Annotation: Object {
        class override var type: git_object_t { return GIT_OBJECT_TAG }

        /// The target of the reference.
        var target: Object? {
            var target: OpaquePointer?
            guard case .success = result(of: { git_tag_target(&target, self.pointer) }) else { return nil }
            return Object.type(of: git_tag_target_type(self.pointer))?.init(target!)
        }

        /// The signature of the tag author.
        public var tagger: Signature {
            return Signature(rawValue: git_tag_tagger(pointer).pointee)
        }

        /// The tag message, if any.
        public var message: String? {
            return String(validatingUTF8: git_tag_message(pointer))
        }

        public func peel<T: Object>() throws -> T? {
            var pointer: OpaquePointer?
            try attempt { git_tag_peel(&pointer, self.pointer) }
            return T(pointer!)
        }
    }

//    /// The tag's annotation, if any.
//    public var annotation: Annotation? {
//        guard let id = target else { return nil }
//        return try? owner.lookup(id)
//    }
}

