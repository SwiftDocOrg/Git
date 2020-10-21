// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Git",
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "Git",
            targets: ["Git"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
    ],
    targets: [
        .systemLibrary(name: "Clibgit2", pkgConfig: "libgit2", providers: [
            .brew(["libgit2"])
        ]),
        .target(
            name: "Git",
            dependencies: ["Clibgit2"]),
        .testTarget(
            name: "GitTests",
            dependencies: ["Git"]),
    ]
)
