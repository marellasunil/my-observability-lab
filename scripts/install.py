#!/usr/bin/env python3
"""Explicit, local-first Helm orchestration; plan by default."""
import argparse
import pathlib
import re
import shlex
import subprocess
import sys
import yaml

ROOT = pathlib.Path(__file__).resolve().parents[1]
CORE = ("prometheus", "mimir", "loki", "tempo", "grafana", "otelGateway", "pyroscope")
def load(path):
    with open(path, encoding="utf-8") as f:
        return yaml.safe_load(f)
def run(args, execute=True, quiet=False):
    if not quiet:
        print(shlex.join(args), flush=True)
    if execute:
        subprocess.run(args, check=True)
def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--config", default="lab-config.yaml")
    p.add_argument("--releases", default="releases.yaml")
    p.add_argument("--apply", action="store_true", help="Actually install/upgrade releases")
    p.add_argument("--allow-upgrade", action="store_true", help="Permit changes to existing releases")
    args = p.parse_args()
    config = load(args.config)
    catalog = load(args.releases)["releases"]
    context = config["cluster"]["context"]
    if not isinstance(context, str) or not context or context.startswith("-"):
        raise ValueError("Invalid Kubernetes context")
    for key, value in config["integrations"].items():
        if value["enabled"]:
            raise ValueError(f"{key}: cloud integration installation is not implemented")
    components = config["components"]
    enabled = {k for k in CORE if components[k]["enabled"]}
    deferred = [k for k in ("astronomyShop", "fleetamp", "headlamp") if components[k]["enabled"]]
    if deferred:
        print("Not installed by core installer: " + ", ".join(deferred))
    selected = []
    errors = []
    seen = set()
    names = set()
    repos = {}
    for entry in catalog:
        component = entry["component"]
        if component not in enabled:
            continue
        if component in seen:
            errors.append(f"Duplicate component: {component}")
        seen.add(component)
        name = entry["name"]
        if not re.fullmatch(r"[a-z0-9][a-z0-9-]{0,52}", name) or name in names:
            errors.append(f"Invalid or duplicate release name: {name}")
        names.add(name)
        version = entry["version"]
        if not isinstance(version, str) or not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+(?:[-+][A-Za-z0-9.+-]+)?", version):
            errors.append(f"{component}: exact chart version required")
        path = (ROOT / entry["values"]).resolve()
        if not path.is_relative_to(ROOT) or not path.is_file():
            errors.append(f"{component}: missing repository values file {entry['values']}")
        repo = entry["repository"]
        alias, url = repo["name"], repo["url"]
        if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_-]*", alias) or not url.startswith("https://"):
            errors.append(f"{component}: invalid chart repository")
        if alias in repos and repos[alias] != url:
            errors.append(f"Conflicting repository alias: {alias}")
        repos[alias] = url
        if not entry["chart"].startswith(alias + "/") or entry["chart"].startswith("-"):
            errors.append(f"{component}: chart must use its repository alias")
        selected.append((entry, path))
    if enabled - seen:
        errors.append("Missing releases: " + ", ".join(sorted(enabled - seen)))
    selected.sort(key=lambda item: CORE.index(item[0]["component"]))
    print(f"Target: {context}, namespace: observability, mode: {'APPLY' if args.apply else 'PLAN'}")
    for entry, path in selected:
        print(f"  {entry['component']}: {entry['chart']} {entry['version'] or '(version required)'} -> {path}")
    if errors:
        raise ValueError("\n".join(errors))
    if not selected:
        print("No core components enabled.")
        return
    helm = ["helm", "--kube-context", context]
    kube = ["kubectl", "--context", context]
    commands = []
    for entry, path in selected:
        commands.append(helm + ["upgrade", "--install", entry["name"], entry["chart"],
            "--version", entry["version"], "--namespace", "observability",
            "--create-namespace", "--values", str(path), "--wait", "--timeout", "15m"])
    if not args.apply:
        for cmd in commands:
            run(cmd, execute=False)
        print("Plan only; no cluster or Helm repository changes.")
        return
    run(["bash", str(ROOT / "scripts/lab-foundation.sh"), "preflight", args.config])
    # Existing releases are protected by default, including failed releases.
    existing = subprocess.check_output(helm + ["list", "-n", "observability", "--all", "-q"], text=True).splitlines()
    conflicts = names.intersection(existing)
    if conflicts and not args.allow_upgrade:
        raise ValueError("Existing releases require --allow-upgrade: " + ", ".join(sorted(conflicts)))
    for alias, url in repos.items():
        run(["helm", "repo", "add", alias, url])
    run(["helm", "repo", "update"])
    # Render every chart before making any Kubernetes release changes.
    # Suppress rendered manifests: they may contain sensitive values.
    for entry, path in selected:
        cmd = helm + ["template", entry["name"], entry["chart"], "--version", entry["version"],
                      "--namespace", "observability", "--values", str(path)]
        print("Rendering " + entry["name"], flush=True)
        subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL)
    for cmd in commands:
        run(cmd)
    print("Core releases applied. Verify PVCs, data sources and actual telemetry separately.")
if __name__ == "__main__":
    try:
        main()
    except (ValueError, KeyError, OSError, subprocess.CalledProcessError, yaml.YAMLError) as exc:
        print(f"Installation stopped: {exc}", file=sys.stderr)
        sys.exit(1)
