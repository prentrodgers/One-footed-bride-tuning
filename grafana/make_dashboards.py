#!/usr/bin/env python3
"""Write k8s-grafana-dashboards.yaml: two Grafana dashboards, as ConfigMaps the
kube-prometheus-stack sidecar loads (label grafana_dashboard=1), for the
tuning runs (ray-ratchet.sh's RayCluster `tuning`) and the render farm
(blender-farm-* pods).

    python grafana/make_dashboards.py && kubectl apply -f k8s-grafana-dashboards.yaml

Everything comes from Ray's own metrics (the ray-tuning PodMonitor),
kube-state-metrics, cAdvisor, node-exporter and the nut-exporter (UPS), which
this Prometheus already scrapes; there are no GPU metrics on the cluster, so
GPU load is inferred from the pods' CPU and the nodes' temperatures.

11 Nov 2026: the tuning dashboard was rebuilt on Ray.  It had counted
Kubernetes Jobs named grid-search-*, which ray-ratchet.sh replaced, so every
panel but the fleet two was empty.  FLEET also matched only fs0-fs9, which
left fs10 and fs11 out of the fleet panels.
"""
import json

DS = {"type": "prometheus", "uid": "prometheus"}
FLEET = 'nodename=~"fs[0-9]+"'
# One tuning pass is a Ray task named ray-<piece>-t<t>_r<ratio>_lm<lm>-p<pass>
# (ray_ratchet.py); the driver's own JobSupervisor tasks are left out.
PASS = 'ray_io_cluster="tuning",Name=~"ray-.+-t[0-9]+_r[0-9.]+_lm[0-9]+-p[0-9]+"'
PIECE = '"piece", "$1", "Name", "ray-(.+)-t[0-9]+_r[0-9.]+_lm[0-9]+-p[0-9]+"'
RAY_POD = 'namespace="default",pod=~"tuning-.*",container=~"ray-worker|ray-head"'
TASK_CPUS = 4                     # ray_ratchet.py --task_cpus default
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
    """The fleet's CPU load, temperatures, power and clocks — shared by both dashboards.
    Two rows of 8: y and y + 8."""
    uname = f'* on(instance) group_left(nodename) node_uname_info{{{FLEET}}}'
    ups_w = ('network_ups_tools_ups_load * on(ups) group_left() network_ups_tools_ups_realpower_nominal / 100')
    busy = '((1 - rate(node_cpu_seconds_total{mode="idle"}[1m])) > bool 0.8)'
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
        # Power: the closet's two UPSs share one 15 A circuit (1,440 W continuous); the
        # cap test of 8 Nov 2026 drew 900 / 951 / 1043 W from them at CAP_W 40 / 50 / 60.
        panel("timeseries", "UPS power (watts)",
              [(f'{ups_w}', "{{ups}}"),
               (f'sum({ups_w.replace("network_ups_tools_ups_load", "network_ups_tools_ups_load{ups=~\"apc-a|apc-b\"}")})',
                "closet (apc-a + apc-b)")], 0, y + 8, 12, 8, unit="watt",
              extra={"fieldConfig": {"defaults": {"min": 0,
                     "thresholds": {"mode": "absolute", "steps": [{"color": "green", "value": None},
                                                                  {"color": "red", "value": 1300}]},
                     "custom": {"thresholdsStyle": {"mode": "line"}}}}}),
        # The clock of the cores that are busy (over 80% in the last minute): what a
        # CAP_W change moves.  The all-core average is diluted by idle cores.
        panel("timeseries", "CPU clock of busy cores",
              [(f'(sum by (instance) (node_cpu_scaling_frequency_hertz * on(instance,cpu) {busy}) '
                f'/ sum by (instance) ({busy})) {uname}', "{{nodename}}")],
              12, y + 8, 12, 8, unit="hertz"),
    ]

def dashboard(uid, title, panels, tags):
    return {"uid": uid, "title": title, "tags": tags, "timezone": "browser", "editable": True,
            "schemaVersion": 39, "version": 1, "refresh": "30s",
            "time": {"from": "now-6h", "to": "now"}, "panels": panels,
            "templating": {"list": []}, "annotations": {"list": []}}

# ── Tuning runs (Ray) ───────────────────────────────────────────────────────
GREEN = {"fieldConfig": {"defaults": {"color": {"mode": "fixed", "fixedColor": "green"}}}}
RED = {"fieldConfig": {"defaults": {"color": {"mode": "fixed", "fixedColor": "red"}}},
       "options": {"graphMode": "none"}}
STACK = {"fieldConfig": {"defaults": {"custom": {"stacking": {"mode": "normal"}, "fillOpacity": 40}}}}
t = []
t += [panel("stat", "Ray workers", [('count(ray_node_cpu_count{ray_io_cluster="tuning",RayNodeType="worker"})', "workers")],
            0, 0, 4, 4, extra={"options": {"graphMode": "none"}}),
      panel("stat", f"Task slots ({TASK_CPUS} CPU each)",
            # per node: a task cannot straddle two workers
            [(f'sum(floor(ray_node_cpu_count{{ray_io_cluster="tuning",RayNodeType="worker"}} / {TASK_CPUS}))', "slots")],
            4, 0, 4, 4, extra={"options": {"graphMode": "none"}}),
      panel("stat", "Passes running", [(f'sum(ray_tasks{{{PASS},State="RUNNING"}})', "running")], 8, 0, 4, 4),
      panel("stat", "Passes waiting", [(f'sum(ray_tasks{{{PASS},State=~"PENDING.*|SUBMITTED.*"}})', "waiting")],
            12, 0, 4, 4),
      panel("stat", "Passes finished", [(f'sum(ray_tasks{{{PASS},State="FINISHED"}})', "finished")], 16, 0, 4, 4,
            extra=GREEN),
      panel("stat", "Passes failed", [(f'sum(ray_tasks{{{PASS},State="FAILED"}}) or vector(0)', "failed")],
            20, 0, 4, 4, extra=RED)]
t += [panel("timeseries", "Passes running, by piece",
            [(f'sum by (piece) (label_replace(ray_tasks{{{PASS},State="RUNNING"}}, {PIECE}))', "{{piece}}")],
            0, 4, 12, 8, extra=STACK),
      panel("timeseries", "Passes finished, by piece (cumulative)",
            [(f'sum by (piece) (label_replace(ray_tasks{{{PASS},State="FINISHED"}}, {PIECE}))', "{{piece}}")],
            12, 4, 12, 8)]
t += [panel("timeseries", "Passes running, by node",
            [(f'sum by (node) (ray_tasks{{{PASS},State="RUNNING"}})', "{{node}}")], 0, 12, 12, 8, extra=STACK),
      panel("timeseries", "CPU cores used by the Ray pods, by node",
            [(f'sum by (node) (rate(container_cpu_usage_seconds_total{{{RAY_POD}}}[2m]))', "{{node}}")],
            12, 12, 12, 8, unit="short")]
t += node_panels(20)
t += [panel("text", "Pass results", [], 0, 36, 24, 3,
            extra={"options": {"mode": "markdown", "content":
                   "GapSum, gaps and chord averages per pass are not metrics: they are in "
                   "`Archive/straw-man/ray-ratchet-<start>.tsv` and the driver's status tables "
                   "(`./ray-ratchet.sh --attach`). Ray's own view: the **Ray: default** dashboard, "
                   "or http://192.168.68.14:30265 while a run is up."}})]
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
r += [panel("text", "Frame progress", [], 0, 36, 24, 4,
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
