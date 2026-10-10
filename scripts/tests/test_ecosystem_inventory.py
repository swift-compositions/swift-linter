import importlib.machinery
import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

loader = importlib.machinery.SourceFileLoader('ecosystem_inventory', str(Path(__file__).parents[1] / 'ecosystem-inventory'))
spec = importlib.util.spec_from_loader(loader.name, loader)
inventory = importlib.util.module_from_spec(spec)
loader.exec_module(inventory)


class InventoryTests(unittest.TestCase):
    def test_records_revision_and_dirty_state_without_entering_repository_caches(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name in ('library', 'consumer', 'consumer/.build/cached'):
                path = root / name
                (path / '.git').mkdir(parents=True)
                (path / 'Package.swift').write_text('// fixture')
            manifest = root / 'consumer/Package.swift'
            manifest.write_text('.package(name: "Library", url: "https://example.com/library.git", branch: "main")')
            def git(path, *args):
                if args[0] == 'remote':
                    return 'https://example.com/' + path.name + '.git'
                if args[0] == 'rev-parse':
                    return path.name + '-revision'
                return ' M Package.swift' if path.name == 'consumer' else ''
            before = manifest.read_bytes()
            with patch.object(inventory, 'git', git):
                result = inventory.inventory(root)
            self.assertEqual([p['path'] for p in result['packages']], ['consumer', 'library'])
            consumer = result['packages'][0]
            self.assertEqual(consumer['revision'], 'consumer-revision')
            self.assertEqual(consumer['status'], ' M Package.swift')
            self.assertEqual(consumer['localDependencies'], ['library'])
            self.assertEqual(consumer['unmatchedDependencyURLs'], [])
            self.assertEqual(manifest.read_bytes(), before)

    def test_empty_directory_is_an_explicit_empty_source_inventory(self):
        with tempfile.TemporaryDirectory() as directory:
            result = inventory.inventory(Path(directory))
            self.assertEqual(result['kind'], 'declared-source-inventory')
            self.assertEqual(result['packages'], [])
