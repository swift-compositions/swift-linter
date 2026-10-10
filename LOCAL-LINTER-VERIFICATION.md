# Local linter verification — 2026-10-10

Implementation is in `swift-linter`, branch `local-linter-workflow`, commits `6325dd0`, `5feb22d`, and `7a2ea1e`. This record covers local developer delivery, not production-release adoption. No production consumer or old fleet control was changed.

## Environment and isolated checkouts

- macOS 27.2 (26B5091g), Apple Silicon; Xcode 27.1 (27A9269); Apple Swift 6.4; Python 3.9.6.
- Development checkout: `/Users/coen/Developer/coenttb/local-linter-development/swift-linter`.
- Independent setup reproduction: `/Users/coen/Developer/coenttb/local-linter-development/fresh setup with spaces/swift-linter`.
- Both checkouts have their own local configuration, dependency cache, source clones, runner build state, and per-run evidence. Initial setup did not use the sprint's caches, binaries, or temporary files.
- Before implementation, `git ls-remote <repository URL> HEAD` confirmed that the engine and all five configured dependencies still matched the revisions below. The two corrected sample package heads were checked separately.

| Source | Starting revision |
|---|---|
| swift-linter | c2b3c858f863548eef7399d8ead597f4351cf7cb |
| swift-institute-linter-rules | 4af2a1698b215cc14a662bdbba9496799db7fd85 |
| swift-primitives-linter-rules | ac9bd4a0291eb89f66671398d0ac07ff6bcf4c90 |
| swift-standards-linter-rules | 73ec2127ee1e8ffc4f3208df9bd8a5d3018f358d |
| swift-linter-rules | b407975e1e018b769c3cf22a901f8f1b709b2984 |
| swift-lint | f61f759487c453dd7996de004be8cba21a1e4342 |

## Fresh setup and end-to-end behavior

Executed from a new directory, using the committed implementation as the clone source:

```sh
git clone /Users/coen/Developer/coenttb/local-linter-development/swift-linter "/Users/coen/Developer/coenttb/local-linter-development/fresh setup with spaces/swift-linter"
cd "/Users/coen/Developer/coenttb/local-linter-development/fresh setup with spaces/swift-linter"
./scripts/lint-local setup
python3 -m unittest discover -s scripts/tests -p 'test_*.py' -v
python3 scripts/tests/integration.py
```

Setup exited **0**, fetching the accepted dependency graph into a new private cache and compiling the runner with all six local bindings. The full integration suite passed **17 cases**. Evidence is retained at `.local-linter/integration-20261010-110636-5314da/`, with an exact argument vector and actual/expected status per case in `results.json`; runner receipts and raw reports are under `.local-linter/runs/`.

| Case | Result |
|---|---|
| Clean package, including spaces in checkout and package paths | 0 |
| Package edit introducing a real existential parameter | 1, with source location |
| Package fix back to a generic parameter | 0 |
| Real bare-string target dependency | 1 |
| Malformed manifest | 2, manifest parse reason |
| Multiple Package initializers | 2, unsupported shape reason |
| Codable witnesses | 0 for existential parameter |
| Non-witness Encoder parameter | 1 for existential parameter |
| Unknown rule | 3, with inventory command |
| Empty rule list; directory without Package.swift | 64 |
| Missing configured checkout | 3 |
| Deliberate compiler error in a local rule | 3 |
| Restored rule plus diagnostic-message edit | 1, with new local marker |
| Restored original diagnostic | 1, marker absent |
| Final package fix | 0 |
| Full report of the minimal fixture | 2: four findings and one unmeasured rule outside the selected set |

The rule probe restores the original bytes in `finally`. No predicates, valid counterexamples, controls, or suppressions were weakened. Recovery used ordinary rebuilds without deleting build state or resetting repositories.

The subsequent setup-race guard, test-command, and nested-checkout identity changes are covered by **18 wrapper unit tests**. They cover missing/contradictory reports, incomplete scans, failed/unmeasured controls, unexplained runner exits, source fingerprints, inherited environment settings, argument errors, and source edits during dependency resolution, and untracked nested Git checkouts. Generated test build caches are ignored without excluding real package source files from measurement. Setup/check and the 17-test wrapper suite at `5feb22d` returned 0 in the checkout with spaces. The final additional nested-checkout regression at `7a2ea1e` raised the wrapper suite to 18 passing tests.

The full 17-case integration suite was rerun at `7a2ea1e` after the final executable changes and returned **0**, with every expected status and diagnostic assertion passing. Its evidence is retained in the independent checkout at `.local-linter/integration-20261010-113655-b26a6d/`; the parent `integration-final.log` records the complete pass list. A final wrapper unit run also passed all 18 tests (`unit-delivery.log`). Documentation-only delivery changes followed these checks.

## Workspace and regression route

From the development checkout, the generated `.local-linter/Linter.xcworkspace` binds the engine and five dependencies to the exact local paths in configuration. These commands were executed:

```sh
xcodebuild -workspace .local-linter/Linter.xcworkspace -list
xcodebuild -workspace .local-linter/Linter.xcworkspace -scheme swift-linter -resolvePackageDependencies
xcodebuild -workspace .local-linter/Linter.xcworkspace -scheme swift-linter -destination 'platform=macOS' -derivedDataPath .local-linter/DerivedData build
./scripts/lint-local test
./scripts/lint-local test --package swift-institute-linter-rules
```

The explicit resolve returned **0** and positively bound all six local checkouts. The Xcode executable build returned **0**, `BUILD SUCCEEDED`. This is actual resolve/build evidence, not just a package listing. The locally bound `swift-institute-linter-rules` suite returned **0**, with **1,938 tests passing** across 19 test targets. The engine suite passed **149 tests** in its first cold run, but that invocation exited **3** because the wrapper could not fingerprint a generated nested Git directory afterward. Commit `7a2ea1e` fixed that wrapper bug with a regression test. The repeat engine run at that commit exited **3**: two existing nested-process tests failed (12 assertions) because their nested Swift builds hit the deployment-target mismatch below. Therefore the full engine test command is **not** claimed to pass reliably. The rule suite at `7a2ea1e` did return **0**, including the wrapper’s source/binding verification.

Xcode-native test builds are not claimed to pass. Their logs show an upstream `Crypto` macOS 12 / `System` macOS 27 deployment mismatch, and subsequent explicit-module/macro linker failures (`Carrier` witness symbols). The passing regression route is the locally bound SwiftPM **rule** test command above. The engine repeat failure likewise came from `Crypto` compiling for macOS 12 against a cached `System` module requiring macOS 27, under Swift 6.4’s default SwiftBuild backend; this is distinct from a linter rule finding. Failed attempts were retained; no dependency source or test was weakened to hide them. Some existing engine process tests independently resolve nested fixture packages from GitHub; they need network access and may fetch again on later runs. The new end-to-end local-rule probe independently verifies local source iteration without publication.

Retained detailed evidence (relative to the development directory):

- `workspace-results.json`, `workspace-resolve-verified.log`, `workspace-build.log`: explicit resolve exit 0 and successful executable build.
- `swift-linter/.local-linter/runs/20261010T092233Z-b8eff0fd/`: rule tests, receipt exit 0 and all 1,938 tests passed.
- `fresh setup with spaces/swift-linter/.local-linter/runs/20261010T091912Z-ea9293f1/tests.log`: cold engine test pass followed by the wrapper fingerprint failure.
- `fresh setup with spaces/swift-linter/.local-linter/runs/20261010T092930Z-34c57b34/tests.log`: repeat engine test failure; `engine-tests-final.stderr` includes the reported exit 3 failure.
- `fresh setup with spaces/swift-linter/.local-linter/runs/20261010T093346Z-f59e3e79/receipt.json`: subsequent ordinary selected-rule check exit 0 at `7a2ea1e`.
- `wrapper-tests-final.log`: 18 tests passed at `7a2ea1e`.

## Current real packages

Freshly cloned package heads, rather than the preserved pre-fix sample checkouts:

| Package | Revision | Three selected rules | Full bundle | Resolve/build/tests |
|---|---|---|---|---|
| swift-effects | be8bca90a7a0db8f74fe5f5ad498e44837d64810 | 0 findings; exit 0 | 92 findings, 0 unmeasured; one existing disclosed suppression | all exit 0; 11 tests |
| swift-test-application | e832144994d016f78211f6f2d117ba2e0c3e8ae1 | 0 findings; exit 0 | 1,234 findings, 0 unmeasured | all exit 0; 28 tests, including MacroSpec consumer tests |

Exact commands, with `name` set to each package above:

```sh
DEV=/Users/coen/Developer/coenttb/local-linter-development
swift package --package-path "$DEV/packages/$name" --cache-path "$DEV/package-cache" --config-path "$DEV/package-config" resolve
swift build --package-path "$DEV/packages/$name" --cache-path "$DEV/package-cache" --config-path "$DEV/package-config"
swift test --package-path "$DEV/packages/$name" --cache-path "$DEV/package-cache" --config-path "$DEV/package-config"
"$DEV/swift-linter/scripts/lint-local" check "$DEV/packages/$name"
"$DEV/swift-linter/scripts/lint-local" report "$DEV/packages/$name"
```

The exact expanded commands and statuses are retained in `package-results.json` and `sample-lint-results.json` in the development directory. Raw logs use `<package>-package.log`, `<package>-build.log`, `<package>-test.log`, and `<package>-<check|report>.<stdout|stderr>`.

## Delivery boundaries

The existing runner, rule implementations, and accepted graph remain intact. New maintained files provide setup, local checking, regression execution, documentation, and tests. The production release and consumers remain unchanged. Windows/Linux support and the previously reported Windows dependency failure are outside this macOS delivery. Selected-rule cleanliness is not full-bundle compliance or a substitute for package compilation/tests.
