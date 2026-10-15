import File_System
import Linter
import Testing

@testable import Linter_Core

extension Lint.Source.Walker {
  @Suite
  struct Test {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
    @Suite struct Integration {}
    @Suite(.serialized) struct Performance {}
  }
}

extension Lint.Rule {
  fileprivate static let `test fixture` = Lint.Rule(
    id: "test fixture",
    default: .warning,
    controls: [
      .init(
        id: "test fixture walker fires",
        source: "let value = 0",
        path: "Fixture.swift",
        expectation: .findings(1)
      )
    ],
    observe: Lint.Rule.measured { source, severity in
      [
        Diagnostic.Record(
          location: Source.Location(
            fileID: source.file.fileID,
            filePath: source.file.filePath,
            line: 1,
            column: 1
          ),
          severity: severity,
          identifier: "test fixture",
          message: "fixture rule fired"
        )
      ]
    }
  )
}

extension Lint.Source.Walker.Test {

  fileprivate static func fixtureRoot(
    testFile: Swift.String = #filePath
  ) throws(Paths.Path.Error) -> File.Path {
    var components: [Swift.String] =
      testFile
      .split(omittingEmptySubsequences: false, whereSeparator: { $0 == "/" || $0 == "\\" })
      .map(Swift.String.init)
    _ = components.popLast()
    _ = components.popLast()
    components.append("Fixtures")
    components.append("nested-package-fixture")
    return try File.Path(components.joined(separator: "/"))
  }
}

extension Lint.Source.Walker.Test.Unit {
  @Test
  func `paths(under:) preserves production Package files and skips package subtrees`() {

    let root = try! Lint.Source.Walker.Test.fixtureRoot()
    let paths = Lint.Source.Walker.paths(under: root).map(\.underlying)
    #expect(
      paths == [
        "Package.swift",
        "Sources/Outer/x.swift",
        "Sources/Package/Package.Name.swift",
        "Sources/Package/Package.swift",
        "Sources/Package/Product.Name.swift",
        "Sources/Package/Product.swift",
        "Sources/Package/Target.Name.swift",
        "Sources/Package/Target.swift",
        "Sources/Package/exports.swift",
        "Sources/Quoted/Package.swift",
        "Sources/Quoted/Value.swift",
      ]
    )
  }
}

extension Lint.Source.Walker.Test.`Edge Case` {
  @Test(arguments: [
    "import PackageDescription\nlet package = Package(name: \"Inner\")",
    "// swift-tools-version: 6.4\r\nimport PackageDescription\r\nlet package = makePackage()",
    "let package = Package(name: \"Incomplete Fixture\")",
    "import struct PackageDescription.Package\nlet package: Package = .init(name: \"Inner\")",
  ])
  func `manifest syntax establishes a nested package boundary`(_ source: Swift.String) {
    #expect(Lint.Source.Walker.isPackageManifest(source))
  }

  @Test(arguments: [
    "public enum Package: Swift.Sendable {}",
    "extension Package { public enum Target {} }",
    "let example = \"import PackageDescription\\nlet package = Package(name: \\\"Inner\\\")\"",
    "// import PackageDescription\n// let package = Package(name: \"Inner\")\npublic enum Package {}",
    "struct Namespace { let package = Package(name: \"Value\") }",
  ])
  func `ordinary source does not establish a nested package boundary`(_ source: Swift.String) {
    #expect(!Lint.Source.Walker.isPackageManifest(source))
  }
}

extension Lint.Source.Walker.Test.Integration {
  @Test
  func `Lint.Run.run does not visit files inside a nested-package subtree`() throws(Lint.Run
    .Error)
  {

    let root = try! Lint.Source.Walker.Test.fixtureRoot()
    let configuration = Lint.Configuration {
      .enable(.`test fixture`, paths: .all)
    }
    let findings = try Lint.Run.run(paths: [root], configuration: configuration)

    #expect(findings.count == 11)
    let paths = Set(findings.compactMap(\.record.location.filePath))
    #expect(paths.contains(where: { $0.replacing("\\", with: "/").hasSuffix("/nested-package-fixture/Package.swift") }))
    #expect(paths.contains(where: { $0.replacing("\\", with: "/").hasSuffix("/Sources/Outer/x.swift") }))
    #expect(paths.filter { $0.replacing("\\", with: "/").contains("/Sources/Package/") }.count == 7)
    #expect(paths.contains(where: { $0.replacing("\\", with: "/").hasSuffix("/Sources/Quoted/Value.swift") }))
    #expect(paths.allSatisfy { !$0.replacing("\\", with: "/").contains("/Experiments/inner/") })
    #expect(paths.allSatisfy { !$0.replacing("\\", with: "/").contains("/Experiments/headerless/") })
    #expect(paths.allSatisfy { !$0.replacing("\\", with: "/").contains("/Outer.docc/") })
  }
}
