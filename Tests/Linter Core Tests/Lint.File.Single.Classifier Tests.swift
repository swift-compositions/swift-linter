import Linter
import Testing

@testable import Linter_Core

extension Lint.File.Single.Classifier {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.File.Single.Classifier.Test {

    private static let baked: Swift.Set<Lint.Rule.Bundle.Baked> = ["alpha", "beta", "gamma"]

    private func isEvalFallback(_ classification: Lint.File.Single.Classification) -> Swift.Bool {
        if case .evalFallback = classification { return true }
        return false
    }

    private func excluded(
        _ classification: Lint.File.Single.Classification
    ) -> (bundle: Lint.Rule.Bundle.Baked, disabled: Swift.Set<Lint.Rule.ID>)? {
        if case .fastPathStandardBundleExcluding(let bundle, let disabled) = classification {
            return (bundle: bundle, disabled: disabled)
        }
        return nil
    }

    @Test
    func `Bare alpha bundle in a trailing closure is the fast path`() {
        let source = """
            // swift-linter-tools-version: 0.1
            import Linter
            import Fixture_Rules

            Lint.run(dependencies: [
                .package(path: "../swift-fixture-linter-rules", products: ["Fixture Rules"])
            ]) {
                Lint.Rule.Bundle.alpha
            }
            """
        #expect(
            Lint.File.Single.Classifier.classify(source: source, baked: Self.baked)
                == .fastPathStandardBundle(bundle: "alpha")
        )
    }

    @Test
    func `Bare alpha bundle in a rules-labelled closure is the fast path`() {
        let source = """
            // swift-linter-tools-version: 0.1
            import Linter
            import Fixture_Rules

            Lint.run(dependencies: [
                .package(path: "../swift-fixture-linter-rules", products: ["Fixture Rules"])
            ], rules: {
                Lint.Rule.Bundle.alpha
            })
            """
        #expect(
            Lint.File.Single.Classifier.classify(source: source, baked: Self.baked)
                == .fastPathStandardBundle(bundle: "alpha")
        )
    }

    @Test
    func `Excluding with string-literal IDs is fast path with exact exclusions`() {

        let source = """
            // swift-linter-tools-version: 0.1
            import Linter
            import Fixture_Rules

            Lint.run(dependencies: [
                .package(path: "../swift-fixture-linter-rules", products: ["Fixture Rules"])
            ]) {
                Lint.Rule.Bundle.alpha.excluding(rules: [
                    "raw value access",
                    "chained rawvalue access",
                    "int public parameter",
                    "pointer advanced by",
                ])
            }
            """
        let expected: Swift.Set<Lint.Rule.ID> = [
            "raw value access", "chained rawvalue access", "int public parameter",
            "pointer advanced by",
        ]
        #expect(
            excluded(Lint.File.Single.Classifier.classify(source: source, baked: Self.baked))?.disabled == expected
        )
    }

    @Test
    func `Excluding with .id-accessor IDs is fast path with exact exclusions`() {

        let source = """
            // swift-linter-tools-version: 0.1
            import Linter
            import Fixture_Rules
            import Fixture_Rule_RawValue

            Lint.run(dependencies: [
                .package(path: "../swift-fixture-linter-rules", products: ["Fixture Rules"])
            ]) {
                Lint.Rule.Bundle.alpha.excluding(rules: [
                    Lint.Rule.`raw value access`.id,
                    Lint.Rule.`chained rawvalue access`.id,
                    Lint.Rule.`unchecked call site`.id,
                ])
            }
            """
        let expected: Swift.Set<Lint.Rule.ID> = [
            "raw value access", "chained rawvalue access", "unchecked call site",
        ]
        #expect(
            excluded(Lint.File.Single.Classifier.classify(source: source, baked: Self.baked))?.disabled == expected
        )
    }

    @Test
    func `Excluding with mixed string and .id forms extracts both exactly`() {
        let source = """
            // swift-linter-tools-version: 0.1
            import Linter
            import Fixture_Rules

            Lint.run(dependencies: [
                .package(path: "../swift-fixture-linter-rules", products: ["Fixture Rules"])
            ]) {
                Lint.Rule.Bundle.alpha.excluding(rules: [
                    "raw value access",
                    Lint.Rule.`pointer advanced by`.id,
                ])
            }
            """
        let expected: Swift.Set<Lint.Rule.ID> = ["raw value access", "pointer advanced by"]
        #expect(
            excluded(Lint.File.Single.Classifier.classify(source: source, baked: Self.baked))?.disabled == expected
        )
    }

    @Test
    func `Excluding with an unreadable element falls back to eval (never guess)`() {

        let source = """
            // swift-linter-tools-version: 0.1
            import Linter
            import Fixture_Rules

            Lint.run(dependencies: [
                .package(path: "../swift-fixture-linter-rules", products: ["Fixture Rules"])
            ]) {
                Lint.Rule.Bundle.alpha.excluding(rules: [
                    "raw value access",
                    someComputedRuleID(),
                ])
            }
            """
        #expect(isEvalFallback(Lint.File.Single.Classifier.classify(source: source, baked: Self.baked)))
    }

    @Test
    func `Excluding with an empty list falls back to eval`() {
        let source = """
            // swift-linter-tools-version: 0.1
            import Linter
            import Fixture_Rules

            Lint.run(dependencies: [
                .package(path: "../swift-fixture-linter-rules", products: ["Fixture Rules"])
            ]) {
                Lint.Rule.Bundle.alpha.excluding(rules: [])
            }
            """
        #expect(isEvalFallback(Lint.File.Single.Classifier.classify(source: source, baked: Self.baked)))
    }

    @Test
    func `Inline custom rule plus enable falls back to eval`() {

        let source = """
            // swift-linter-tools-version: 0.1
            import Linter
            import Fixture_Rules
            import SwiftSyntax

            extension Lint.Rule {
                static let `sli public carrier import` = Lint.Rule(
                    id: "sli public carrier import",
                    default: .warning,
                    observe: Lint.Rule.measured { source, severity in [] }
                )
            }

            Lint.run(dependencies: [
                .package(path: "../swift-fixture-linter-rules", products: ["Fixture Rules"])
            ]) {
                Lint.Rule.Bundle.alpha.excluding(rules: [Lint.Rule.`int public parameter`.id])
                Lint.Rule.Configuration.enable(.`sli public carrier import`)
            }
            """
        #expect(isEvalFallback(Lint.File.Single.Classifier.classify(source: source, baked: Self.baked)))
    }

    @Test
    func `Bare beta bundle is the fast path with the beta token`() {

        let source = """
            // swift-linter-tools-version: 0.1
            import Linter
            import Fixture_Rules

            Lint.run(dependencies: [
                .package(url: "https://github.com/swift-beta/swift-beta-linter-rules.git", branch: "main", products: ["Fixture Rules"])
            ]) {
                Lint.Rule.Bundle.beta
            }
            """
        #expect(
            Lint.File.Single.Classifier.classify(source: source, baked: Self.baked)
                == .fastPathStandardBundle(bundle: "beta")
        )
    }

    @Test
    func `Bare gamma bundle is the fast path with the gamma token`() {
        let source = """
            // swift-linter-tools-version: 0.1
            import Linter
            import Fixture_Rules

            Lint.run(dependencies: [
                .package(path: "../swift-fixture-linter-rules", products: ["Fixture Rules"])
            ]) {
                Lint.Rule.Bundle.gamma
            }
            """
        #expect(
            Lint.File.Single.Classifier.classify(source: source, baked: Self.baked)
                == .fastPathStandardBundle(bundle: "gamma")
        )
    }

    @Test
    func `Beta bundle with exclusions carries the beta token`() {
        let source = """
            // swift-linter-tools-version: 0.1
            import Linter
            import Fixture_Rules

            Lint.run(dependencies: [
                .package(url: "https://github.com/swift-beta/swift-beta-linter-rules.git", branch: "main", products: ["Fixture Rules"])
            ]) {
                Lint.Rule.Bundle.beta.excluding(rules: [
                    "raw value access",
                ])
            }
            """
        let result = excluded(Lint.File.Single.Classifier.classify(source: source, baked: Self.baked))
        #expect(result?.bundle == "beta")
        #expect(result?.disabled == ["raw value access"])
    }

    @Test
    func `Gamma bundle with exclusions carries the gamma token`() {
        let source = """
            // swift-linter-tools-version: 0.1
            import Linter
            import Fixture_Rules

            Lint.run(dependencies: [
                .package(path: "../swift-fixture-linter-rules", products: ["Fixture Rules"])
            ]) {
                Lint.Rule.Bundle.gamma.excluding(rules: [
                    Lint.Rule.`raw value access`.id,
                ])
            }
            """
        let result = excluded(Lint.File.Single.Classifier.classify(source: source, baked: Self.baked))
        #expect(result?.bundle == "gamma")
        #expect(result?.disabled == ["raw value access"])
    }

    @Test
    func `Non-baked bundle falls back to eval`() {

        let source = """
            // swift-linter-tools-version: 0.1
            import Linter
            import Linter_Rules

            Lint.run(dependencies: [
                .package(path: ".", products: ["Linter Rules"])
            ]) {
                Lint.Rule.Bundle.universal
            }
            """
        #expect(isEvalFallback(Lint.File.Single.Classifier.classify(source: source, baked: Self.baked)))
    }

    @Test
    func `Non-baked bundle with exclusions falls back to eval`() {
        let source = """
            // swift-linter-tools-version: 0.1
            import Linter
            import Linter_Rules

            Lint.run(dependencies: [
                .package(path: ".", products: ["Linter Rules"])
            ]) {
                Lint.Rule.Bundle.universal.excluding(rules: ["raw value access"])
            }
            """
        #expect(isEvalFallback(Lint.File.Single.Classifier.classify(source: source, baked: Self.baked)))
    }

    @Test
    func `Parent inheritance directive falls back to eval`() {

        let source = """
            // swift-linter-tools-version: 0.1
            // parent: https://github.com/swift-molecules/swift-fixture-linter-rules.git
            import Linter
            import Fixture_Rules

            Lint.run(dependencies: [
                .package(path: "../swift-fixture-linter-rules", products: ["Fixture Rules"])
            ]) {
                Lint.Rule.Bundle.alpha
            }
            """
        #expect(isEvalFallback(Lint.File.Single.Classifier.classify(source: source, baked: Self.baked)))
    }

    @Test
    func `A non-directive parent substring stays on the fast path`() {

        let source = """
            // swift-linter-tools-version: 0.1
            import Linter
            import Fixture_Rules

            Lint.run(dependencies: [
                .package(path: "../swift-fixture-linter-rules", products: ["Fixture Rules"])
            ]) {
                Lint.Rule.Bundle.alpha  // not a // parent: directive, just prose
            }
            """
        #expect(
            Lint.File.Single.Classifier.classify(source: source, baked: Self.baked)
                == .fastPathStandardBundle(bundle: "alpha")
        )
    }

    @Test
    func `Source without a run call falls back to eval`() {
        let source = """
            // swift-linter-tools-version: 0.1
            import Linter
            let manifest: Lint.Manifest = Lint.Manifest()
            """
        #expect(isEvalFallback(Lint.File.Single.Classifier.classify(source: source, baked: Self.baked)))
    }

    @Test
    func `Two-statement bare closure falls back to eval`() {

        let source = """
            // swift-linter-tools-version: 0.1
            import Linter
            import Fixture_Rules

            Lint.run(dependencies: [
                .package(path: "../swift-fixture-linter-rules", products: ["Fixture Rules"])
            ]) {
                Lint.Rule.Bundle.alpha
                Lint.Rule.Configuration.disable(.`raw value access`)
            }
            """
        #expect(isEvalFallback(Lint.File.Single.Classifier.classify(source: source, baked: Self.baked)))
    }
}

extension Lint.File.Single.Classifier.Test {

    @Test
    func `A bundle the runner does not bake falls back to eval`() {
        let source = """
            // swift-linter-tools-version: 0.1
            import Linter
            import Fixture_Rules

            Lint.run(dependencies: [
                .package(path: "../swift-fixture-linter-rules", products: ["Fixture Rules"])
            ]) {
                Lint.Rule.Bundle.delta
            }
            """
        #expect(isEvalFallback(Lint.File.Single.Classifier.classify(source: source, baked: Self.baked)))
    }

    @Test
    func `A runner that bakes nothing routes nothing`() {
        let source = """
            // swift-linter-tools-version: 0.1
            import Linter
            import Fixture_Rules

            Lint.run(dependencies: [
                .package(path: "../swift-fixture-linter-rules", products: ["Fixture Rules"])
            ]) {
                Lint.Rule.Bundle.alpha
            }
            """
        #expect(isEvalFallback(Lint.File.Single.Classifier.classify(source: source, baked: [])))
    }
}
