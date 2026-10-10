# Local Swift linter

Build and check with editable local engine and rule sources. No releases or fleet tools are involved.

## Setup once

Supported and tested: **macOS 27 on Apple Silicon, full Xcode 27.1 / Swift 6.4**, Git, and Python 3.9 or newer (`python3`). Select that Xcode with `DEVELOPER_DIR` if it is not your default. Initial setup needs network access to the repositories in `Runner/accepted-graph.json`, several GB of disk space, and time for dependency resolution and compilation. No Python packages are required.

From a fresh checkout of this repository:

```sh
cd swift-linter
./scripts/lint-local setup
./scripts/lint-local check "/path/to/Your Swift Package"
```

`setup` clones five rule/core repositories at the revisions in the committed accepted graph, binds those plus this engine checkout locally, resolves dependencies, and builds the existing runner. It creates `.local-linter/config.json`, an Xcode workspace, a private dependency cache, and incremental build state inside this checkout. It never pulls, resets, or cleans existing sources. Rerun setup after an interrupted resolve/build; normal checks also resume the build.

## Everyday use

```sh
# Run from the swift-linter checkout. Edit your package, then repeat this command.
./scripts/lint-local check "/path/to/Your Swift Package"

# Choose rules explicitly, or inspect all available IDs.
./scripts/lint-local check "/path/to/package" --rules "existential parameter"
./scripts/lint-local rules

# Full bundle report: includes findings outside the default selection.
./scripts/lint-local report "/path/to/package"
./scripts/lint-local --help
```

The default selection is `do throws for typed catch,bare string dependency,existential parameter` from the `institute` bundle. `--bundle primitives` and `--bundle standards` are also supported with rule IDs from `rules`. An absolute path to `scripts/lint-local` works from any working directory; relative package paths are relative to that working directory.

Edit rules under `.local-linter/checkouts/swift-institute-linter-rules/Sources/`, then run the same check. Each invocation rebuilds incrementally, including uncommitted and untracked local Swift sources. No intermediate publication or build-directory deletion is needed. Rule controls run with each measurement; breaking a control makes the result incomplete.

| Exit | Meaning |
|---|---|
| 0 | `check`: selected rules measured and clean. `report`: complete full-bundle report, **possibly with findings**. |
| 1 | Selected rules have violations; diagnostics include file, line, column, rule, and explanation. |
| 2 | Unmeasured/incomplete, including malformed measurement, failed controls, or sources changing during a check. Fix the reported cause and rerun. |
| 3 | Setup/build/configuration failure or unknown rule. Read the displayed error and build log; rerun setup or correct configuration. |
| 64 | Usage error, including a directory without `Package.swift`. Read `--help`. |

Incomplete measurement takes precedence over violations. Clean applies only to the selected rules, not compilation, all rules, or absence of suppressions. Existing source suppressions are honored and their count is printed; the raw report retains them. Run your package's build and tests separately.

Each run prints the exact engine/rule paths, Git revisions, changed/untracked counts, content fingerprints, package path and Swift-source fingerprint, bundle and selected rules. Unique `.local-linter/runs/<id>/` directories retain the build log, raw structured report, runner stderr, resolved dependency graph, and receipt with toolchain, binary identity, and package Git identity when it is a checkout root. Reports are never reused as new measurements. Concurrent commands in one tool checkout fail with an actionable message; independent checkouts can run separately. Ambient `SWIFT_LINTER_*` variables are cleared so they cannot silently change selection or policy.

## Checkout locations

Optional, on first setup: `./scripts/lint-local setup --checkouts "/path/with spaces/local rules"`.

For existing clones or worktrees, create an explicit JSON config, then run `./scripts/lint-local --config /path/to/config.json setup` and use the same `--config` for checks:

```json
{
  "schema": 1,
  "sources": {
    "swift-linter": "/path/to/this/swift-linter",
    "swift-institute-linter-rules": "/path/to/swift-institute-linter-rules",
    "swift-primitives-linter-rules": "/path/to/swift-primitives-linter-rules",
    "swift-standards-linter-rules": "/path/to/swift-standards-linter-rules",
    "swift-linter-rules": "/path/to/swift-linter-rules",
    "swift-lint": "/path/to/swift-lint"
  }
}
```

Relative config paths resolve from the config file's directory. Missing rule checkouts are cloned during setup; existing checkouts are used as-is. Run the script belonging to the configured engine. Changing checkout locations selects separate build state and preserves earlier state. The accepted graph pins initial dependencies; local source edits can require new dependency resolution, which remains visible in the build log.

## Xcode and verification

Open `.local-linter/Linter.xcworkspace` in Xcode, so all six local packages participate. The workspace contains editable sources; the CLI's generated Runner owns its separate SwiftPM build state. Use an explicit scheme for command-line resolution, build, and tests (commands below are verified in `LOCAL-LINTER-VERIFICATION.md`).

```sh
# Initialize package scheme discovery on the first opening of this workspace.
xcodebuild -workspace .local-linter/Linter.xcworkspace -list
xcodebuild -workspace .local-linter/Linter.xcworkspace -scheme swift-linter -resolvePackageDependencies
xcodebuild -workspace .local-linter/Linter.xcworkspace -scheme swift-linter -destination 'platform=macOS' -derivedDataPath .local-linter/DerivedData build
xcodebuild -workspace .local-linter/Linter.xcworkspace -scheme 'Linter Core Tests' -destination 'platform=macOS' -derivedDataPath .local-linter/DerivedData test
python3 -m unittest discover -s scripts/tests -p 'test_*.py' -v
# Real package/rule edit loop; use an otherwise idle disposable development clone.
python3 scripts/tests/integration.py
```

Integration tests preserve fixtures and output under `.local-linter/integration-*`. They temporarily inject a compiler error and then append a marker to one diagnostic message, restore the original bytes even on failure, and verify the rebuilt runner after restoration. They never weaken a rule or erase build state.
