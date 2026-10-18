import File_System
import Foundation
import Lint
import Testing

@testable import Linter_Core

extension Lint.Suppression.Test.`Engine Integration` {

    static func writeFixture(content: Swift.String) -> File.Path? {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "lint-suppression-fixture-\(UUID().uuidString)"
        )
        let root: File.Path
        do throws(File.Path.Error) {
            root = try File.Path(directory.path)
        } catch {
            Issue.record("suppression fixture path unavailable: \(error)")
            return nil
        }
        let sources = root / "Sources"
        do throws(File.System.Create.Directory.Error) {
            try File.Directory(sources).create.recursive()
        } catch {
            Issue.record("suppression fixture directory creation failed: \(error)")
            return nil
        }
        do throws(File.System.Write.Atomic.Error) {
            try File(sources / "x.swift").write.atomic(content)
        } catch {
            Issue.record("suppression fixture write failed: \(error)")
            return nil
        }
        return root
    }
}
