internal import Environment
internal import Process


extension Lint.Driver.Dispatch.Prebuilt {
    public enum Error: Swift.Error, Swift.Sendable {

        case spawnFailed(executable: Swift.String, description: Swift.String)
    }
}
