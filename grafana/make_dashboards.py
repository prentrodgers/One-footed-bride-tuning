#!/usr/bin/env python3
"""Write k8s-grafana-dashboards.yaml: two Grafana dashboards, as ConfigMaps the
kube-prometheus-stack sidecar loads (label grafana_dashboard=1), for the
tuning jobs (grid-search-*) and the render farm (blender-farm-* pods).

    python grafana/make_dashboards.py && kubectl apply -f k8s-grafana-dashboards.yaml

Everything comes from kube-state-metrics, cAdvisor and node-exporter, which
this Prometheus already scrapes; there are no GPU metrics on the cluster, so
GPU load is inferred from the pods' CPU and the nodes' temperatures.
"""
import json

DS = {"type": "prometheus", "uid": "prometheus"}
FLEET = 'nodename=~"fs[0-9]"'
TUNE_POD = 'namespace="default",pod=~"grid-search-[0-9].*"'
TUNE_JOB = 'namespace="default",job_name=~"grid-search-[0-9].*"'
FARM_POD = 'namespace="default",pod=~"blender-farm-.*"'

_id = [0]
def panel(kind, title, targets, x, y, w, h, unit=None, extra=None, legend="bottom"):
    _id[0] += 1
    p = {"id": _id[0], "type": kind, "title": title, "datasource": DS,
         "gridPos": {"x": x, "y": y, "w": w, "h": h},
         "targets": [{"refId": chr(65 + i), "datasource": DS, "expr": e, "legendFormat": l}
                     for i, (e, l) in enumerate(targets)],
         "fieldConfig": {"defaults": {}, "overrides": []},
         "options": {}}
    if unit:
        p["fieldConfig"]["defaults"]["unit"] = unit
    if kind == "timeseries":
        p["options"] = {"legend": {"displayMode": "list", "placement": legend, "showLegend": True},
                        "tooltip": {"mode": "multi", "sort": "desc"}}
        p["fieldConfig"]["defaults"]["custom"] = {"lineWidth": 1, "fillOpacity": 12, "showPoints": "never"}
    if kind == "stat":
        p["options"] = {"reduceOptions": {"calcs": ["lastNotNull"], "fields": "", "values": False},
                        "colorMode": "value", "graphMode": "area", "textMode": "value_and_name"}
    if extra:
        for k, v in extra.items():
            if isinstance(v, dict) and isinstance(p.get(k), dict):
                p[k].update(v)
            else:
                p[k] = v
    return p

def node_panels(y):
    """The fleet's CPU load and temperatures — shared by both dashboards."""
    uname = f'* on(instance) group_left(nodename) node_uname_info{{{FLEET}}}'
    return [
        panel("timeseries", "Node CPU utilisation (fleet)",
              [(f'100 * (1 - avg by (nodename) (rate(node_cpu_seconds_total{{mode="idle"}}[2m]) {uname}))',
                "{{nodename}}")], 0, y, 12, 8, unit="percent",
              extra={"fieldConfig": {"defaults": {"min": 0, "max": 100}}}),
        panel("timeseries", "CPU package temperature (fleet)",
              [(f'max by (nodename) ((node_hwmon_temp_celsius * on(chip,sensor,instance) group_left(label) '
                f'node_hwmon_sensor_label{{label=~"Package id 0|Tctl"}}) {uname})', "{{nodename}}")],
              12, y, 12, 8, unit="celsius",
              extra={"fieldConfig": {"defaults": {"min": 20, "max": 100,
                     "thresholds": {"mode": "absolute", "steps": [{"color": "green", "value": None},
                                                                  {"color": "orange", "value": 75},
                                                                  {"color": "red", "value": 85}]},
                     "custom": {"thresholdsStyle": {"mode": "line"}}}}}),
    ]

def dashboard(uid, title, panels, tags):
    return {"uid": uid, "title": title, "tags": tags, "timezone": "browser", "editable": True,
            "schemaVersion": 39, "version": 1, "refresh": "30s",
            "time": {"from": "now-6h", "to": "now"}, "panels": panels,
            "templating": {"list": []}, "annotations": {"list": []}}

# ── Tuning jobs ─────────────────────────────────────────────────────────────
t = []
t += [panel("stat", "Jobs", [(f'count(kube_job_info{{{TUNE_JOB}}})', "total")], 0, 0, 4, 4),
      panel("stat", "Active", [(f'sum(kube_job_status_active{{{TUNE_JOB}}})', "active")], 4, 0, 4, 4),
      panel("stat", "Succeeded", [(f'sum(kube_job_status_succeeded{{{TUNE_JOB}}})', "done")], 8, 0, 4, 4,
            extra={"fieldConfig": {"defaults": {"color": {"mode": "fixed", "fixedColor": "green"}}}}),
      panel("stat", "Failed", [(f'sum(kube_job_status_failed{{{TUNE_JOB}}})', "failed")], 12, 0, 4, 4,
            extra={"fieldConfig": {"defaults": {"color": {"mode": "fixed", "fixedColor": "red"}}}}),
      panel("stat", "Progress", [(f'100 * sum(kube_job_status_succeeded{{{TUNE_JOB}}}) / count(kube_job_info{{{TUNE_JOB}}})', "done")],
            16, 0, 4, 4, unit="percent", extra={"options": {"graphMode": "none"}}),
      panel("stat", "Avg job duration",
            [(f'avg(kube_job_status_completion_time{{{TUNE_JOB}}} - on(job_name) kube_job_status_start_time{{{TUNE_JOB}}})', "avg")],
            20, 0, 4, 4, unit="s", extra={"options": {"graphMode": "none"}})]
t += [panel("timeseries", "Tuning pods by phase",
            [(f'sum by (phase) (kube_pod_status_phase{{{TUNE_POD}}})', "{{phase}}")], 0, 4, 12, 8,
            extra={"fieldConfig": {"defaults": {"custom": {"stacking": {"mode": "normal"}, "fillOpacity": 40}}}}),
      panel("timeseries", "Jobs completed (cumulative) and active",
            [(f'sum(kube_job_status_succeeded{{{TUNE_JOB}}})', "succeeded"),
             (f'sum(kube_job_status_active{{{TUNE_JOB}}})', "active"),
             (f'sum(kube_job_status_failed{{{TUNE_JOB}}})', "failed")], 12, 4, 12, 8)]
t += [panel("timeseries", "Running tuning pods per node",
            [(f'sum by (node) (kube_pod_info{{{TUNE_POD}}} * on(namespace,pod) group_left() '
              f'kube_pod_status_phase{{{TUNE_POD},phase="Running"}})', "{{node}}")], 0, 12, 12, 8,
            extra={"fieldConfig": {"defaults": {"custom": {"stacking": {"mode": "normal"}, "fillOpacity": 40}}}}),
      panel("timeseries", "CPU cores used by tuning pods, per node",
            [(f'sum by (node) (rate(container_cpu_usage_seconds_total{{{TUNE_POD},container="grid-search"}}[2m]))',
              "{{node}}")], 12, 12, 12, 8, unit="short")]
t += node_panels(20)
t += [panel("timeseries", "Job duration by completion time",
            [(f'(kube_job_status_completion_time{{{TUNE_JOB}}} - on(job_name) kube_job_status_start_time{{{TUNE_JOB}}})',
              "{{job_name}}")], 0, 28, 24, 8, unit="s", legend="hidden",
            extra={"fieldConfig": {"defaults": {"custom": {"drawStyle": "points", "showPoints": "always", "pointSize": 4}}}})]
tuning = dashboard("ofb-tuning", "One-footed bride: tuning jobs", t, ["one-footed-bride", "tuning"])

# ── Render farm ─────────────────────────────────────────────────────────────
_id[0] = 100
r = []
r += [panel("stat", "Render pods", [(f'count(kube_pod_info{{{FARM_POD}}})', "pods")], 0, 0, 4, 4),
      panel("stat", "Running", [(f'sum(kube_pod_status_phase{{{FARM_POD},phase="Running"}})', "running")], 4, 0, 4, 4),
      panel("stat", "Completed", [(f'sum(kube_pod_status_phase{{{FARM_POD},phase="Succeeded"}})', "done")], 8, 0, 4, 4,
            extra={"fieldConfig": {"defaults": {"color": {"mode": "fixed", "fixedColor": "green"}}}}),
      panel("stat", "Failed", [(f'sum(kube_pod_status_phase{{{FARM_POD},phase="Failed"}})', "failed")], 12, 0, 4, 4,
            extra={"fieldConfig": {"defaults": {"color": {"mode": "fixed", "fixedColor": "red"}}}}),
      panel("stat", "Longest running pod", [(f'max(time() - kube_pod_start_time{{{FARM_POD}}} * on(namespace,pod) group_left() '
                                           f'kube_pod_status_phase{{{FARM_POD},phase="Running"}})', "elapsed")],
            16, 0, 8, 4, unit="s", extra={"options": {"graphMode": "none"}})]
r += [panel("timeseries", "Render pods by phase",
            [(f'sum by (phase) (kube_pod_status_phase{{{FARM_POD}}})', "{{phase}}")], 0, 4, 12, 8,
            extra={"fieldConfig": {"defaults": {"custom": {"stacking": {"mode": "normal"}, "fillOpacity": 40}}}}),
      panel("timeseries", "Elapsed time per running pod",
            [(f'(time() - kube_pod_start_time{{{FARM_POD}}}) * on(namespace,pod) group_left() '
              f'kube_pod_status_phase{{{FARM_POD},phase="Running"}}', "{{pod}}")], 12, 4, 12, 8, unit="s")]
r += [panel("timeseries", "CPU cores per render pod (the per-frame Python)",
            [(f'sum by (pod) (rate(container_cpu_usage_seconds_total{{{FARM_POD},container="blender"}}[2m]))', "{{pod}}")],
            0, 12, 12, 8, unit="short"),
      panel("timeseries", "Memory per render pod",
            [(f'sum by (pod) (container_memory_working_set_bytes{{{FARM_POD},container="blender"}})', "{{pod}}")],
            12, 12, 12, 8, unit="bytes")]
r += node_panels(20)
r += [panel("text", "Frame progress", [], 0, 28, 24, 4,
            extra={"options": {"mode": "markdown", "content":
                   "Frames are files on the PVC, not metrics. For per-slice progress and ETA run "
                   "`./render_farm.sh --progress` on fs2; `./render_farm.sh --status` lists the pods. "
                   "A pod that completes leaves the **Running** band above; the render is done when "
                   "**Completed** equals **Render pods**, and the farm's waiter then returns the fleet to balanced."}})]
render = dashboard("ofb-render", "One-footed bride: render farm", r, ["one-footed-bride", "render"])

def cm(name, key, dash):
    body = json.dumps(dash, indent=1)
    return (f"apiVersion: v1\nkind: ConfigMap\nmetadata:\n  name: {name}\n  namespace: prometheus\n"
            f"  labels:\n    grafana_dashboard: \"1\"\n    app: one-footed-bride\ndata:\n  {key}: |\n"
            + "".join("    " + line + "\n" for line in body.splitlines()))

out = ("# Generated by grafana/make_dashboards.py — edit that, not this.\n"
       + cm("ofb-tuning-dashboard", "ofb-tuning.json", tuning) + "---\n"
       + cm("ofb-render-dashboard", "ofb-render.json", render))
open("k8s-grafana-dashboards.yaml", "w").write(out)
print("wrote k8s-grafana-dashboards.yaml:", len(t), "tuning panels,", len(r), "render panels")
