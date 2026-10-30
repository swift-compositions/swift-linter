internal import JSON
internal import Process

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
