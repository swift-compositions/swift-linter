import File_System
import Foundation
import Testing

@testable import Linter_Core

extension `Lint.Source.Walker Tests`.Test.Integration {
    @Test
    func `documents(under:) lists every markdown file, catalogs included, outside build state`() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("walker-documents-\(UUID().uuidString)")
        let root = try File.Path(directory.path)
        let files = [
            "README.md", "Docs/Diagnostics.md", "Sources/Core/Core.docc/Core.md",
            ".build/checkouts/dependency/README.md", "Sources/Core/Value.swift",
        ]
        for file in files {
            let path = root / (try File.Path(file))
            try File.Directory(path.parent!).create.recursive()
            try File(path).write.atomic("x")
        }
        #expect(Lint.Source.Walker.documents(under: root) == ["README.md", "Docs/Diagnostics.md", "Sources/Core/Core.docc/Core.md"])
    }
}

extension `Lint.Source.Walker Tests`.Test.Integration {
    @Test
    func `packages(under:) lists each folder holding a nested package manifest, outside build state`() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("walker-packages-\(UUID().uuidString)")
        let root = try File.Path(directory.path)
        let files = [
            "Package.swift": "let package = Package(name: \"Root\")",
            "example-app/Package.swift": "let package = Package(name: \"App\")",
            "Tests/Fixture/Package.swift": "let package = Package(name: \"Fixture\")",
            "Sources/Core/Package.swift": "struct Package {}",
            ".build/checkouts/dependency/Package.swift": "let package = Package(name: \"Dependency\")",
        ]
        for (file, source) in files {
            let path = root / (try File.Path(file))
            try File.Directory(path.parent!).create.recursive()
            try File(path).write.atomic(source)
        }
        #expect(Lint.Source.Walker.packages(under: root) == ["example-app", "Tests/Fixture"])
    }
}
