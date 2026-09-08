import File_System
import Linter
import Testing

extension Lint.File.Single.Test {
  @Suite
  struct `Local runner` {}
}

extension Lint.File.Single.Test.`Local runner` {
  @Test
  func `Unsupported selections fail before package evaluation or runner execution`() throws {
    let components = #filePath.split(separator: "/", omittingEmptySubsequences: false)
    let root = components.dropLast(3).joined(separator: "/")
    let fixture = try File.Path(root + "/Tests/Fixtures/local-unsupported")

    do throws(Lint.File.Single.Error) {
      _ = try Lint.File.Single.dispatch(
        at: fixture,
        arguments: [fixture.string],
        localRunner: "/this-runner-must-not-execute"
      )
      Issue.record("Unsupported selections must fail before dispatch")
    } catch {
      guard case .unsupportedLocalConfiguration(let reason) = error else {
        Issue.record("Unexpected dispatch error: \(error)")
        return
      }
      #expect(!reason.isEmpty)
    }
    #expect(!File.System.Stat.isDirectory(at: fixture / ".build"))
  }
}
