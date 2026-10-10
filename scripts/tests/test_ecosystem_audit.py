import importlib.machinery
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

loader = importlib.machinery.SourceFileLoader('ecosystem_audit', str(Path(__file__).parents[1] / 'ecosystem-audit'))
spec = importlib.util.spec_from_loader(loader.name, loader)
audit = importlib.util.module_from_spec(spec)
loader.exec_module(audit)


class AuditTests(unittest.TestCase):
    def test_cycles_are_grouped_after_dependencies_and_before_consumers(self):
        rows = [('consumer', ['a']), ('a', ['b', 'leaf']), ('b', ['a']), ('leaf', [])]
        self.assertEqual(audit.groups([{'path': p, 'localDependencies': d} for p, d in rows]),
                         [['leaf'], ['a', 'b'], ['consumer']])

    def test_mapping_requires_component_boundary_and_explicit_coverage(self):
        mapping = {'atoms': 'primitives', 'atoms/special': 'institute'}
        self.assertEqual(audit.bundle_for('atoms/special/repo', mapping), 'institute')
        self.assertEqual(audit.bundle_for('atoms/repo', mapping), 'primitives')
        self.assertIsNone(audit.bundle_for('atoms-extra/repo', mapping))

    def test_baseline_never_excuses_unmeasured_or_new_packages(self):
        old = {'exitCode': 1, 'debt': {'x': 2}}
        self.assertEqual(audit.regression({'exitCode': 2, 'debt': {}}, old), 2)
        self.assertEqual(audit.regression({'exitCode': 0, 'debt': {}}, None), 1)
        self.assertEqual(audit.regression({'exitCode': 0, 'debt': {}}, {'exitCode': 2}), 1)
        self.assertEqual(audit.regression({'exitCode': 1, 'debt': {'x': 3}}, old), 1)
        self.assertEqual(audit.regression({'exitCode': 1, 'debt': {'x': 1}}, old), 0)

    def test_incomplete_duplicate_and_inconsistent_baselines_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'baseline.json'
            row = {'path': 'a', 'exitCode': 0, 'debt': {}}
            valid = {'metadata': {}, 'complete': True, 'expectedPackages': 1, 'packages': [row]}
            for invalid in [dict(valid, complete=False), dict(valid, expectedPackages=2),
                            dict(valid, packages=[row, row], expectedPackages=2),
                            dict(valid, packages=[dict(row, debt={'a' * 64: 1})])]:
                path.write_text(json.dumps(invalid))
                with self.assertRaises(audit.lint.Failure):
                    audit.load_baseline(path, {})
            path.write_text(json.dumps(valid))
            self.assertEqual(audit.load_baseline(path, {}), valid)

    def test_snapshot_includes_dirty_resources_and_ignored_swift_without_touching_original(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            original = root / 'original with spaces'
            original.mkdir()
            def git(*args):
                return subprocess.check_output(['git', '-C', str(original), *args], stderr=subprocess.DEVNULL)
            git('init')
            (original / 'Package.swift').write_text('// package\n')
            (original / '.gitignore').write_text('Ignored.swift\n.build/\n')
            (original / 'resource.txt').write_text('before')
            git('add', '.')
            git('-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid', 'commit', '-m', 'fixture')
            (original / 'resource.txt').write_text('working edit')
            (original / 'Ignored.swift').write_text('enum Ignored {}\n')
            (original / '.build').mkdir()
            (original / '.build/cache.swift').write_text('do not copy')
            before = git('status', '--porcelain')
            snapshot = root / 'snapshot'
            result = audit.snapshot_inputs(original, snapshot)
            self.assertEqual((snapshot / 'resource.txt').read_text(), 'working edit')
            self.assertTrue((snapshot / 'Ignored.swift').exists())
            self.assertFalse((snapshot / '.build').exists())
            self.assertFalse((snapshot / '.git').exists())
            self.assertIn('resource.txt', result['inputFilesSHA256'])
            self.assertEqual(git('status', '--porcelain'), before)

    def test_signature_preserves_multiplicity_suppressions_and_rejects_escape(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'A.swift').write_text('enum A {}\n')
            item = {'fileID': './A.swift', 'line': 1, 'rule': 'rule', 'message': 'finding'}
            debt = audit.signatures({'findings': [item, item], 'suppressions': [item]}, root)
            self.assertEqual(sorted(debt.values()), [1, 2])
            with self.assertRaises(audit.lint.Failure):
                audit.signatures({'findings': [dict(item, fileID='../A.swift')], 'suppressions': []}, root)
