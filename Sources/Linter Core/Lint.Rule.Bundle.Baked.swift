public import Lint

extension Lint.Rule.Bundle {

    public struct Baked: Swift.Hashable, Swift.Sendable {

        public let token: Swift.String

        public init(_ token: Swift.String) {
            self.token = token
        }
    }
}

extension Lint.Rule.Bundle.Baked: Swift.ExpressibleByStringLiteral {

    public init(stringLiteral token: Swift.String) {
        self.init(token)
    }
}

extension Lint.Rule.Bundle.Baked {

    public var expression: Swift.String {
        "Lint.Rule.Bundle.\(token)"
    }
}
