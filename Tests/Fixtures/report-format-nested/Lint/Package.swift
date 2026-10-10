// swift-tools-version: 6.4

import PackageDescription

let package = Package(
  name: "report-format-nested-fixture",
  platforms: [.macOS(.v27)],
  dependencies: [
    .package(name: "swift-linter", path: "../../../..")
  ],
  targets: [
    .executableTarget(
      name: "Lint Runner",
      dependencies: [
        .product(name: "Linter", package: "swift-linter")
      ]
    )
  ],
  swiftLanguageModes: [.v6]
)
