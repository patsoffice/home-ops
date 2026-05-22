#!/usr/bin/env python3
"""Deterministically stagger VolSync backup schedules across apps.

Every app that pulls in `kubernetes/components/volsync` runs a kopia backup on
`spec.trigger.schedule`. The shared component defaults to `0 * * * *`, so without
intervention all backups fire at minute 0 of every hour. That synchronized fan-out
spikes CPU on every node at once and trips Ceph's OSD slow-ping detector
(`OSD_SLOW_PING_TIME_BACK/FRONT` -> CephOSDTimeouts* alerts).

This script assigns each app a stable minute-of-hour derived from a hash of its
`<namespace>/<app>` key, then writes `VOLSYNC_SCHEDULE: "<min> * * * *"` into the
app's Flux Kustomization `spec.postBuild.substitute`. The component reads that var
(`${VOLSYNC_SCHEDULE:=0 * * * *}`), so apps without an override still work.

Assignment is a pure function of the set of volsync apps:
  base   = int(sha256("<namespace>/<app>").hexdigest()[:8], 16) % 60
  minute = base, advanced to the next free minute if taken (deterministic linear
           probe over apps sorted by key) so no two apps collide.

Adding/removing an app re-runs this generator and may shift a few probed minutes;
the result is committed to git, which is the source of truth.

Usage:
  scripts/volsync-schedules.py          # rewrite ks.yaml files in place
  scripts/volsync-schedules.py --check  # exit 1 if any file is out of date (CI/hook)
"""
from __future__ import annotations

import hashlib
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
APPS = REPO / "kubernetes" / "apps"
COMPONENT_MARKER = "components/volsync"
SLOTS = 60  # minutes in an hour


def app_namespace(text: str) -> tuple[str, str]:
    """Extract (namespace, app) from a Flux Kustomization ks.yaml.

    app       = the `name: &app <x>` anchor value.
    namespace = the app's real namespace = resolved `spec.targetNamespace`.
                When targetNamespace is the `*namespace` alias, resolve it to the
                `&namespace <x>` anchor; otherwise it's a literal.
    """
    m = re.search(r"&app\s+([a-z0-9][a-z0-9-]*)", text)
    if not m:
        raise ValueError("no `&app` anchor found")
    app = m.group(1)

    tns = re.search(r"targetNamespace:\s*(\S+)", text)
    if not tns:
        raise ValueError("no `targetNamespace` found")
    raw = tns.group(1)
    if raw.startswith("*"):  # alias -> resolve the matching anchor
        anchor = raw[1:]
        a = re.search(rf"&{re.escape(anchor)}\s+([a-z0-9][a-z0-9-]*)", text)
        if not a:
            raise ValueError(f"targetNamespace alias *{anchor} has no anchor")
        ns = a.group(1)
    else:
        ns = raw
    return ns, app


def base_minute(ns: str, app: str) -> int:
    digest = hashlib.sha256(f"{ns}/{app}".encode()).hexdigest()[:8]
    return int(digest, 16) % SLOTS


def assign(keys: list[tuple[str, str, Path]]) -> dict[Path, int]:
    """Map each file to a unique minute: hash, then linear-probe on collision.

    Iterate apps sorted by `<namespace>/<app>` so the assignment is independent of
    filesystem ordering and fully reproducible.
    """
    taken: set[int] = set()
    out: dict[Path, int] = {}
    for ns, app, path in sorted(keys, key=lambda k: f"{k[0]}/{k[1]}"):
        m = base_minute(ns, app)
        while m in taken:
            m = (m + 1) % SLOTS
        taken.add(m)
        out[path] = m
    return out


def set_schedule(text: str, minute: int) -> str:
    """Insert or update VOLSYNC_SCHEDULE inside spec.postBuild.substitute."""
    value = f"{minute} * * * *"
    lines = text.splitlines(keepends=True)

    # Locate the `substitute:` line and the indent of its children.
    sub_idx = None
    for i, line in enumerate(lines):
        if re.match(r"^\s+substitute:\s*$", line):
            sub_idx = i
            break
    if sub_idx is None:
        raise ValueError("no `postBuild.substitute:` block found")
    sub_indent = len(lines[sub_idx]) - len(lines[sub_idx].lstrip())
    child_indent = sub_indent + 2

    # Scan the block's children for an existing VOLSYNC_SCHEDULE.
    j = sub_idx + 1
    while j < len(lines):
        stripped = lines[j].strip()
        if stripped == "" or stripped.startswith("#"):
            j += 1
            continue
        indent = len(lines[j]) - len(lines[j].lstrip())
        if indent < child_indent:  # left the substitute block
            break
        if re.match(r"VOLSYNC_SCHEDULE:", stripped):
            lines[j] = f'{" " * child_indent}VOLSYNC_SCHEDULE: "{value}"\n'
            return "".join(lines)
        j += 1

    # Not present: insert as the first child of substitute.
    lines.insert(sub_idx + 1, f'{" " * child_indent}VOLSYNC_SCHEDULE: "{value}"\n')
    return "".join(lines)


def main() -> int:
    check = "--check" in sys.argv[1:]

    volsync_files: list[tuple[str, str, Path]] = []
    for ks in sorted(APPS.glob("**/ks.yaml")):
        text = ks.read_text()
        if COMPONENT_MARKER not in text:
            continue
        ns, app = app_namespace(text)
        volsync_files.append((ns, app, ks))

    minutes = assign(volsync_files)

    drift = []
    for ns, app, ks in sorted(volsync_files, key=lambda k: f"{k[0]}/{k[1]}"):
        minute = minutes[ks]
        original = ks.read_text()
        updated = set_schedule(original, minute)
        rel = ks.relative_to(REPO)
        status = "ok" if updated == original else ("stale" if check else "write")
        print(f"{minute:2d} * * * *   {ns}/{app:<24}  {status}  {rel}")
        if updated != original:
            if check:
                drift.append(rel)
            else:
                ks.write_text(updated)

    if check and drift:
        print(f"\n{len(drift)} file(s) out of date. Run: task kubernetes:volsync-schedules", file=sys.stderr)
        return 1
    print(f"\n{len(volsync_files)} volsync app(s); {len(set(minutes.values()))} distinct minute(s).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
