import XCTest
@testable import Git
import Clibgit2
import Foundation

final class GitTests: XCTestCase {
    func testCloneAndReadRepository() throws {
        let remoteURL = URL(string: "https://github.com/SwiftDocOrg/StringLocationConverter.git")!

        let localURL = URL(fileURLWithPath: temporaryURL().path)
        try FileManager.default.createDirectory(at: localURL, withIntermediateDirectories: true)

        try Repository.clone(from: remoteURL, to: localURL)
        let repository = try Repository.open(at: localURL)

        let directoryURL = repository.workingDirectory
        XCTAssertNotNil(directoryURL)

        do {
            let head = repository.head
            XCTAssertEqual(head?.branch?.name, "refs/heads/master")
            XCTAssertEqual(head?.attached, true)

            let tree = head?.branch?.commit?.tree
            XCTAssertEqual(tree?.count, 6)

            XCTAssert(tree?["README.md"]?.object is Blob)
            XCTAssert(tree?["Sources"]?.object is Tree)

            do {
                let blob = tree?["README.md"]?.object as? Blob
                XCTAssertNotNil(blob)

                let string = String(data: blob!.data, encoding: .utf8)
                XCTAssert(string!.starts(with: "# StringLocationConverter"))
            }

            do {
                let subtree = tree?["Sources"]?.object as? Tree
                XCTAssertNotNil(subtree)

                XCTAssertEqual(subtree?.count, 1)
                XCTAssertNotNil(subtree?["StringLocationConverter"])
                XCTAssert(subtree?["StringLocationConverter"]?.object is Tree)
            }
        }

        do {
            let master = try repository.branch(named: "refs/heads/master")
            XCTAssertEqual(master?.shortName, "master")
            XCTAssertEqual(master?.commit?.message?.trimmingCharacters(in: .whitespacesAndNewlines), "Initial commit")
            XCTAssertEqual(master?.commit?.id.description, "6cf6579c191e20a5a77a7e3176d37a8d654c9fc4")
            XCTAssertEqual(master?.commit?.author.name, "Mattt")
        }

        do {
            let index = repository.index
            let entries = index?.entries.compactMap { $0.blob }
            XCTAssertEqual(entries?.count, 9)

            let revisions = try repository.revisions { walker in
                try walker.pushHead()
            }

            XCTAssertEqual(Array(revisions.compactMap { $0.message }), ["Initial commit\n"])
        }
    }

    func testCreateAndCommitToRepository() throws {
        let localURL = URL(fileURLWithPath: temporaryURL().path)
        try FileManager.default.createDirectory(at: localURL, withIntermediateDirectories: true)
        let repository = try Repository.create(at: localURL)

        try """
        Hello, world!
        """.write(toFile: localURL.appendingPathComponent("hello.txt").path, atomically: true, encoding: .utf8)

        try repository.add(paths: ["hello.txt"])

        let signature = try Signature(name: "Mona Lisa Octocat", email: "mona@github.com")
        let commit = try repository.commit(message: "Initial commit", author: signature, committer: signature)

        XCTAssertEqual(repository.head?.commit, commit)
        XCTAssertEqual(commit.message, "Initial commit")

        let tree = commit.tree
        XCTAssertNotNil(tree)
        XCTAssertEqual(tree?.count, 1)
        XCTAssertNotNil(tree?["hello.txt"])

        let blob = tree?["hello.txt"]?.object as? Blob
        XCTAssertNotNil(blob)
        XCTAssertEqual(String(data: blob!.data, encoding: .utf8), "Hello, world!")
    }
}

// MARK: -

fileprivate func temporaryURL() -> URL {
    let globallyUniqueString = ProcessInfo.processInfo.globallyUniqueString
    let path = "\(NSTemporaryDirectory())\(globallyUniqueString)"
    return URL(fileURLWithPath: path)
}
