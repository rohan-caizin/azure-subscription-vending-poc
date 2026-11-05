#!/usr/bin/env python3
"""Validate landing-zone request files before Terraform runs (proposal §5, "Validate" stage).

Checks:
  1. Folder layout: landing-zones/<archetype>/<request-key>.yaml, known archetypes only
  2. Request key naming, and no duplicate keys across archetype folders
  3. Each file against schema/landing-zone.schema.json
  4. Spoke CIDRs: valid, inside the spoke range, no overlap with each other or the hub
  5. mg_association: at most one request per subscription manages the management group

Usage:
  python scripts/validate_requests.py [landing_zones_dir] [schema_file]
Exit code 0 = all good, 1 = at least one error.
"""
from __future__ import annotations

import ipaddress
import json
import os
import re
import sys
from collections import defaultdict
from pathlib import Path

try:
    import yaml
    from jsonschema import Draft202012Validator
except ImportError:
    sys.exit("Missing dependencies: pip install pyyaml jsonschema")

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_LZ_DIR = REPO_ROOT / "vending" / "landing-zones"
DEFAULT_SCHEMA = REPO_ROOT / "schema" / "landing-zone.schema.json"

ARCHETYPES = {"corp", "sandbox", "decommissioned"}
KEY_PATTERN = re.compile(r"^[a-z0-9]([a-z0-9-]{1,38})[a-z0-9]$")
SPOKE_RANGE = ipaddress.ip_network("10.20.0.0/16")
RESERVED = {"hub": ipaddress.ip_network("10.100.0.0/22")}


def main() -> int:
    lz_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_LZ_DIR
    schema_path = Path(sys.argv[2]) if len(sys.argv) > 2 else DEFAULT_SCHEMA

    validator = Draft202012Validator(json.loads(schema_path.read_text(encoding="utf-8")))
    errors: list[str] = []
    seen_keys: dict[str, Path] = {}
    networks: list[tuple[str, ipaddress.IPv4Network]] = []
    mg_managers: dict[str, list[str]] = defaultdict(list)

    files = sorted(lz_dir.rglob("*"))
    if not any(f.is_file() for f in files):
        print(f"No request files found under {lz_dir}")
        return 0

    for path in files:
        if not path.is_file():
            continue
        rel = path.relative_to(lz_dir).as_posix()

        # 1. layout
        parts = path.relative_to(lz_dir).parts
        if len(parts) != 2 or path.suffix != ".yaml":
            errors.append(f"{rel}: must be landing-zones/<archetype>/<key>.yaml (use the .yaml extension)")
            continue
        archetype, key = parts[0], path.stem
        if archetype not in ARCHETYPES:
            errors.append(f"{rel}: unknown archetype folder '{archetype}' (allowed: {', '.join(sorted(ARCHETYPES))})")

        # 2. key
        if not KEY_PATTERN.match(key):
            errors.append(f"{rel}: request key '{key}' must be 3-40 chars, lowercase letters, digits and '-'")
        if key in seen_keys:
            errors.append(f"{rel}: duplicate request key '{key}' (also {seen_keys[key].relative_to(lz_dir).as_posix()})")
        seen_keys[key] = path

        # 3. schema
        try:
            data = yaml.safe_load(path.read_text(encoding="utf-8"))
        except yaml.YAMLError as exc:
            errors.append(f"{rel}: invalid YAML: {exc}")
            continue
        if not isinstance(data, dict):
            errors.append(f"{rel}: top level must be a mapping")
            continue
        schema_errors = sorted(validator.iter_errors(data), key=lambda e: list(e.path))
        for err in schema_errors:
            where = "/".join(str(p) for p in err.path) or "(root)"
            errors.append(f"{rel}: {where}: {err.message}")
        if schema_errors:
            continue

        # 4. CIDRs
        for cidr in data["network"]["address_space"]:
            try:
                net = ipaddress.ip_network(cidr, strict=True)
            except ValueError as exc:
                errors.append(f"{rel}: invalid CIDR {cidr}: {exc}")
                continue
            if not net.subnet_of(SPOKE_RANGE):
                errors.append(f"{rel}: {cidr} is outside the spoke range {SPOKE_RANGE}")
            networks.append((rel, net))

        # 5. MG association ownership
        sub = data.get("subscription_id", "<default>")
        if data.get("mg_association", True):
            mg_managers[sub].append(rel)

    for i, (file_a, net_a) in enumerate(networks):
        for name, reserved in RESERVED.items():
            if net_a.overlaps(reserved):
                errors.append(f"{file_a}: {net_a} overlaps the {name} range {reserved}")
        for file_b, net_b in networks[i + 1:]:
            if net_a.overlaps(net_b):
                errors.append(f"{file_a}: {net_a} overlaps {net_b} in {file_b}")

    for sub, owners in mg_managers.items():
        if len(owners) > 1:
            errors.append(
                f"subscription {sub} has its management group managed by {len(owners)} requests "
                f"({', '.join(owners)}); set 'mg_association: false' on all but one"
            )

    if errors:
        print(f"FAILED: {len(errors)} problem(s) in landing-zone requests:")
        for e in errors:
            print(f"  - {e}")
            if "GITHUB_ACTIONS" in os.environ:
                print(f"::error::{e}")
        return 1

    print(f"OK: {len(seen_keys)} request(s) valid: {', '.join(sorted(seen_keys))}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
