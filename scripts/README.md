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

Diagnostic paths beginning with `./` are relative to the checked package, whose absolute path is printed in the banner.

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

Open `.local-linter/Linter.xcworkspace` in Xcode, so all six local packages participate. The workspace contains editable sources; the CLI's generated Runner owns its separate SwiftPM build state. Use an explicit scheme for command-line resolution and build. Outcomes, including test limitations, are recorded in `LOCAL-LINTER-VERIFICATION.md`.

```sh
# Initialize package scheme discovery on the first opening of this workspace.
xcodebuild -workspace .local-linter/Linter.xcworkspace -list
xcodebuild -workspace .local-linter/Linter.xcworkspace -scheme swift-linter -resolvePackageDependencies
xcodebuild -workspace .local-linter/Linter.xcworkspace -scheme swift-linter -destination 'platform=macOS' -derivedDataPath .local-linter/DerivedData build
# Rule regressions through SwiftPM with verified local bindings (1,938 passed).
./scripts/lint-local test --package swift-institute-linter-rules
# Full engine suite; known nested-fixture build failures on repeat runs (see below).
./scripts/lint-local test
python3 -m unittest discover -s scripts/tests -p 'test_*.py' -v
# Real package/rule edit loop; use an otherwise idle disposable development clone.
python3 scripts/tests/integration.py
```

Integration tests preserve fixtures and output under `.local-linter/integration-*`. They temporarily inject a compiler error and then append a marker to one diagnostic message, restore the original bytes even on failure, and verify the rebuilt runner after restoration. They never weaken a rule or erase build state.

`test` uses a separate private SwiftPM scratch tree, binds the configured local dependencies, builds the process-test executables, and runs the package's complete test suite. It preserves the resolved graph, source identity, and full output in the run evidence. Exit 0 means tests passed; exit 3 means resolution, build, or tests failed.

Some engine process tests build nested fixture packages against this local engine and resolve their transitive dependencies. These tests need network access and additional disk space/time, including possible fetches on later runs. Both SwiftBuild and native builds passed all 149 tests cold, but repeat runs failed because the SDK and ecosystem both expose a module named `System`; Crypto then resolves the wrong module. The command reports exit 3. The full engine suite is not yet reliably green in this environment. The current local runner uses the native backend explicitly (deprecated by SwiftPM); it is a recorded build profile, not a complete fix for the module collision.

The Xcode workspace's package resolution and executable build are verified. The SwiftPM rule suite above is the passing regression route. Xcode-native test/fixture builds also encounter upstream deployment-target and module/linker conflicts in this dependency graph. These failures are recorded in `LOCAL-LINTER-VERIFICATION.md`; no tests are skipped to conceal them.

## Ecosystem source inventory

```sh
./scripts/ecosystem-inventory /path/to/swift-institute > ecosystem-inventory.json
```

This read-only command records package checkout paths, Git revisions, working-tree status, manifest hashes, literal dependency URLs, and matching local dependency edges. It does not descend into a repository's build caches. The result is a starting point for dependency-ordered verification, **not** a resolved SwiftPM graph or a compliance verdict: computed/conditional manifest declarations still require resolution. Preserve dirty checkouts and perform migrations in isolated clones.

## Full-policy compliance

A selected-rule check cannot establish full compliance. To enforce a reviewed,
versioned policy, use:

```sh
./scripts/lint-local --config /path/to/local-config.json check /path/to/package \
  --policy /path/to/package/compliance-policy.json
```

`--policy` and `--rules` are mutually exclusive. Policy mode measures the whole
chosen bundle, requires its exact rule inventory, and rejects changed or dirty
tool checkouts, a different toolchain, and a different resolved tool graph.
Package sources may be edited normally. The evidence directory retains the
policy, raw findings, suppressions, resolved graph, and source identities.

The policy is JSON with these fields:

- `schema`: `1`.
- `bundle`: `institute`, `primitives`, or `standards`.
- `requiredRules`: every rule ID in that bundle, with no duplicates.
- `sources`: all six configured checkout names mapped to full Git commit IDs.
- `toolchain`: exact `swift` and `xcode` strings from a run receipt, and
  `buildSystem: "native"`, plus `swiftTarget` (for example
  `arm64-apple-macosx27.0`).
- `dependencyPins`: the resolved tool graph's `pins`, retaining `identity`,
  `location`, and `state` for each dependency.
- `reviewedSuppressions`: normally `[]`. Each existing, justified suppression
  requires `rule`, relative `file`, diagnostic `line`, the entire source file's
  `fileSHA256`, and a nonempty human-readable `reason`. Any change to its context,
  additional suppression, or obsolete review fails the gate.

Review the policy in version control alongside the package. Do not generate an
accepted policy from arbitrary findings or update pins automatically in CI.
Tool/rule development uses ordinary checks; once changes are reviewed, committed,
and tested, update the compliance policy deliberately.

In policy mode, exit **0** means the full policy is satisfied, with any reviewed
suppressions explicitly disclosed. Exit **1** means findings or suppression
review failures; **2** means incomplete measurement or a rule-inventory mismatch;
**3** means setup, build, toolchain, source-pin, or dependency-pin failure; **64**
means invalid arguments or policy. Only exit 0 passes the gate. `report` remains
an evidence command whose exit 0 does not establish cleanliness.

Exercise the full-policy contract against the reference package in an isolated
clone (all generated files and commands are retained in the output directory):

```sh
python3 scripts/tests/policy_integration.py --linter . \
  --config /path/to/local-config.json --policy /path/to/swift-effects/compliance-policy.json \
  --package /path/to/swift-effects --output .local-linter
```

This reference-specific test checks the package edit/fix cycle, malformed Swift
source, paths containing spaces, suppression context changes, incomplete rule
inventories, wrong tool revisions, invalid policies, and setup failure. It uses
the package's existing reviewed suppression as a mutation fixture; it does not
add a suppression or weaken any rule.


### Fresh setup from a pinned policy

Clone the engine at the policy's `sources.swift-linter` revision. From that new
engine checkout, run:

```sh
./scripts/lint-local setup --policy /path/to/swift-effects/compliance-policy.json
./scripts/lint-local check /path/to/swift-effects --policy /path/to/swift-effects/compliance-policy.json
```

Setup clones the policy's exact five rule/core revisions, binds them locally,
builds, and validates the full inventory and dependency pins. Existing checkouts
are checked, never reset to match a policy. A policy mismatch is an actionable
setup failure.

For unpublished local candidates, clone the engine from its maintained checkout
with `git clone --no-local /path/to/engine /new/directory/swift-linter`. Supply
`setup --source-repositories /path/to/sources.json` to clone the other five from
explicit repositories. That JSON maps `swift-institute-linter-rules`,
`swift-primitives-linter-rules`, `swift-standards-linter-rules`, `swift-linter-rules`,
and `swift-lint` to Git URLs or local repository paths. Relative paths are relative
to the JSON file. Git object data is copied; build caches and uncommitted changes
are not copied. The sources must contain the policy's commits.

The macOS-only compiler profile explicitly targets macOS 27 for every Swift
compilation, including regression subprocesses, using
`-Xswiftc -target -Xswiftc <architecture>-apple-macosx27.0`. This keeps dependencies
with older declared deployment floors from failing when this graph's `System`
module is already present. The profile, source revisions, actual commands, and
subprocess trace are retained as evidence. It does not rename the ecosystem or
SDK modules. Validate the complete cold/repeat engine suite when changing this
profile or toolchain; passing an individual nested fixture is insufficient.

## Ecosystem debt audit

After verifying a reference package with a pinned full policy, measure the other
checkouts with the same engine, rules, toolchain and resolved tool dependencies:

```sh
./scripts/ecosystem-audit /path/to/swift-institute \
  --policy /path/to/swift-effects/compliance-policy.json \
  --output /path/to/new-audit
```

Use `--config` for an explicit local tool configuration. The output directory
must be new and should be outside the source workspace. The audit snapshots
working-tree files, including dirty edits and ignored Swift sources, before
measurement. It preserves the originals and keeps per-package raw reports,
diagnostics, source hashes, a tool receipt, and a summary checkpoint. It does
not change packages or publish anything. Each run measures again; checkpoints
are evidence, not a cache of verdicts.

`scripts/ecosystem-bundles.json` explicitly assigns `primitives` to atoms and
molecules, `standards` to standards packages, and `institute` to compositions,
shims and the other listed groups. Override with `--mapping` when reviewing a
different layout. Missing mappings are unmeasured. Declared dependency edges
order dependencies before consumers and group cycles; they are **not** a
resolved SwiftPM graph. Relative local package layouts are retained in snapshots,
but manifests that require Git metadata or files outside the inventoried packages
may fail to measure. Such failures remain visible, never clean.

The summary separates **lint-clean**, **measured-debt**, and **unmeasured**.
Every finding and suppression counts as debt here, including the reference
package's individually reviewed suppression. This audit does not establish build,
test, API, or runtime correctness. Those require package-specific verification.

After reviewing and retaining a complete audit, compare a new run explicitly:

```sh
./scripts/ecosystem-audit /path/to/swift-institute \
  --policy /path/to/swift-effects/compliance-policy.json \
  --baseline /path/to/reviewed-audit/summary.json \
  --output /path/to/new-comparison
```

A comparison fails for new/increased finding or suppression signatures, added or
removed packages, and any incomplete measurement. Signatures include rule,
file, diagnostic message and the source line plus its neighbors; duplicate
counts are retained. Moving unchanged context preserves its signature, while
editing context requires review. This is a textual debt comparison, not proof
of semantic equivalence. Changes to policy, mapping or auditor require a newly
reviewed baseline. **Baseline preserved does not mean compliant.** Exit codes
are 0 for the stated verdict, 1 for debt/regression, 2 for unmeasured, 3 for tool
setup failure and 64 for usage. An interrupted run retains an incomplete summary
and exits 2. `--timeout` bounds each package (300 seconds by default).
