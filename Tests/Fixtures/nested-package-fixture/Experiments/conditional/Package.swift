// swift-tools-version: 6.4

#if canImport(PackageDescription)
import PackageDescription

let package = Package(
    name: "conditional",
    targets: [.target(name: "Inner")]
)
#else
#error("PackageDescription is required")
#endif
