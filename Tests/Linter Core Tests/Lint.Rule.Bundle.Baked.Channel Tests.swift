import Environment
import Kernel
import Testing

@testable import Linter_Core

extension Lint.Rule.Bundle.Baked.Channel {
    @Suite(.serialized)
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Rule.Bundle.Baked.Channel.Test {
    private func withVariable(_ value: Swift.String?, body: () -> Swift.Void) {
        do throws(Kernel.Environment.Error) {
            if let value {
                try Environment.write(Lint.Rule.Bundle.Baked.Channel.variable, to: value)
            } else {
                try Environment.write.unset(Lint.Rule.Bundle.Baked.Channel.variable)
            }
        } catch {
            Issue.record("environment setup failed: \(error)")
            return
        }
        defer {
            do throws(Kernel.Environment.Error) {
                try Environment.write.unset(Lint.Rule.Bundle.Baked.Channel.variable)
            } catch {
                Issue.record("environment cleanup failed: \(error)")
            }
        }
        body()
    }

    @Test
    func `unset reads nil`() {
        withVariable(nil) {
            do throws(Lint.Rule.Bundle.Baked.Channel.Error) {
                let bundle = try Lint.Rule.Bundle.Baked.Channel.read()
                #expect(bundle == nil)
            } catch {
                Issue.record("unexpected channel read failure: \(error)")
            }
        }
    }

    @Test
    func `vocabulary round trips`() {
        for bundle in Lint.Rule.Bundle.Baked.allCases {
            withVariable(bundle.rawValue) {
                do throws(Lint.Rule.Bundle.Baked.Channel.Error) {
                    let decoded = try Lint.Rule.Bundle.Baked.Channel.read()
                    #expect(decoded == bundle)
                } catch {
                    Issue.record("unexpected channel read failure: \(error)")
                }
            }
        }
    }

    @Test
    func `invalid value throws`() {
        withVariable("universal") {
            #expect(throws: Lint.Rule.Bundle.Baked.Channel.Error.invalid(value: "universal")) {
                try Lint.Rule.Bundle.Baked.Channel.read()
            }
        }
    }

    @Test
    func `expressions match accessors`() {
        #expect(Lint.Rule.Bundle.Baked.primitives.expression == "Lint.Rule.Bundle.primitives")
        #expect(Lint.Rule.Bundle.Baked.standards.expression == "Lint.Rule.Bundle.standards")
        #expect(Lint.Rule.Bundle.Baked.institute.expression == "Lint.Rule.Bundle.institute")
    }
}
