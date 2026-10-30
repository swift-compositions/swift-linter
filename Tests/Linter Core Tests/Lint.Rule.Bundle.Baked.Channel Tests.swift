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
    func `any name round trips`() {
        for bundle: Lint.Rule.Bundle.Baked in ["alpha", "beta", "universal"] {
            withVariable(bundle.token) {
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
    func `empty value throws`() {
        withVariable("") {
            #expect(throws: Lint.Rule.Bundle.Baked.Channel.Error.invalid(value: "")) {
                try Lint.Rule.Bundle.Baked.Channel.read()
            }
        }
    }

    @Test
    func `expression names the bundle accessor`() {
        #expect(Lint.Rule.Bundle.Baked("alpha").expression == "Lint.Rule.Bundle.alpha")
    }
}
