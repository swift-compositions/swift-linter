import Environment
import JSON
import Kernel
import Linter
import Linter_Reporter_Structured
import Testing

extension Lint.Reporter.Format {
    @Suite(.serialized)
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Reporter.Format.Test {
    fileprivate static func withVariable(_ value: Swift.String?, body: () -> Swift.Void) {
        do throws(Kernel.Environment.Error) {
            if let value {
                try Environment.write(Lint.Reporter.Format.Channel.variable, to: value)
            } else {
                try Environment.write.unset(Lint.Reporter.Format.Channel.variable)
            }
        } catch {
            Issue.record("environment setup failed: \(error)")
            return
        }
        defer {
            do throws(Kernel.Environment.Error) {
                try Environment.write.unset(Lint.Reporter.Format.Channel.variable)
            } catch {
                Issue.record("environment cleanup failed: \(error)")
            }
        }
        body()
    }

    fileprivate static func finding() -> Lint.Finding {
        Lint.Finding(
            record: Diagnostic.Record(
                location: Source.Location(
                    fileID: "Module/Foo.swift",
                    filePath: "Sources/Foo.swift",
                    line: 10,
                    column: 5
                ),
                severity: .warning,
                identifier: "fixture rule",
                message: "fixture message"
            )
        )
    }
}

extension Lint.Reporter.Format.Test.Integration {
    @Test
    func `Unset channel preserves text compatibility`() {
        Lint.Reporter.Format.Test.withVariable(nil) {
            do throws(Lint.Reporter.Format.Channel.Error) {
                let format = try Lint.Reporter.Format.Channel.read()
                #expect(format == .text)
            } catch {
                Issue.record("unexpected channel read failure: \(error)")
            }
        }
    }

    @Test
    func `Every explicit format round trips through the channel`() {
        for format in Lint.Reporter.Format.allCases {
            Lint.Reporter.Format.Test.withVariable(
                Lint.Reporter.Format.Channel.value(format)
            ) {
                do throws(Lint.Reporter.Format.Channel.Error) {
                    let decoded = try Lint.Reporter.Format.Channel.read()
                    #expect(decoded == format)
                } catch {
                    Issue.record("unexpected channel read failure: \(error)")
                }
            }
        }
    }
}

extension Lint.Reporter.Format.Test.`Edge Case` {
    @Test
    func `Corrupt channel throws instead of silently substituting text`() {
        Lint.Reporter.Format.Test.withVariable("checkstyle") {
            #expect(
                throws: Lint.Reporter.Format.Channel.Error.invalid(value: "checkstyle")
            ) {
                try Lint.Reporter.Format.Channel.read()
            }
        }
    }

    @Test
    func `Empty SARIF selection remains a valid document with no results`() throws(JSON.Error) {
        let report = Lint.Reporter.Format.sarif.report(for: [])
        let document = try JSON.parse(report)
        #expect(document.runs[0].results.array?.isEmpty == true)
    }
}

extension Lint.Reporter.Format.Test.Unit {
    @Test
    func `Structured selection emits one self-consistent document`() throws(JSON.Error) {
        let findings = [Lint.Reporter.Format.Test.finding()]
        let report = Lint.Reporter.Format.structured.report(for: findings)
        let document = try JSON.parse(report)

        #expect(Swift.Int(document.schema) == 2)
        #expect(document.files.array?.isEmpty == true)
        #expect(document.activeRules.array?.isEmpty == true)
        #expect(document.applicableRules.array?.isEmpty == true)
        #expect(document.observations.array?.isEmpty == true)
        #expect(document.controls.array?.isEmpty == true)
        #expect(document.findings.array?.count == 1)
        #expect(Swift.Int(document.summary.findings) == 1)
        #expect(Swift.Int(document.summary.files) == 0)
        #expect(Swift.Int(document.summary.activeRules) == 0)
        #expect(Swift.Int(document.summary.applicableRules) == 0)
    }

    @Test
    func `Explicit text selection preserves the canonical text report`() {
        let findings = [Lint.Reporter.Format.Test.finding()]
        let selected = Lint.Reporter.Format.text.report(for: findings)
        #expect(selected == Lint.Reporter.Text.report(for: findings))
        #expect(selected.hasPrefix("Sources/Foo.swift:10:5: warning: fixture rule:"))
    }

    @Test
    func `SARIF selection produces one structured result per finding`() throws(JSON.Error) {
        let report = Lint.Reporter.Format.sarif.report(
            for: [Lint.Reporter.Format.Test.finding()]
        )
        let document = try JSON.parse(report)
        let results = document.runs[0].results.array
        #expect(Swift.String(document.version) == "2.1.0")
        #expect(results?.count == 1)
        #expect(Swift.String(results?[0].ruleId) == "fixture rule")
        #expect(Swift.String(results?[0].level) == "warning")
        #expect(Swift.String(results?[0].message.text) == "fixture message")
    }
}
