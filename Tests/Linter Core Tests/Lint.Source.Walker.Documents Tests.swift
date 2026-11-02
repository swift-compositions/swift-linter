import File_System
import Foundation
import Testing

@testable import Linter_Core

extension Lint.Source.Walker.Test.Integration {
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
