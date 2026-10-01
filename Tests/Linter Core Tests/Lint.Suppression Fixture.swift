import File_System
import Foundation
import Lint

@testable import Linter_Core

extension Lint.Suppression.Test.`Engine Integration` {

  static func writeFixture(content: Swift.String) -> File.Path {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
      "lint-suppression-fixture-\(UUID().uuidString)"
    )
    let sources = directory.appendingPathComponent("Sources")

    try! FileManager.default.createDirectory(at: sources, withIntermediateDirectories: true)
    let file = sources.appendingPathComponent("x.swift")

    try! content.data(using: .utf8)!.write(to: file)

    return try! File.Path(directory.path)
  }
}
