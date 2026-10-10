"""Fast contract tests. Real compilation/measurement lives in integration.py."""
import contextlib
import copy
import importlib.machinery
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[1] / "lint-local"
loader = importlib.machinery.SourceFileLoader("lint_local", str(SCRIPT))
spec = importlib.util.spec_from_loader(loader.name, loader)
lint = importlib.util.module_from_spec(spec)
loader.exec_module(lint)


def report():
    return {
        "schema": 2, "files": ["./Package.swift"], "activeRules": ["rule"], "applicableRules": ["rule"],
        "observations": [{"file": "./Package.swift", "rule": "rule", "applicable": True,
                          "coverage": {"status": "measured"}}],
        "findings": [], "suppressions": [],
        "controls": [{"identity": "clean", "rule": "rule", "expectation": {"status": "clean"},
                      "actualFindings": 0, "coverage": {"status": "measured"}}],
        "summary": {"files": 1, "activeRules": 1, "applicableRules": 1, "applicableObservations": 1,
                    "measuredObservations": 1, "unmeasuredObservations": 0, "findings": 0,
                    "suppressions": 0, "controls": 1, "failedControls": 0, "unmeasuredControls": 0},
    }


def finding():
    return {"rule": "rule", "fileID": "./Package.swift", "line": 3, "column": 9,
            "severity": "warning", "message": "real violation"}


class VerdictTests(unittest.TestCase):
    def check(self, data, expected, status=0, report_mode=False):
        lint.validate_report(data, ["rule"])
        with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(lint.verdict(data, ["rule"], status, report_mode), expected)

    def test_clean(self):
        self.check(report(), 0)

    def test_partial_source_scan_is_not_clean(self):
        with self.assertRaises(lint.Failure) as error:
            lint.validate_report(report(), ["rule"], ["Package.swift", "Sources/Missed.swift"])
        self.assertEqual(error.exception.code, 2)

    def test_real_finding_even_when_runner_is_advisory(self):
        data = report()
        data["findings"] = [finding()]
        data["summary"]["findings"] = 1
        self.check(data, 1)
        self.check(data, 0, report_mode=True)

    def test_unmeasured_dominates_findings(self):
        data = report()
        data["findings"] = [finding()]
        data["summary"].update(findings=1, measuredObservations=0, unmeasuredObservations=1)
        data["observations"][0]["coverage"] = {"status": "unmeasured", "reason": {"code": "parse"}}
        self.check(data, 2, status=2)
        self.check(data, 2, status=2, report_mode=True)

    def test_failed_controls_are_incomplete(self):
        data = report()
        data["controls"][0]["actualFindings"] = 1
        data["summary"]["failedControls"] = 1
        self.check(data, 2, status=1)

    def test_unmeasured_controls_are_incomplete(self):
        data = report()
        data["controls"][0]["coverage"] = {"status": "unmeasured", "reason": {"code": "semantic"}}
        data["summary"]["unmeasuredControls"] = 1
        self.check(data, 2, status=2)

    def test_unexplained_exit_never_clean(self):
        for status in (1, 2, 3, -9, 64):
            with self.subTest(status=status):
                self.check(report(), 2, status=status)

    def test_suppressions_are_disclosed(self):
        data = report()
        data["suppressions"] = [finding()]
        data["summary"]["suppressions"] = 1
        lint.validate_report(data, ["rule"])
        stream = io.StringIO()
        with contextlib.redirect_stderr(stream):
            self.assertEqual(lint.verdict(data, ["rule"], 0), 0)
        self.assertIn("1 suppressions", stream.getvalue())

    def test_corrupt_or_partial_evidence_rejected(self):
        mutations = [
            lambda d: d.update(schema=1),
            lambda d: d.update(files=[]),
            lambda d: d.update(files=["./Other.swift"]),
            lambda d: d.update(activeRules=[]),
            lambda d: d.update(observations=[]),
            lambda d: d["observations"].append(copy.deepcopy(d["observations"][0])),
            lambda d: d.update(controls=[]),
            lambda d: d["observations"][0].update(coverage={"status": "unknown"}),
            lambda d: d["summary"].update(findings=7),
            lambda d: d["summary"].update(files=True),
            lambda d: d.update(applicableRules=[]),
        ]
        for mutate in mutations:
            data = report()
            mutate(data)
            with self.subTest(mutation=mutate):
                with self.assertRaises(lint.Failure) as error:
                    lint.validate_report(data, ["rule"])
                self.assertEqual(error.exception.code, 2)

    def test_other_rule_incompleteness_does_not_claim_full_bundle_clean(self):
        data = report()
        data["summary"]["unmeasuredObservations"] = 1
        data["observations"].append({"rule": "other", "coverage": {"status": "unmeasured"}})
        with contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(lint.verdict(data, ["rule"], 2), 0)


class WorkflowTests(unittest.TestCase):
    def test_help_is_success_and_invalid_cli_is_usage(self):
        for args, code in [(["--help"], 0), (["check", "--help"], 0), ([], 64),
                           (["check", ".", "--rules", ""], 64),
                           (["check", ".", "--rules", "rule,rule"], 64),
                           (["check", ".", "--unknown"], 64),
                           (["report", ".", "--rules", "rule"], 64)]:
            with self.subTest(args=args):
                result = subprocess.run([str(SCRIPT), *args], capture_output=True, text=True)
                self.assertEqual(result.returncode, code, result.stderr)

    def test_environment_cannot_disable_rules(self):
        with patch.dict(lint.os.environ, {"SWIFT_LINTER_SELECTION": "bad", "SWIFT_LINTER_POLICY": "bad"}):
            env = lint.runner_environment("institute")
        self.assertEqual({k: v for k, v in env.items() if k.startswith("SWIFT_LINTER_")},
                         {"SWIFT_LINTER_BUNDLE": "institute", "SWIFT_LINTER_FORMAT": "structured"})

    def test_missing_configuration_is_actionable_setup_failure(self):
        with tempfile.TemporaryDirectory() as directory:
            args = lint.arguments(["--config", directory + "/missing.json", "rules"])
            with self.assertRaises(lint.Failure) as error:
                lint.configure(args, Path(directory) / "log")
            self.assertEqual(error.exception.code, 3)
            self.assertIn("setup", str(error.exception))

    def test_snapshot_includes_untracked_sources_and_changes(self):
        with tempfile.TemporaryDirectory(prefix="linter spaces ") as directory:
            path = Path(directory)
            subprocess.run(["git", "init", "-q", str(path)], check=True)
            subprocess.run(["git", "-C", str(path), "commit", "--allow-empty", "-qm", "Fixture"], check=True)
            before = lint.identity(path)
            (path / "Rule.swift").write_text("let value = 1\n")
            first = lint.identity(path)
            (path / "Rule.swift").write_text("let value = 2\n")
            second = lint.identity(path)
            self.assertNotEqual(before["snapshot"], first["snapshot"])
            self.assertNotEqual(first["snapshot"], second["snapshot"])
            self.assertEqual(second["untracked"], 1)

    def test_package_snapshot_ignores_builds_and_nested_packages(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "Package.swift").write_text("manifest")
            initial = lint.package_snapshot(root)
            for folder in (".build", "Nested"):
                (root / folder).mkdir()
                (root / folder / "Package.swift").write_text("nested")
            self.assertEqual(lint.package_snapshot(root), initial)
            (root / "Source.swift").write_text("func f() {}")
            self.assertNotEqual(lint.package_snapshot(root), initial)


if __name__ == "__main__":
    unittest.main()
