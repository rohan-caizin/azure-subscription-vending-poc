#!/usr/bin/env python3
"""Cross-request checks that one Terraform run (one request) cannot see.

Field-level rules (name format, archetype, GUIDs, tags...) live in
modules/landing-zone/variables.tf and run in every plan. This script checks:

  1. Layout: subscriptions/<team>/<name>.yaml, and the file name equals `name`
  2. `name` is unique across all requests
  3. Network: address spaces inside the spoke range, no overlap with each other or
     the hub, every subnet inside its address space, subnets don't overlap
  4. At most one request per adopted subscription manages its management group

Usage:  python ci/validate_requests.py [subscriptions_dir]
Exit code 0 = all good, 1 = at least one problem.
"""
from __future__ import annotations

import ipaddress
import os
import sys
from collections import defaultdict
from pathlib import Path

try:
    import yaml
except ImportError:
    sys.exit("Missing dependency: pip install pyyaml")

REPO_ROOT = Path(__file__).resolve().parent.parent
SPOKE_RANGE = ipaddress.ip_network("10.20.0.0/16")
RESERVED = {"hub": ipaddress.ip_network("10.100.0.0/22")}


def main() -> int:
    root = Path(sys.argv[1]) if len(sys.argv) > 1 else REPO_ROOT / "subscriptions"
    errors: list[str] = []
    names: dict[str, str] = {}
    spaces: list[tuple[str, ipaddress.IPv4Network]] = []
    mg_managers: dict[str, list[str]] = defaultdict(list)

    files = sorted(p for p in root.rglob("*") if p.is_file())
    for path in files:
        rel = path.relative_to(root.parent).as_posix()
        parts = path.relative_to(root).parts

        # 1. layout
        if len(parts) != 2 or path.suffix != ".yaml":
            errors.append(f"{rel}: must be subscriptions/<team>/<name>.yaml (use the .yaml extension)")
            continue
        try:
            req = yaml.safe_load(path.read_text(encoding="utf-8"))
        except yaml.YAMLError as exc:
            errors.append(f"{rel}: invalid YAML: {exc}")
            continue
        if not isinstance(req, dict):
            errors.append(f"{rel}: top level must be a mapping")
            continue
        name = str(req.get("name", ""))
        if name != path.stem:
            errors.append(f"{rel}: file name must equal name ('{name}')")

        # 2. unique names
        if name in names:
            errors.append(f"{rel}: duplicate name '{name}' (also {names[name]})")
        names[name] = rel

        # 3. network
        net = req.get("network")
        if isinstance(net, dict):
            try:
                space = ipaddress.ip_network(str(net.get("address_space")), strict=True)
            except ValueError as exc:
                errors.append(f"{rel}: network.address_space: {exc}")
                space = None
            if space is not None:
                if not space.subnet_of(SPOKE_RANGE):
                    errors.append(f"{rel}: {space} is outside the spoke range {SPOKE_RANGE}")
                spaces.append((rel, space))
                subnets: list[tuple[str, ipaddress.IPv4Network]] = []
                for key, prefix in (net.get("subnets") or {}).items():
                    try:
                        sn = ipaddress.ip_network(str(prefix), strict=True)
                    except ValueError as exc:
                        errors.append(f"{rel}: network.subnets.{key}: {exc}")
                        continue
                    if not sn.subnet_of(space):
                        errors.append(f"{rel}: subnet {key} {sn} is outside {space}")
                    for other_key, other in subnets:
                        if sn.overlaps(other):
                            errors.append(f"{rel}: subnet {key} {sn} overlaps subnet {other_key} {other}")
                    subnets.append((key, sn))

        # 4. management group ownership for adopted subscriptions
        sub = req.get("subscription_id")
        if sub and req.get("manage_management_group", True):
            mg_managers[str(sub)].append(rel)

    for i, (file_a, a) in enumerate(spaces):
        for label, reserved in RESERVED.items():
            if a.overlaps(reserved):
                errors.append(f"{file_a}: {a} overlaps the {label} range {reserved}")
        for file_b, b in spaces[i + 1:]:
            if a.overlaps(b):
                errors.append(f"{file_a}: {a} overlaps {b} in {file_b}")

    for sub, owners in mg_managers.items():
        if len(owners) > 1:
            errors.append(
                f"subscription {sub} has its management group managed by {len(owners)} requests "
                f"({', '.join(owners)}); set 'manage_management_group: false' on all but one"
            )

    if errors:
        print(f"FAILED: {len(errors)} problem(s) in subscription requests:")
        for e in errors:
            print(f"  - {e}")
            if "GITHUB_ACTIONS" in os.environ:
                print(f"::error::{e}")
        return 1

    print(f"OK: {len(names)} request(s): {', '.join(sorted(names))}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
