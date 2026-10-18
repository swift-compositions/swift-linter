import Environment
import Kernel
import Testing

@testable import Linter_Core

extension Lint.Run.Policy.Channel {
    @Suite(.serialized)
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Run.Policy.Channel.Test {
    private func withVariable(_ value: Swift.String?, body: () -> Swift.Void) {
        do throws(Kernel.Environment.Error) {
            if let value {
                try Environment.write(Lint.Run.Policy.Channel.variable, to: value)
            } else {
                try Environment.write.unset(Lint.Run.Policy.Channel.variable)
            }
        } catch {
            Issue.record("environment setup failed: \(error)")
            return
        }
        defer {
            do throws(Kernel.Environment.Error) {
                try Environment.write.unset(Lint.Run.Policy.Channel.variable)
            } catch {
                Issue.record("environment cleanup failed: \(error)")
            }
        }
        body()
    }

    @Test
    func `unset reads nil`() {
        withVariable(nil) {
            do throws(Lint.Run.Policy.Channel.Error) {
                let policy = try Lint.Run.Policy.Channel.read()
                #expect(policy == nil)
            } catch {
                Issue.record("unexpected channel read failure: \(error)")
            }
        }
    }

    @Test
    func `vocabulary round trips`() {
        for policy in Lint.Run.Policy.allCases {
            withVariable(policy.rawValue) {
                do throws(Lint.Run.Policy.Channel.Error) {
                    let decoded = try Lint.Run.Policy.Channel.read()
                    #expect(decoded == policy)
                } catch {
                    Issue.record("unexpected channel read failure: \(error)")
                }
            }
        }
    }

    @Test
    func `invalid value throws`() {
        withVariable("warnings-as-errors") {
            #expect(throws: Lint.Run.Policy.Channel.Error.invalid(value: "warnings-as-errors")) {
                try Lint.Run.Policy.Channel.read()
            }
        }
    }
}
