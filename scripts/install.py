#!/usr/bin/env python3
"""Plan-first installer for the reference lab. Python 3.9+."""
import argparse
import pathlib
import re
import shlex
import subprocess
import sys
import tempfile
import yaml

ROOT = pathlib.Path(__file__).resolve().parents[1]
ORDER = ("prometheus","mimir","loki","tempo","grafana","otelGateway","pyroscope","astronomyShop")
DEPS = {"grafana": {"prometheus","mimir","loki","tempo"}, "otelGateway": {"prometheus","mimir","loki","tempo"}, "pyroscope":{"prometheus"}, "astronomyShop":{"otelGateway"}}
def load(p):
    return yaml.safe_load(pathlib.Path(p).read_text())
def run(cmd, **kw):
    print(shlex.join(cmd), flush=True)
    return subprocess.run(cmd, check=True, **kw)
def safe_path(p):
    path = (ROOT / p).resolve()
    if not path.is_relative_to(ROOT) or not path.exists():
        raise ValueError("Invalid repository path: "+p)
    return path
def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--config",default="lab-config.yaml")
    p.add_argument("--releases",default="releases.yaml")
    p.add_argument("--apply",action="store_true")
    p.add_argument("--allow-upgrade",action="store_true")
    a=p.parse_args()
    c=load(a.config); context=c["cluster"]["context"]; storage=c["storage"]["className"]
    if not all(isinstance(x,str) and re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.-]*",x) for x in (context,storage)):
        raise ValueError("Invalid context or storage class")
    if any(v["enabled"] for v in c["integrations"].values()):
        raise ValueError("Cloud integration automation is not implemented")
    enabled={k for k in ORDER if c["components"][k]["enabled"]}
    for k in enabled:
        if DEPS.get(k,set())-enabled:
            raise ValueError(k+" requires "+", ".join(sorted(DEPS[k]-enabled)))
    for k in ("fleetamp","headlamp"):
        if c["components"][k]["enabled"]: raise ValueError(k+" installation is not implemented")
    if "astronomyShop" in enabled and c["demo"]["loadGenerator"] != {"enabled":True,"users":1,"autoStart":False}:
        raise ValueError("Only reference load-generator settings are supported")
    entries=[e for e in load(a.releases)["releases"] if e["component"] in enabled]
    if len(entries)!=len(enabled) or {e["component"] for e in entries}!=enabled:
        raise ValueError("Missing or duplicate catalog entries")
    entries.sort(key=lambda e:ORDER.index(e["component"]))
    k=["kubectl","--context",context]; h=["helm","--kube-context",context]
    print("Target:",context,"mode:", "APPLY" if a.apply else "PLAN")
    with tempfile.TemporaryDirectory(prefix="observability-install-") as tmp:
        tmp=pathlib.Path(tmp); plans=[]; repos={}
        for e in entries:
            comp=e["component"]; name=e["name"]; ns=e.get("namespace","observability")
            if not re.fullmatch(r"[a-z0-9][a-z0-9-]{0,52}",name) or ns not in ("observability","otel-demo"):
                raise ValueError("Invalid release name or namespace")
            if e.get("kind")=="kustomize":
                path=safe_path(e["path"])
                rendered=subprocess.check_output(k+["kustomize",str(path)],text=True)
                docs=list(yaml.safe_load_all(rendered))
                for obj in docs:
                    if obj and obj["kind"]=="PersistentVolumeClaim": obj["spec"]["storageClassName"]=storage
                out=tmp/(name+".yaml"); out.write_text(yaml.safe_dump_all(docs))
                plans.append((e,k+["apply","-f",str(out)],None,out))
            else:
                v=e["version"]; repo=e["repository"]; alias=repo["name"]; url=repo["url"]
                if not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+(?:[-+][A-Za-z0-9.+-]+)?",v) or not url.startswith("https://") or not e["chart"].startswith(alias+"/"):
                    raise ValueError("Invalid chart pin or repository")
                if alias in repos and repos[alias]!=url: raise ValueError("Conflicting repository")
                repos[alias]=url
                values=load(safe_path(e["values"]))
                def replace(x):
                    if isinstance(x,dict):
                        for key,val in x.items():
                            if key in ("storageClass","storageClassName"): x[key]=storage
                            else: replace(val)
                    elif isinstance(x,list):
                        for val in x: replace(val)
                replace(values)
                out=tmp/(name+".values.yaml"); out.write_text(yaml.safe_dump(values))
                base=[name,e["chart"],"--version",v,"--namespace",ns,"--values",str(out)]
                plans.append((e,h+["upgrade","--install"]+base+["--create-namespace","--wait","--timeout","15m"],h+["template"]+base,None))
        for e,cmd,render,raw in plans: print(e["component"],shlex.join(cmd))
        if not a.apply:
            print("Plan only; temporary rendered files removed on exit."); return
        run(["bash",str(ROOT/"scripts/lab-foundation.sh"),"preflight",a.config])
        # Refuse existing resources by default; namespace absence is normal.
        namespaces=set(subprocess.check_output(k+["get","namespace","-o","jsonpath={.items[*].metadata.name}"],text=True).split())
        for e,cmd,render,raw in plans:
            ns=e.get("namespace","observability")
            if ns not in namespaces: continue
            if raw:
                existing=subprocess.check_output(k+["get","-f",str(raw),"--ignore-not-found","-o","name"],text=True).strip()
            else:
                existing=e["name"] in subprocess.check_output(h+["list","-n",ns,"--all","-q"],text=True).splitlines()
            if existing and not a.allow_upgrade: raise ValueError("Existing resources: "+e["name"]+"; use --allow-upgrade only after review")
        for alias,url in repos.items(): run(["helm","repo","add",alias,url])
        if repos: run(["helm","repo","update"])
        for e,cmd,render,raw in plans:
            if render: run(render,stdout=subprocess.DEVNULL)
        if "observability" not in namespaces: run(k+["create","namespace","observability"])
        for e,cmd,render,raw in plans:
            run(cmd)
            if raw: run(k+["-n","observability","rollout","status","deployment/"+e["name"],"--timeout=300s"])
        print("Installed; verify telemetry and PVCs separately.")
if __name__=="__main__":
    try: main()
    except (ValueError,KeyError,OSError,subprocess.CalledProcessError,yaml.YAMLError) as exc:
        print("Installation stopped:",exc,file=sys.stderr); sys.exit(1)
