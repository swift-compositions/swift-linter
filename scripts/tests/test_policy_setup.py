"""Policy setup must clone pinned sources without moving existing checkouts."""
import argparse
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from test_lint_local import lint


class PolicySetupTests(unittest.TestCase):
    def test_local_source_paths_are_relative_to_the_mapping_file(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            mapping = root / 'sources.json'
            origins = {name: '../sources with spaces/' + name for name in lint.NAMES[1:]}
            origins['swift-lint'] = 'https://example.test/swift-lint.git'
            mapping.write_text(json.dumps(origins))
            actual = lint.source_repositories(mapping)
            self.assertEqual(actual['swift-lint'], origins['swift-lint'])
            self.assertEqual(actual['swift-linter-rules'], str((root / origins['swift-linter-rules']).resolve()))
            mapping.write_text('{}')
            with self.assertRaises(lint.Failure) as caught:
                lint.source_repositories(mapping)
            self.assertEqual(caught.exception.code, 64)

    def test_policy_pins_override_defaults_only_for_new_clones(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            engine = root / 'engine'
            (engine / 'Runner').mkdir(parents=True)
            (engine / 'Package.swift').write_text('// fixture\n')
            pins = [{'identity': name, 'location': 'https://example.test/' + name,
                     'state': {'revision': 'a' * 40}} for name in lint.NAMES[1:]]
            (engine / 'Runner/accepted-graph.json').write_text(json.dumps({'pins': pins}))
            args = argparse.Namespace(command='setup', config=root / 'config.json', checkouts=None,
                policy_sources={name: 'b' * 40 for name in lint.NAMES[1:]},
                clone_origins={name: '/explicit sources/' + name for name in lint.NAMES[1:]})
            commands = []

            def run(command, **kwargs):
                commands.append(command)
                if command[:2] == ['git', 'clone']:
                    clone = Path(command[-1])
                    clone.mkdir(parents=True)
                    (clone / 'Package.swift').write_text('// fixture\n')
                if command[-2:] == ['rev-parse', '--show-toplevel']:
                    return command[2]
                return ''

            with patch.object(lint, 'REPO', engine), patch.object(lint, 'LOCAL', root / 'state'), patch.object(lint, 'run', run):
                paths = lint.configure(args, root / 'log')
                self.assertEqual(set(paths), set(lint.NAMES))
                clones = [c for c in commands if c[:2] == ['git', 'clone']]
                self.assertEqual(len(clones), 5)
                self.assertTrue(all(c[2] == '--no-local' and c[3].startswith('/explicit sources/') for c in clones))
                checkouts = [c for c in commands if 'checkout' in c]
                self.assertEqual(len(checkouts), 5)
                self.assertTrue(all(c[-2:] == ['--detach', 'b' * 40] for c in checkouts))
                commands.clear()
                args.policy_sources = {name: 'c' * 40 for name in lint.NAMES[1:]}
                lint.configure(args, root / 'log')
                self.assertFalse(any('checkout' in c or 'clone' in c for c in commands))

