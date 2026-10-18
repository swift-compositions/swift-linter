public import Lint
public import Text

extension Lint.Suppression {

    public struct Entry: Sendable, Equatable {

        public let line: Text.Line.Number

        public let rule: Lint.Rule.ID

        public let reason: Swift.String?

        public let directive: Lint.Rule.Suppression.Directive

        @inlinable
        public init(
            line: Text.Line.Number,
            rule: Lint.Rule.ID,
            reason: Swift.String? = nil,
            directive: Lint.Rule.Suppression.Directive = .next
        ) {
            self.line = line
            self.rule = rule
            self.reason = reason
            self.directive = directive
        }
    }
}
