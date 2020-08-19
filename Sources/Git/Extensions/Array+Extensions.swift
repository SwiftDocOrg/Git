import Clibgit2
import Foundation

extension Array where Element == String {
    @discardableResult
    func withGitStringArray<T>(_ body: (git_strarray) throws -> T) rethrows -> T {
        let cStrings = UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>.allocate(capacity: count)
        defer { cStrings.deallocate() }

        for (index, string) in enumerated() {
            cStrings.advanced(by: index).pointee = strdup(string.cString(using: .utf8)!)
        }

        return try body(git_strarray(strings: cStrings, count: count))
    }
}
