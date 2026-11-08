public import Linter_Core

extension Lint.Run.Command {
    public enum Error: Swift.Error, Swift.Equatable, Swift.Sendable {
        case unknownOption(Swift.String)
        case usage(Swift.String)
    }
}
