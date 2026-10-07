public import Linter_Core

extension Lint.Run {
  public enum Command: Swift.Equatable, Swift.Sendable {
    case inventory
    case profile(path: Swift.String, paths: [Swift.String])
    case lint(paths: [Swift.String])
  }
}

extension Lint.Run.Command {
  public enum Error: Swift.Error, Swift.Equatable, Swift.Sendable {
    case unknownOption(Swift.String)
    case usage(Swift.String)
  }

  public static let usage: Swift.String =
    "usage: --inventory | --profile <profile.json> <path> ... | [<path> ...]; "
    + "only the leading token selects the mode, and every later token is a path, "
    + "even one that looks like an option"

  public static func parse(_ arguments: [Swift.String]) throws(Error) -> Self {
    guard let first = arguments.first, first.hasPrefix("--") else {
      return .lint(paths: arguments)
    }
    switch first {
    case "--inventory":
      guard arguments.count == 1 else {
        throw .usage("--inventory takes no further arguments")
      }
      return .inventory
    case "--profile":
      guard arguments.count >= 3 else {
        throw .usage("profile invocation requires --profile <profile.json> <path> ...")
      }
      return .profile(path: arguments[1], paths: [Swift.String](arguments.dropFirst(2)))
    default:
      throw .unknownOption(first)
    }
  }
}
