import Clibgit2
import Foundation

/**
 An action signature (e.g. for committers, taggers, etc).
 */
public struct Signature /*: internal RawRepresentable*/ {
    var rawValue: git_signature

    init(rawValue: git_signature) {
        self.rawValue = rawValue
    }

    public static func `default`(for repository: Repository) throws -> Signature {
        let pointer =  UnsafeMutablePointer<UnsafeMutablePointer<git_signature>?>.allocate(capacity: 1)
        defer { pointer.deallocate() }
        try attempt { git_signature_default(pointer, repository.pointer) }

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
    public init(name: String,
                email: String,
                time: Date = Date(),
                timeZone: TimeZone = TimeZone.current) throws
    {
        var pointer: UnsafeMutablePointer<git_signature>?
        let offset = Int32(timeZone.secondsFromGMT(for: time) / 60)
        let time = git_time_t(time.timeIntervalSince1970)
        try attempt { git_signature_new(&pointer, name, email, time, offset) }
        self.init(rawValue: pointer!.pointee)
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

// MARK: - Codable

extension Signature: Codable {
    private enum CodingKeys: String, CodingKey {
        case name
        case email
        case time
        case timeZone
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let name = try container.decode(String.self, forKey: .name)
        let email = try container.decode(String.self, forKey: .email)
        let time = try container.decode(Date.self, forKey: .time)
        let timeZone = try container.decode(TimeZone.self, forKey: .timeZone)

        try self.init(name: name, email: email, time: time, timeZone: timeZone)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(email, forKey: .email)
        try container.encode(time, forKey: .time)
        try container.encode(timeZone, forKey: .timeZone)
    }
}
