# Git

A package for working with Git repositories in Swift,
built on top of [libgit2](https://libgit2.org).

> **Warning**:
> This is currently a work-in-progress and shouldn't be used in production.

## Requirements

- Swift 5.2

## Usage

```swift
import Git
import Foundation

let remoteURL = URL(string: "https://github.com/SwiftDocOrg/StringLocationConverter.git")!
let localURL = URL(fileURLWithPath: "<#path/to/repository#>")
let repository = try Repository.clone(from: remoteURL, to: localURL)

repository.head?.name // "refs/heads/master"

let master = try repository.branch(named: "refs/heads/master")
master?.shortName// "master"
master?.commit?.message // "Initial commit"
master?.commit?.id.description // "6cf6579c191e20a5a77a7e3176d37a8d654c9fc4"
master?.commit?.author.name // "Mattt"

let tree = master?.commit?.tree
tree.count // 6

tree?["README.md"]?.object is Blob // true
let blob = tree?["README.md"]?.object as? Blob
String(data: blob!.data, encoding: .utf8) // "# StringLocationConverter (...)"

tree?["Sources"]?.object is Tree // true
let subtree = tree?["Sources"]?.object as? Tree
subtree?.count // 1
subtree?["StringLocationConverter"]?.object is Tree // true


let index = repository.index
let entries = index?.entries.compactMap { $0.blob }
entries?.count // 9
```

## License

MIT

## Contact

Mattt ([@mattt](https://twitter.com/mattt))
