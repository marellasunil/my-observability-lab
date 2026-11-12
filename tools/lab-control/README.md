# Portable lab controls

Use explicit context for every command. The original local web dashboard is machine-specific and is not packaged here.

Run `bash tools/lab-control/control.sh CONTEXT status` to list workloads, `stop-load` to stop Locust, `start-load` to restore one replica, `shop` to forward the frontend, or `grafana` to forward Grafana. Port forwards bind loopback and run in the foreground. Stop with Ctrl-C. Full demo replica preservation and web UI portability remain future work.
