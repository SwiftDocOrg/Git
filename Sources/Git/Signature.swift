import Clibgit2
import Foundation

/**
 An action signature (e.g. for committers, taggers, etc).
 */
public class Signature /*: internal RawRepresentable*/ {
    var rawValue: git_signature
    var managed: Bool = false

    init(rawValue: git_signature) {
        self.rawValue = rawValue
    }

    deinit {
        guard managed else { return }
        git_signature_free(&rawValue)
    }

    public static func `default`(for repository: Repository) throws -> Signature {
        let pointer =  UnsafeMutablePointer<UnsafeMutablePointer<git_signature>?>.allocate(capacity: 1)
        defer { pointer.deallocate() }
        try wrap { git_signature_default(pointer, repository.pointer) }

        return Signature(rawValue: pointer.pointee!.pointee)
    }

    // MARK: -

    /**
     Creates a signature with the specified name, email, time, and time zone.

     - Parameters:
        - name: The name of the signer.
        - email: The email of the signer.
        - time: The time at which the action occurred.
        - timeZone: The time's corresponding time zone.
     */
    public convenience init(name: String,
                            email: String,
                            time: Date = Date(),
                            timeZone: TimeZone = TimeZone.current) throws
    {
        var pointer: UnsafeMutablePointer<git_signature>?
        let offset = Int32(timeZone.secondsFromGMT(for: time) / 60)
        let time = git_time_t(time.timeIntervalSince1970)
        try wrap { git_signature_new(&pointer, name, email, time, offset) }
        self.init(rawValue: pointer!.pointee)
        managed = true
    }

    /// The name of the signer.
    public var name: String {
        return String(validatingUTF8: rawValue.name)!
    }

    /// The email of the signer.
    public var email: String {
        String(validatingUTF8: rawValue.email)!
    }

    /// The time at which the action occurred.
    public var time: Date {
        return Date(timeIntervalSince1970: TimeInterval(rawValue.when.time))
    }

    /// The time's corresponding time zone.
    public var timeZone: TimeZone? {
        return TimeZone(secondsFromGMT: 60 * Int(rawValue.when.offset))
    }
}

// MARK: - Equatable

extension Signature: Equatable {
    public static func == (lhs: Signature, rhs: Signature) -> Bool {
        return (lhs.name, lhs.email, lhs.time, lhs.timeZone) == (rhs.name, rhs.email, rhs.time, rhs.timeZone)
    }
}

// MARK: - Hashable

extension Signature: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(email)
        hasher.combine(rawValue.when.time)
        hasher.combine(rawValue.when.offset)
    }
}
