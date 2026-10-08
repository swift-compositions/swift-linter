internal import Environment
internal import Process

extension Lint.Driver.Dispatch {

  public enum Prebuilt: Swift.Sendable {}
}

extension Lint.Driver.Dispatch.Prebuilt {

  public static let variable: Swift.String = "SWIFT_LINTER_TEST_DISPATCH_EXECUTABLE"

  public enum Error: Swift.Error, Swift.Sendable {

    case spawnFailed(executable: Swift.String, description: Swift.String)
  }

  internal static func executable() -> Swift.String? {
    Environment.read(Self.variable)
  }

  internal static func run(
    executable: Swift.String,
    arguments: [Swift.String],
    environment: [Swift.String: Swift.String]
  ) throws(Self.Error) -> Swift.Int32 {
    let configuration = Process.Spawn.Configuration(
      executable: executable,
      arguments: arguments,
      environment: environment
    )
    let status: Process.Status
    do throws(Process.Error) {
      status = try Process.Spawn.run(configuration).status
    } catch {
      throw .spawnFailed(executable: executable, description: "\(error)")
    }
    return switch status {
    case .exited(let code): code
    case .signaled(let signal): -signal
    case .stopped(let signal): -signal
    }
  }
}
