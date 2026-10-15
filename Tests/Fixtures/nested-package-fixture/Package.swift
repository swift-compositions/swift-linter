// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "nested-package-fixture",
    targets: [
        .target(name: "Outer"),
        .target(name: "Package"),
        .target(name: "Quoted"),
    ]
)
