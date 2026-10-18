import Testing

@testable import Linter_Core

extension Lint.File.Single.Test {
    @Suite
    struct Detection {
        @Suite struct `Edge Case` {}
    }
}

extension Lint.File.Single.Test.Detection.`Edge Case` {
    @Test
    func `tools version header is found with LF and CRLF line endings`() {
        let header = "// swift-linter-tools-version: 6.4"
        #expect(Lint.File.Single.Detection.hasMagicComment(in: "\(header)\nimport Linter\n"))
        #expect(Lint.File.Single.Detection.hasMagicComment(in: "\(header)\r\nimport Linter\r\n"))
        #expect(!Lint.File.Single.Detection.hasMagicComment(in: "import Linter\r\n"))
    }
}
