import Linter
import Linter_Institute_Rules
import Linter_Primitives_Rules
import Linter_Standards_Rules

extension Lint {
  @main
  enum Runner {
    static func main() {
      Lint.run(bundles: [
        .institute: Lint.Rule.Bundle.institute,
        .primitives: Lint.Rule.Bundle.primitives,
        .standards: Lint.Rule.Bundle.standards,
      ])
    }
  }
}
