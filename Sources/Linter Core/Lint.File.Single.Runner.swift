internal import Environment
internal import File_System
internal import Process
internal import JSON

extension Lint.File.Single {

    public enum Runner: Swift.Sendable {}
}

extension Lint.File.Single.Runner {

    internal static func run(
        binary: Swift.String,
        consumerPackageRoot: File.Path,
        arguments: [Swift.String],
        selection: Lint.Manifest?,
        bundle: Lint.Rule.Bundle.Baked,
        nonce: Swift.String
    ) throws(Lint.File.Single.Error) -> Swift.Int32 {
        let selectionPath: File.Path?
        if let selection {
            let manifestPath: File.Path
            do throws(Lint.File.Single.Channel.Error) {
                manifestPath = try Lint.File.Single.Channel.selection.write(
                    selection,
                    consumerPackageRoot: consumerPackageRoot,
                    nonce: nonce
                )
            } catch {
                throw .materializationFailed(reason: "write selection manifest: \(error)")
            }
            selectionPath = manifestPath
        } else {
            selectionPath = nil
        }
        defer { Lint.File.Single.Channel.discard(selectionPath, nonce: nonce) }
        let environment: [Swift.String: Swift.String] = Self.environment(
            inheriting: Environment.Snapshot.current(),
            bundle: bundle,
            selection: selectionPath
        )
        let invocation: [Swift.String] = Self.invocation(binary: binary, arguments: arguments)
        let spawnConfiguration = Process.Spawn.Configuration(
            executable: "/usr/bin/env",
            arguments: invocation,
            environment: environment
        )
        let status: Process.Status
        do throws(Process.Error) {
            status = try Process.Spawn.run(spawnConfiguration).status
        } catch {
            throw .spawnFailed(
                consumerPackageRoot: consumerPackageRoot,
                description: "standard-runner spawn failed: \(error)"
            )
        }
        switch status {
        case .exited(let code): return code
        case .signaled(let signal): return -signal
        case .stopped(let signal): return -signal
        }
    }

    internal static func environment(
        inheriting snapshot: Environment.Snapshot,
        bundle: Lint.Rule.Bundle.Baked,
        selection: File.Path?
    ) -> [Swift.String: Swift.String] {
        var environment = snapshot

        environment.values[Lint.Rule.Bundle.Baked.Channel.variable] = bundle.token
        if let selection {
            environment.values[Lint.File.Single.Channel.selection.variable] = selection.string
        }
        return environment.values
    }

    internal static func invocation(
        binary: Swift.String,
        arguments: [Swift.String]
    ) -> [Swift.String] {
        [binary] + arguments
    }
}

extension Lint.File.Single.Runner {

    internal static func inventory(
        binary: Swift.String
    ) throws(Lint.File.Single.Error) -> Swift.Set<Lint.Rule.Bundle.Baked> {
        let output: Process.Output
        do throws(Process.Error) {
            output = try Process.Spawn.run(
                .init(
                    executable: "/usr/bin/env",
                    arguments: Self.invocation(binary: binary, arguments: ["--inventory"]),
                    stdout: .pipe,
                    stderr: .inherit
                )
            )
        } catch {
            throw .inventoryFailed(binary: binary, description: "spawn failed: \(error)")
        }
        guard output.status == .exited(code: 0) else {
            throw .inventoryFailed(binary: binary, description: "exited with \(output.status)")
        }
        let text = Swift.String(decoding: output.stdout ?? [], as: Swift.UTF8.self)
        do throws(JSON.Error) {
            guard let bundles = try JSON.parse(text).dictionary?["bundles"] else {
                throw JSON.Error.typeMismatch(expected: "inventory object", got: "no bundles")
            }
            var baked: Swift.Set<Lint.Rule.Bundle.Baked> = []
            for entry in try [JSON](json: bundles) {
                guard let token = entry.dictionary?["bundle"] else {
                    throw JSON.Error.typeMismatch(expected: "bundle entry", got: "no bundle")
                }
                baked.insert(Lint.Rule.Bundle.Baked(try Swift.String(json: token)))
            }
            return baked
        } catch {
            throw .inventoryFailed(binary: binary, description: "malformed inventory: \(error)")
        }
    }
}
