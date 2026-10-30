import Linter

extension Lint.Rule {
    fileprivate static let `bundle fixture alpha` = Lint.Rule(
        id: "bundle fixture alpha",
        default: .error,
        controls: [
            .init(
                id: "bundle fixture alpha positive",
                source: "let value = 0",
                path: "Controls/Fixture.swift",
                expectation: .findings(1)
            )
        ],
        observe: Lint.Rule.measured { source, severity in
            [
                Diagnostic.Record(
                    location: Source.Location(
                        fileID: source.file.fileID,
                        filePath: source.file.filePath,
                        line: 1,
                        column: 1
                    ),
                    severity: severity,
                    identifier: "bundle fixture alpha",
                    message: "alpha bundle fired"
                )
            ]
        }
    )

    fileprivate static let `bundle fixture beta` = Lint.Rule(
        id: "bundle fixture beta",
        default: .error,
        controls: [
            .init(
                id: "bundle fixture beta positive",
                source: "let value = 0",
                path: "Controls/Fixture.swift",
                expectation: .findings(1)
            )
        ],
        observe: Lint.Rule.measured { source, severity in
            [
                Diagnostic.Record(
                    location: Source.Location(
                        fileID: source.file.fileID,
                        filePath: source.file.filePath,
                        line: 1,
                        column: 1
                    ),
                    severity: severity,
                    identifier: "bundle fixture beta",
                    message: "beta bundle fired"
                )
            ]
        }
    )

    fileprivate static let `bundle fixture gamma` = Lint.Rule(
        id: "bundle fixture gamma",
        default: .error,
        controls: [
            .init(
                id: "bundle fixture gamma positive",
                source: "let value = 0",
                path: "Controls/Fixture.swift",
                expectation: .findings(1)
            )
        ],
        observe: Lint.Rule.measured { source, severity in
            [
                Diagnostic.Record(
                    location: Source.Location(
                        fileID: source.file.fileID,
                        filePath: source.file.filePath,
                        line: 1,
                        column: 1
                    ),
                    severity: severity,
                    identifier: "bundle fixture gamma",
                    message: "gamma bundle fired"
                )
            ]
        }
    )
}

Lint.run(bundles: [
    "alpha": [.enable(.`bundle fixture alpha`)],
    "beta": [.enable(.`bundle fixture beta`)],
    "gamma": [.enable(.`bundle fixture gamma`)],
])
