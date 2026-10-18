import File_System
import Linter
import Testing

@testable import Linter_Core

extension Lint.Run {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
        @Suite struct `Brand Pre-Pass` {}
    }
}

extension Lint.Rule {
    fileprivate static let `brand aware fixture` = Lint.Rule(
        id: "brand aware fixture",
        default: .warning,
        controls: [
            .init(
                id: "brand aware fixture fires without the brand",
                source: "let value = 0",
                path: "Fixture.swift",
                expectation: .findings(1)
            )
        ],
        observe: Lint.Rule.measured { source, severity in
            if Lint.Brand.owned(["Cardinal"], in: source) { return [] }
            return [
                Diagnostic.Record(
                    location: Source.Location(
                        fileID: source.file.fileID,
                        filePath: source.file.filePath,
                        line: 1,
                        column: 1
                    ),
                    severity: severity,
                    identifier: "brand aware fixture",
                    message: "brand aware fixture rule fired"
                )
            ]
        }
    )
}

extension Lint.Run.Test.`Brand Pre-Pass` {
    private static func fixtureRoot(
        _ name: Swift.String,
        testFile: Swift.String = #filePath
    ) throws(Paths.Path.Error) -> File.Path {
        var components: [Swift.String] =
            testFile
            .split(omittingEmptySubsequences: false, whereSeparator: { $0 == "/" || $0 == "\\" })
            .map(Swift.String.init)
        _ = components.popLast()
        _ = components.popLast()
        components.append("Fixtures")
        components.append(name)
        return try File.Path(components.joined(separator: "/"))
    }

    @Test
    func `brand owner run self-suppresses across files`() throws(Lint.Run.Error) {

        let root: File.Path
        do throws(Paths.Path.Error) {
            root = try Self.fixtureRoot("brand-prepass-fixture")
        } catch {
            Issue.record("fixture root unavailable: \(error)")
            return
        }
        let configuration = Lint.Configuration {
            .enable(.`brand aware fixture`)
        }
        let findings = try Lint.Run.run(paths: [root], configuration: configuration)
        #expect(findings.count == 0)
    }

    @Test
    func `consumer run without the brand still fires`() throws(Lint.Run.Error) {

        let root: File.Path
        do throws(Paths.Path.Error) {
            root = try Self.fixtureRoot("brand-consumer-fixture")
        } catch {
            Issue.record("fixture root unavailable: \(error)")
            return
        }
        let configuration = Lint.Configuration {
            .enable(.`brand aware fixture`)
        }
        let findings = try Lint.Run.run(paths: [root], configuration: configuration)
        #expect(findings.count == 1)
    }
}

extension Lint.Rule {
    fileprivate static let `test fixture` = Lint.Rule(
        id: "test fixture",
        default: .warning,
        controls: [
            .init(
                id: "test fixture run fires",
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

extension Lint.Run.Test.Integration {

    private static func fixtureRoot(
        testFile: Swift.String = #filePath
    ) throws(Paths.Path.Error) -> File.Path {

        var components: [Swift.String] =
            testFile
            .split(omittingEmptySubsequences: false, whereSeparator: { $0 == "/" || $0 == "\\" })
            .map(Swift.String.init)
        _ = components.popLast()
        _ = components.popLast()
        components.append("Fixtures")
        components.append("path-filter-fixture")
        return try File.Path(components.joined(separator: "/"))
    }

    @Test
    func `paths .all yields findings for both A and B`() throws(Lint.Run.Error) {

        let root: File.Path
        do throws(Paths.Path.Error) {
            root = try Self.fixtureRoot()
        } catch {
            Issue.record("fixture root unavailable: \(error)")
            return
        }
        let configuration = Lint.Configuration {
            .enable(.`test fixture`, paths: .all)
        }
        let findings = try Lint.Run.run(paths: [root], configuration: configuration)
        #expect(findings.count == 2)
    }

    @Test
    func `paths .including A yields finding for A only`() throws(Lint.Run.Error) {

        let root: File.Path
        do throws(Paths.Path.Error) {
            root = try Self.fixtureRoot()
        } catch {
            Issue.record("fixture root unavailable: \(error)")
            return
        }
        let configuration = Lint.Configuration {
            .enable(.`test fixture`, paths: .including(["Sources/A"]))
        }
        let findings = try Lint.Run.run(paths: [root], configuration: configuration)
        #expect(findings.count == 1)
        #expect(findings.first?.record.location.filePath?.replacing("\\", with: "/").hasSuffix("/Sources/A/x.swift") == true)
    }

    @Test
    func `paths .excluding B yields finding for A only`() throws(Lint.Run.Error) {

        let root: File.Path
        do throws(Paths.Path.Error) {
            root = try Self.fixtureRoot()
        } catch {
            Issue.record("fixture root unavailable: \(error)")
            return
        }
        let configuration = Lint.Configuration {
            .enable(.`test fixture`, paths: .excluding(["Sources/B"]))
        }
        let findings = try Lint.Run.run(paths: [root], configuration: configuration)
        #expect(findings.count == 1)
        #expect(findings.first?.record.location.filePath?.replacing("\\", with: "/").hasSuffix("/Sources/A/x.swift") == true)
    }

    @Test
    func `paths .including non-matching yields no findings`() throws(Lint.Run.Error) {

        let root: File.Path
        do throws(Paths.Path.Error) {
            root = try Self.fixtureRoot()
        } catch {
            Issue.record("fixture root unavailable: \(error)")
            return
        }
        let configuration = Lint.Configuration {
            .enable(.`test fixture`, paths: .including(["Tests/Fixtures/Other"]))
        }
        let findings = try Lint.Run.run(paths: [root], configuration: configuration)
        #expect(findings.count == 0)
    }
}

extension Lint.Run.Test.Unit {
    private static func licenseRoot(key: Swift.String) -> File.Path? {
        let root: File.Path
        do throws(File.Path.Error) {
            root = try File.Path.Temporary.deterministic(prefix: "lint-license-root-", key: key, suffix: "")
        } catch {
            Issue.record("temporary license root unavailable: \(error)")
            return nil
        }
        do throws(File.System.Create.Directory.Error) {
            try File.Directory(root).create.recursive()
        } catch {
            Issue.record("license root creation failed: \(error)")
            return nil
        }
        return root
    }

    @Test
    func `the package license is read from LICENSE.md, then LICENSE`() throws(File.System.Write.Atomic.Error) {
        guard let markdown = Self.licenseRoot(key: "markdown") else { return }
        try File(markdown / "LICENSE.md").write.atomic("Apache License")
        #expect(Lint.Run.license(at: markdown) == .text("Apache License"))
        guard let plain = Self.licenseRoot(key: "plain") else { return }
        try File(plain / "LICENSE").write.atomic("MIT License")
        #expect(Lint.Run.license(at: plain) == .text("MIT License"))
    }

    @Test
    func `a package without a license file reads as absent`() {
        guard let root = Self.licenseRoot(key: "absent") else { return }
        #expect(Lint.Run.license(at: root) == .absent)
    }
}
