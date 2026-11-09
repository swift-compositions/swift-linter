import File_System
import Linter
import Testing

@testable import Linter_Core

enum `Lint.Driver Tests` {}

extension `Lint.Driver Tests` {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension `Lint.Driver Tests`.Test {
    @Suite struct `Configuration From Manifest` {}
}

extension `Lint.Driver Tests`.Test.`Configuration From Manifest` {
    @Test
    func `Empty manifest with nil parent produces empty effective rules`() {
        let manifest = Lint.Manifest()
        let configuration = Lint.Driver.configuration(from: manifest, parent: nil)
        #expect(configuration.rules.effective.entries.isEmpty)
    }

    @Test
    func `Manifest enabledRuleIDs are silently ignored at engine layer`() {

        let manifest = Lint.Manifest(enabled: ["unchecked_call_site"])
        let configuration = Lint.Driver.configuration(from: manifest, parent: nil)
        #expect(configuration.rules.effective.entries.isEmpty)
    }

    @Test
    func `Manifest disabledRuleIDs are silently ignored at engine layer`() {

        let manifest = Lint.Manifest(
            disabled: ["unchecked_call_site"]
        )
        let configuration = Lint.Driver.configuration(from: manifest, parent: nil)
        #expect(configuration.rules.effective.entries.isEmpty)
    }

    @Test
    func `Child Configuration inherits from parent reference`() {

        let parentManifest = Lint.Manifest(enabled: ["unchecked_call_site"])
        let parentConfiguration = Lint.Driver.configuration(
            from: parentManifest,
            parent: nil
        )
        let childManifest = Lint.Manifest()
        let childConfiguration = Lint.Driver.configuration(
            from: childManifest,
            parent: parentConfiguration
        )
        #expect(childConfiguration.rules.effective.entries.isEmpty)
    }

    @Test
    func `Excluded paths are carried through to Configuration`() throws(Path::Path.Error) {
        let manifest = Lint.Manifest(
            excluded: [
                File.Path("Tests/Fixtures"),
                File.Path(".build"),
            ]
        )
        let configuration = Lint.Driver.configuration(from: manifest, parent: nil)
        #expect(configuration.excluded == ["Tests/Fixtures", ".build"])
    }

    @Test
    func `Unknown rule ID is silently ignored`() {

        let manifest = Lint.Manifest(enabled: ["nonexistent_rule"])
        let configuration = Lint.Driver.configuration(from: manifest, parent: nil)
        #expect(configuration.rules.effective.entries.isEmpty)
    }
}

extension `Lint.Driver Tests`.Test {
    @Suite struct `Enabled Rules Without Header` {}
}

extension `Lint.Driver Tests`.Test.`Enabled Rules Without Header` {
    @Test
    func `A manifest without enabled rules passes the check`() throws(Lint.Driver.Error) {
        try Lint.Driver.check(enabled: [], in: "Lint.swift")
    }

    @Test
    func `Enabled rules in a manifest without the tools-version header are refused`() {
        #expect {
            try Lint.Driver.check(enabled: ["unchecked_call_site"], in: "Lint.swift")
        } throws: { error in
            guard case Lint.Driver.Error.resolutionFailed(let description) = error else { return false }
            return description.contains("unchecked_call_site")
                && description.contains(Lint.File.Single.Detection.header)
        }
    }
}
