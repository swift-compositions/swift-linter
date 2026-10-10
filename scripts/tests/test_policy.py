"""Full-policy checks must reject partial, changed, or silently suppressed results."""
import contextlib
import copy
import hashlib
import io
import json
from pathlib import Path
import tempfile
import unittest

from test_lint_local import lint, report, finding


class PolicyTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        (self.root / "Package.swift").write_text("// reviewed source\n")
        self.toolchain = {"swift": "Swift version 6.4", "xcode": "Xcode 27.1"}
        self.sources = {name: {"revision": "a" * 40, "changed": 0, "untracked": 0} for name in lint.NAMES}
        self.pin = {"identity": "dependency", "location": "https://example.test/dependency.git",
                    "state": {"revision": "b" * 40}}
        self.policy = {"schema": 1, "bundle": "institute", "requiredRules": ["rule"],
                       "sources": {name: "a" * 40 for name in lint.NAMES},
                       "toolchain": {**self.toolchain, "buildSystem": lint.BUILD_SYSTEM, "swiftTarget": lint.swift_target()},
                       "dependencyPins": [self.pin], "reviewedSuppressions": []}

    def verdict(self, data, expected, status=0):
        lint.validate_report(data, ["rule"])
        with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            selected = lint.verdict(data, ["rule"], status)
            self.assertEqual(lint.policy_verdict(self.policy, data, self.root, selected), expected)

    def test_full_clean_and_real_violation(self):
        self.verdict(report(), 0)
        data = report()
        data["findings"] = [finding()]
        data["summary"]["findings"] = 1
        self.verdict(data, 1)

    def test_incomplete_dominates_findings_and_reviews(self):
        data = report()
        data["observations"][0]["coverage"] = {"status": "unmeasured", "reason": {"code": "parse"}}
        data["summary"].update(measuredObservations=0, unmeasuredObservations=1)
        self.verdict(data, 2, status=2)

    def test_unknown_suppression_cannot_pass(self):
        data = report()
        data["suppressions"] = [finding()]
        data["summary"]["suppressions"] = 1
        self.verdict(data, 1)

    def test_review_is_bound_to_exact_file_and_location(self):
        data = report()
        data["suppressions"] = [finding()]
        data["summary"]["suppressions"] = 1
        self.policy["reviewedSuppressions"] = [{"rule": "rule", "file": "Package.swift", "line": 3,
            "fileSHA256": hashlib.sha256((self.root / "Package.swift").read_bytes()).hexdigest(),
            "reason": "Protocol contract requires this declaration."}]
        self.verdict(data, 0)
        (self.root / "Package.swift").write_text("// changed suppression context\n")
        self.verdict(data, 1)
        self.verdict(report(), 1)

    def test_added_and_removed_rules_are_incomplete(self):
        for rules in ([], ["rule", "new rule"]):
            with self.subTest(rules=rules), self.assertRaises(lint.Failure) as caught:
                lint.verify_policy_inventory(self.policy, rules, {"pins": [self.pin]})
            self.assertEqual(caught.exception.code, 2)

    def test_changed_graph_is_setup_failure(self):
        lint.verify_policy_inventory(self.policy, ["rule"], {"pins": [self.pin]})
        other = copy.deepcopy(self.pin)
        other["state"]["revision"] = "c" * 40
        with self.assertRaises(lint.Failure) as caught:
            lint.verify_policy_inventory(self.policy, ["rule"], {"pins": [other]})
        self.assertEqual(caught.exception.code, 3)

    def test_wrong_revision_dirty_and_untracked_tools_are_rejected(self):
        lint.verify_policy_tools(self.policy, self.sources, self.toolchain)
        for field, value in (("revision", "c" * 40), ("changed", 1), ("untracked", 1)):
            changed = copy.deepcopy(self.sources)
            changed["swift-linter"][field] = value
            with self.subTest(field=field), self.assertRaises(lint.Failure) as caught:
                lint.verify_policy_tools(self.policy, changed, self.toolchain)
            self.assertEqual(caught.exception.code, 3)

    def test_wrong_toolchain_is_rejected(self):
        with self.assertRaises(lint.Failure):
            lint.verify_policy_tools(self.policy, self.sources, {**self.toolchain, "swift": "other"})

    def test_policy_schema_and_mutually_exclusive_cli(self):
        path = self.root / "policy.json"
        path.write_text(json.dumps(self.policy))
        self.assertEqual(lint.load_policy(path), self.policy)
        for field, value in (("requiredRules", ["rule", "rule"]), ("sources", {}), ("schema", 2)):
            bad = {**self.policy, field: value}
            path.write_text(json.dumps(bad))
            with self.subTest(field=field), self.assertRaises(lint.Failure) as caught:
                lint.load_policy(path)
            self.assertEqual(caught.exception.code, 64)
        with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(lint.Failure) as caught:
            lint.arguments(["check", str(self.root), "--rules", "rule", "--policy", str(path)])
        self.assertEqual(caught.exception.code, 64)
