#!/usr/bin/env python3
"""Exercise the real full-policy gate on an isolated copy of its reference package."""
import argparse
import datetime
import json
from pathlib import Path
import subprocess
import uuid

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--linter', type=Path, required=True)
parser.add_argument('--config', type=Path, required=True)
parser.add_argument('--policy', type=Path, required=True)
parser.add_argument('--package', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
root = args.output.resolve() / ('policy-workflow-' + datetime.datetime.now().strftime('%Y%m%d-%H%M%S') + '-' + uuid.uuid4().hex[:6])
root.mkdir(parents=True)
package = root / 'package with spaces'
subprocess.run(['git', 'clone', '--no-local', str(args.package.resolve()), str(package)], check=True)
policy = json.loads(args.policy.read_text())
policy_path = root / 'policy.json'
policy_path.write_text(json.dumps(policy, indent=2) + '\n')
config = args.config.resolve()
cli = args.linter.resolve() / 'scripts/lint-local'
results = []


def check(name, expected, chosen_policy=policy_path, chosen_config=config):
    command = [str(cli), '--config', str(chosen_config), 'check', str(package), '--policy', str(chosen_policy)]
    run = subprocess.run(command, text=True, capture_output=True)
    (root / (name + '.stdout')).write_text(run.stdout)
    (root / (name + '.stderr')).write_text(run.stderr)
    results.append({'case': name, 'command': command, 'expected': expected, 'actual': run.returncode})
    (root / 'commands.json').write_text(json.dumps(results, indent=2) + '\n')
    if run.returncode != expected:
        raise SystemExit(f'{name}: expected {expected}, got {run.returncode}; see {root}')
    print(f'PASS {name}: exit {expected}', flush=True)
    return run


print(f'Evidence: {root}', flush=True)
check('clean-path-with-spaces', 0)
probe = package / 'Sources/Effects/Probe.swift'
probe.write_text('public func invoke(_ value: any Sendable) {}\n')
try:
    result = check('real-package-violation', 1)
    if 'existential parameter' not in result.stdout:
        raise SystemExit('Expected the existential parameter finding; inspect retained evidence')
finally:
    (root / 'violation-source.txt').write_bytes(probe.read_bytes())
    probe.unlink()
check('package-fixed', 0)
source = package / 'Sources/Effects/Effect.Handled.swift'
original = source.read_bytes()
try:
    source.write_text('public enum Broken {{\n')
    check('malformed-source', 2)
finally:
    source.write_bytes(original)
check('malformed-source-fixed', 0)
reviewed = package / policy['reviewedSuppressions'][0]['file']
original = reviewed.read_bytes()
try:
    reviewed.write_bytes(original + b'\n')
    check('changed-suppression-context', 1)
finally:
    reviewed.write_bytes(original)
missing = root / 'missing-rule-policy.json'
missing.write_text(json.dumps({**policy, 'requiredRules': policy['requiredRules'][1:]}))
check('omitted-rule', 2, missing)
wrong = root / 'wrong-source-policy.json'
wrong.write_text(json.dumps({**policy, 'sources': {**policy['sources'], 'swift-linter': '0' * 40}}))
check('wrong-source-revision', 3, wrong)
invalid = root / 'invalid-policy.json'
invalid.write_text('{}')
check('invalid-policy', 64, invalid)
broken_config = json.loads(config.read_text())
broken_config['sources']['swift-institute-linter-rules'] = str(root / 'missing checkout')
broken = root / 'broken-config.json'
broken.write_text(json.dumps(broken_config))
check('setup-failure', 3, chosen_config=broken)
check('final-clean', 0)
print(f'All {len(results)} full-policy workflow cases passed. Evidence: {root}', flush=True)
