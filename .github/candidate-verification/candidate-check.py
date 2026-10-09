import hashlib, json, os, subprocess, sys

binary, root, rules, out = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
selected = [r.strip() for r in rules.split(",") if r.strip()]

head = subprocess.run(["git", "-C", root, "rev-parse", "HEAD"], capture_output=True, text=True).stdout.strip()
diff = subprocess.run(["git", "-C", root, "diff", "HEAD"], capture_output=True).stdout
snapshot = hashlib.sha256(head.encode() + b"\0" + diff).hexdigest()[:16]

env = dict(os.environ, SWIFT_LINTER_BUNDLE="institute", SWIFT_LINTER_FORMAT="structured")
run = subprocess.run([binary, "."], cwd=root, env=env, capture_output=True)
open(out + ".json", "wb").write(run.stdout)
open(out + ".stderr", "wb").write(run.stderr)
report = json.loads(run.stdout)

findings = [f for f in report.get("findings", []) if f["rule"] in selected]
unmeasured = [o for o in report.get("observations", [])
              if o.get("coverage", {}).get("status") == "unmeasured" and o["rule"] in selected]
summary = report["summary"]
controls = summary.get("failedControls", 0) + summary.get("unmeasuredControls", 0)

lines = [f"subject {root} HEAD {head} snapshot {snapshot} engine-exit {run.returncode}"]
for f in findings:
    lines.append(f"{f['fileID']}:{f['line']}:{f['column']}: {f['severity']}: {f['rule']}")
for o in unmeasured:
    reason = o["coverage"].get("reason", {})
    lines.append(f"unmeasured: {o['file']}: {o['rule']}: {reason.get('code', '?')}: {reason.get('detail', '')}")
if controls:
    lines.append(f"unmeasured: rule controls {summary.get('failedControls', 0)} failed, {summary.get('unmeasuredControls', 0)} unmeasured")
code = 2 if unmeasured or controls else 1 if findings else 0
lines.append(f"verdict {['CLEAN', 'VIOLATIONS', 'UNMEASURED'][code]} exit {code}: {len(findings)} finding(s), {len(unmeasured)} unmeasured, total findings {summary.get('findings')}")
open(out + ".txt", "w").write("\n".join(lines) + "\n")
print("\n".join(lines))
sys.exit(code)
