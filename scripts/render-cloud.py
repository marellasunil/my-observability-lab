#!/usr/bin/env python3
"""Generate a cloud-enabled gateway config locally; never apply automatically."""
import argparse
import pathlib
import yaml
p=argparse.ArgumentParser()
p.add_argument("--grafana",action="store_true")
p.add_argument("--splunk",action="store_true")
p.add_argument("--output",required=True)
a=p.parse_args()
root=pathlib.Path(__file__).resolve().parents[1]
d=yaml.safe_load((root/"observability/otel/gateway/config.yaml").read_text())
if a.grafana:
 d.setdefault("extensions",{})["basicauth/grafana_cloud"]={"client_auth":{"username":"${env:GRAFANA_CLOUD_INSTANCE}","password":"${env:GRAFANA_CLOUD_TOKEN}"}}
 d["service"].setdefault("extensions",[]).append("basicauth/grafana_cloud")
 d["exporters"]["otlphttp/grafana_cloud"]={"endpoint":"${env:GRAFANA_CLOUD_OTLP_ENDPOINT}","auth":{"authenticator":"basicauth/grafana_cloud"},"timeout":"10s"}
if a.splunk:
 d["exporters"]["otlphttp/splunk_o11y"]={"metrics_endpoint":"${env:SPLUNK_METRICS_ENDPOINT}","traces_endpoint":"${env:SPLUNK_TRACES_ENDPOINT}","headers":{"X-SF-Token":"${env:SPLUNK_ACCESS_TOKEN}"},"timeout":"10s"}
if a.grafana or a.splunk:
 d["processors"].update({"probabilistic_sampler/demo_cloud":{"sampling_percentage":10},"filter/demo_cloud_logs":{"error_mode":"ignore","logs":{"log_record":["severity_number < SEVERITY_NUMBER_WARN"]}},"filter/demo_cloud_metrics":{"error_mode":"ignore","metrics":{"metric":['not IsMatch(name, "^(http[._].*|rpc[._].*|traces[._]span[._]metrics[._].*|gen_ai[._].*)$")']}}})
 for signal,proc in [("metrics","filter/demo_cloud_metrics"),("logs","filter/demo_cloud_logs"),("traces","probabilistic_sampler/demo_cloud")]:
  exports=(["otlphttp/grafana_cloud"] if a.grafana else [])+(["otlphttp/splunk_o11y"] if a.splunk and signal!="logs" else [])
  if not exports: continue
  connector="forward/demo_"+signal+"_cloud"
  d.setdefault("connectors",{})[connector]={}
  d["service"]["pipelines"][signal+"/demo"]["exporters"].append(connector)
  d["service"]["pipelines"][signal+"/demo_cloud"]={"receivers":[connector],"processors":["memory_limiter",proc,"batch"],"exporters":exports}
with open(a.output,"x") as f: yaml.safe_dump(d,f,sort_keys=False)

