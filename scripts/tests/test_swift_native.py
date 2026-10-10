import importlib.machinery
import importlib.util
from pathlib import Path
import unittest

loader = importlib.machinery.SourceFileLoader('swift_native', str(Path(__file__).parents[1] / 'swift-native'))
spec = importlib.util.spec_from_loader(loader.name, loader)
profile = importlib.util.module_from_spec(spec)
loader.exec_module(profile)


class NativeProfileTests(unittest.TestCase):
    def test_preserves_spaced_paths_and_product_arguments(self):
        args = ['run', '--package-path', '/a path/Package', 'Lint Runner', '/subject path']
        self.assertEqual(profile.arguments(args, 'arm64-apple-macosx27.0'), ['run', '--build-system', 'native', '-Xswiftc', '-target', '-Xswiftc', 'arm64-apple-macosx27.0', *args[1:]])

    def test_passes_toolchain_and_resolution_commands_through(self):
        for args in (['--version'], ['package', 'resolve'], []):
            self.assertEqual(profile.arguments(args, 'arm64-apple-macosx27.0'), args)

    def test_does_not_duplicate_the_explicit_backend(self):
        args = ['test', '--build-system', 'native', '-Xswiftc', '-target', '-Xswiftc', 'arm64-apple-macosx27.0']
        self.assertEqual(profile.arguments(args, 'arm64-apple-macosx27.0'), args)

    def test_conflicting_backend_is_visible_failure(self):
        for args in (['run', '--build-system', 'swiftbuild'], ['build', '--build-system=xcode']):
            with self.assertRaises(ValueError):
                profile.arguments(args, 'arm64-apple-macosx27.0')

    def test_target_is_required_and_conflicts_are_rejected(self):
        with self.assertRaises(ValueError):
            profile.arguments(['build'])
        for flags in (
            ['-Xswiftc', '-target', '-Xswiftc', 'arm64-apple-macosx12.0'],
            ['-Xswiftc=-target', '-Xswiftc=arm64-apple-macosx12.0'],
            ['-Xswiftc=-target=arm64-apple-macosx12.0'],
        ):
            with self.subTest(flags=flags), self.assertRaises(ValueError):
                profile.arguments(['run', *flags], 'arm64-apple-macosx27.0')

    def test_explicit_target_and_backend_are_not_added_twice(self):
        args = ['build', '--build-system=native', '-Xswiftc=-target=arm64-apple-macosx27.0']
        self.assertEqual(profile.arguments(args, 'arm64-apple-macosx27.0'), args)
