#!/usr/bin/env python3
"""Real user workflow; run after setup in a disposable development clone.

Preserves fixtures, exact commands, and output under .local-linter/integration-*.
Temporarily edits one diagnostic message in the configured local rule source,
restoring the original bytes in finally. No rule predicate or control is weakened.
"""
import datetime
import json
from pathlib import Path
import subprocess
import sys
import uuid

REPO = Path(__file__).resolve().parents[2]
CLI = REPO / "scripts/lint-local"
ROOT = REPO / ".local-linter" / ("integration-" + datetime.datetime.now().strftime("%Y%m%d-%H%M%S") + "-" + uuid.uuid4().hex[:6])
MANIFEST = '''// swift-tools-version: 6.4
import PackageDescription
let package = Package(
    name: "Fixture",
    products: [.library(name: "Fixture", targets: ["Fixture"])],
    targets: [.target(name: "Fixture", dependencies: [.target(name: "Helper")]), .target(name: "Helper")]
)
'''
CLEAN = "protocol View {}\nfunc render<V: View>(_ view: V) {}\n"
VIOLATION = "protocol View {}\nfunc render(_ view: any View) {}\n"
results = []


def check(name, expected, *args, contains=None):
    command = [str(CLI), *map(str, args)]
    result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True)
    (ROOT / (name + ".stdout")).write_text(result.stdout)
    (ROOT / (name + ".stderr")).write_text(result.stderr)
    results.append({"case": name, "command": command, "expected": expected, "actual": result.returncode})
    (ROOT / "results.json").write_text(json.dumps(results, indent=2) + "\n")
    assert result.returncode == expected, f"{name}: expected {expected}, got {result.returncode}\n{result.stderr}"
    if contains:
        assert contains in result.stdout + result.stderr, f"{name}: missing {contains}"
    print(f"PASS {name}: exit {expected}", flush=True)
    return result


def main():
    ROOT.mkdir(parents=True)
    print(f"Evidence: {ROOT}", flush=True)
    package = ROOT / "Package with spaces"
    source = package / "Sources/Fixture/Fixture.swift"
    source.parent.mkdir(parents=True)
    helper = package / "Sources/Helper/Helper.swift"
    helper.parent.mkdir(parents=True)
    helper.write_text("public struct Helper {}\n")
    manifest = package / "Package.swift"
    manifest.write_text(MANIFEST)
    source.write_text(CLEAN)
    check("clean", 0, "check", package, contains="SELECTED-RULE CLEAN")
    source.write_text(VIOLATION)
    check("package-edit", 1, "check", package, contains="Fixture.swift:2:")
    source.write_text(CLEAN)
    check("package-fix", 0, "check", package)
    manifest.write_text(MANIFEST.replace('[.target(name: "Helper")]', '["Helper"]'))
    check("bare-string", 1, "check", package, contains="bare string dependency")
    manifest.write_text(MANIFEST + "let broken = (\n")
    check("malformed-manifest", 2, "check", package, contains="manifest does not parse")
    manifest.write_text(MANIFEST + 'let other = Package(name: "Other")\n')
    check("ambiguous-manifest", 2, "check", package, contains="unmeasured:")
    manifest.write_text(MANIFEST)
    source.write_text('''struct Box: Codable {
    init(from decoder: any Decoder) throws {}
    func encode(to encoder: any Encoder) throws {}
}
''')
    check("codable-witnesses", 0, "check", package, "--rules", "existential parameter")
    source.write_text("func log(_ encoder: any Encoder) {}\n")
    check("non-witness-counterexample", 1, "check", package, "--rules", "existential parameter")
    source.write_text(VIOLATION)
    check("unknown-rule", 3, "check", package, "--rules", "no such rule", contains="lint-local rules")
    check("bad-usage", 64, "check", package, "--rules", "", contains="--help")
    check("not-package", 64, "check", ROOT)
    config = json.loads((REPO / ".local-linter/config.json").read_text())
    broken = json.loads(json.dumps(config))
    broken["sources"]["swift-lint"] = str(ROOT / "missing checkout")
    bad_config = ROOT / "broken config.json"
    bad_config.write_text(json.dumps(broken))
    check("setup-failure", 3, "--config", bad_config, "check", package, contains="missing Package.swift")
    rule = Path(config["sources"]["swift-institute-linter-rules"]) / "Sources/Institute Linter Rule Idiom/Lint.Rule.Idiom.ExistentialParameter.swift"
    original = rule.read_bytes()
    marker = "LOCAL-RULE-EDIT-PROBE"
    old = "generic parameter instead. `any Error` is admitted."
    assert old.encode() in original
    try:
        rule.write_bytes(original + b'\n#error("LOCAL-BUILD-FAILURE-PROBE")\n')
        check("build-failure", 3, "check", package, contains="LOCAL-BUILD-FAILURE-PROBE")
    finally:
        rule.write_bytes(original)
    try:
        rule.write_bytes(original.replace(old.encode(), (old + " " + marker).encode()))
        changed = check("local-rule-edit", 1, "check", package, "--rules", "existential parameter", contains=marker)
        assert "+1changed" in changed.stderr
    finally:
        rule.write_bytes(original)
    restored = check("local-rule-restored", 1, "check", package, "--rules", "existential parameter")
    assert marker not in restored.stdout
    source.write_text(CLEAN)
    check("final-clean", 0, "check", package)
    # This minimal manifest intentionally lacks the full institute policy settings.
    # Selected rules are clean; a different rule is explicitly unmeasured.
    check("full-report", 2, "report", package, contains="package policy revision 1")
    print(f"All {len(results)} workflow cases passed. Evidence: {ROOT}")


if __name__ == "__main__":
    main()
