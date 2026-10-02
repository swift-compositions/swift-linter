extension Lint.Driver {

  public enum Error: Swift.Error, Equatable, Sendable {
    case resolutionFailed(description: Swift.String)
  }
}
