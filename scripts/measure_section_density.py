#!/usr/bin/env python3
"""Measure section density from Csound score lines.

Parses score lines that begin with "i" and computes per-section statistics for a
user-defined expression over note fields. This lets you validate relationships
like finger_pianos being 2x marimbas and marimbas being 2x pizz_strings.

Examples:
  python scripts/measure_section_density.py --csd new_output.csd
  python scripts/measure_section_density.py --csd new_output.csd --expr "hold * vol"
  python scripts/measure_section_density.py --csd new_output.csd --bin-seconds 10
"""

from __future__ import annotations

import argparse
import ast
import math
import re
import statistics
from dataclasses import dataclass
from pathlib import Path


SECTION_SETS = {
    "percussive": ("finger_pianos", "marimbas", "pizz_strings"),
    "sustained": ("wood_winds", "bowed_strings", "brass_section", "melody_section"),
    "all": (
        "finger_pianos",
        "marimbas",
        "pizz_strings",
        "wood_winds",
        "bowed_strings",
        "brass_section",
        "melody_section",
    ),
}

SECTION_TO_NPY = {
    "finger_pianos": "perc_part_finger_pianos.npy",
    "marimbas": "perc_part_marimbas.npy",
    "pizz_strings": "perc_part_pizz_strings.npy",
    "wood_winds": "winds_part_wood_winds.npy",
    "bowed_strings": "winds_part_bowed_strings.npy",
    "brass_section": "winds_part_brass_section.npy",
    "melody_section": "melody_part_melody_section.npy",
    "bass_section": "bass_part_bass_section.npy",
}


@dataclass
class ScoreRow:
    inst: int
    start: float
    hold: float
    vel: float
    ton: float
    octv: float
    voi: float
    ste: float
    en1: float
    gls: float
    ups: float
    ren: float
    gl2: float
    gl3: float
    vol: float


ALLOWED_NAMES = {
    "inst",
    "start",
    "hold",
    "vel",
    "vel_clamped",
    "ton",
    "octv",
    "voi",
    "ste",
    "en1",
    "gls",
    "ups",
    "ren",
    "gl2",
    "gl3",
    "vol",
    "audible",
    "audible_amp",
    "math",
}

ALLOWED_FUNCS = {
    "abs",
    "min",
    "max",
    "round",
}


class ExprValidator(ast.NodeVisitor):
    def visit_Name(self, node: ast.Name) -> None:
        if node.id not in ALLOWED_NAMES and node.id not in ALLOWED_FUNCS:
            raise ValueError(f"Unsupported name in expression: {node.id}")

    def visit_Call(self, node: ast.Call) -> None:
        if isinstance(node.func, ast.Name):
            if node.func.id not in ALLOWED_FUNCS:
                raise ValueError(f"Unsupported function: {node.func.id}")
        elif isinstance(node.func, ast.Attribute):
            if not (isinstance(node.func.value, ast.Name) and node.func.value.id == "math"):
                raise ValueError("Only math.<fn> attribute calls are allowed")
        else:
            raise ValueError("Unsupported call syntax")
        self.generic_visit(node)

    def generic_visit(self, node: ast.AST) -> None:
        allowed_nodes = (
            ast.Expression,
            ast.BinOp,
            ast.UnaryOp,
            ast.Add,
            ast.Sub,
            ast.Mult,
            ast.Div,
            ast.FloorDiv,
            ast.Mod,
            ast.Pow,
            ast.USub,
            ast.UAdd,
            ast.Constant,
            ast.Name,
            ast.Load,
            ast.Call,
            ast.Attribute,
        )
        if not isinstance(node, allowed_nodes):
            raise ValueError(f"Unsupported syntax in expression: {type(node).__name__}")
        super().generic_visit(node)


def parse_score_line(line: str) -> ScoreRow | None:
    parts = line.strip().split()
    if len(parts) < 16 or parts[0] != "i":
        return None
    try:
        vals = [float(x) for x in parts[1:16]]
    except ValueError:
        return None
    return ScoreRow(
        inst=int(round(vals[0])),
        start=vals[1],
        hold=vals[2],
        vel=vals[3],
        ton=vals[4],
        octv=vals[5],
        voi=vals[6],
        ste=vals[7],
        en1=vals[8],
        gls=vals[9],
        ups=vals[10],
        ren=vals[11],
        gl2=vals[12],
        gl3=vals[13],
        vol=vals[14],
    )


def safe_compile_expr(expr: str):
    tree = ast.parse(expr, mode="eval")
    ExprValidator().visit(tree)
    return compile(tree, "<expr>", "eval")


def eval_expr(code_obj, row: ScoreRow) -> float:
    vel_clamped = min(90.0, max(50.0, row.vel))
    audible = 1.0 if row.vol > 0 else 0.0
    # Csound path in ball9.csd:
    # iVelTemp = clamp(p4, <= 90)
    # iVel = clamp(iVelTemp, >= 50)
    # iamp = ampdb(iVel) * p15 / 5
    # The constant scale factor inside ampdb does not matter for section ratios.
    audible_amp = math.pow(10.0, vel_clamped / 20.0) * row.vol / 5.0
    scope = {
        "inst": row.inst,
        "start": row.start,
        "hold": row.hold,
        "vel": row.vel,
        "vel_clamped": vel_clamped,
        "ton": row.ton,
        "octv": row.octv,
        "voi": row.voi,
        "ste": row.ste,
        "en1": row.en1,
        "gls": row.gls,
        "ups": row.ups,
        "ren": row.ren,
        "gl2": row.gl2,
        "gl3": row.gl3,
        "vol": row.vol,
        "audible": audible,
        "audible_amp": audible_amp,
        "math": math,
        "abs": abs,
        "min": min,
        "max": max,
        "round": round,
    }
    value = eval(code_obj, {"__builtins__": {}}, scope)
    return float(value)


def stats(values: list[float]) -> dict[str, float]:
    if not values:
        return {"count": 0.0, "min": 0.0, "max": 0.0, "mean": 0.0, "sum": 0.0}
    return {
        "count": float(len(values)),
        "min": float(min(values)),
        "max": float(max(values)),
        "mean": float(statistics.fmean(values)),
        "sum": float(sum(values)),
    }


def build_bin_series(rows: list[tuple[ScoreRow, float]], bin_seconds: float) -> list[float]:
    if not rows:
        return []
    max_t = max(r.start for r, _ in rows)
    nbins = int(math.floor(max_t / bin_seconds)) + 1
    bins = [0.0] * nbins
    for r, value in rows:
        idx = int(math.floor(r.start / bin_seconds))
        bins[idx] += value
    return bins


def ratio(a: float, b: float) -> float:
    if b == 0:
        return float("inf")
    return a / b


def load_just_piano_samples_short_names(
    wreckingcrew_path: Path, target_sections: tuple[str, ...]
) -> dict[str, list[str]]:
    text = wreckingcrew_path.read_text(encoding="utf-8")
    marker = "elif just_piano_samples:"
    start = text.find(marker)
    if start == -1:
        raise ValueError("Could not find just_piano_samples block in WreckingCrew.py")
    end = text.find("\n      else:", start)
    if end == -1:
        raise ValueError("Could not find end of just_piano_samples block in WreckingCrew.py")
    block = text[start:end]

    result: dict[str, list[str]] = {}
    for section in target_sections:
        pattern = rf"'{section}':\s*\[True,\s*np\.array\(\[(.*?)\]\)\]"
        match = re.search(pattern, block, flags=re.S)
        if not match:
            raise ValueError(f"Could not find section {section} in just_piano_samples block")
        names = re.findall(r"'([^']+)'", match.group(1))
        result[section] = names
    return result


def load_csound_voice_map(adaptive_path: Path, short_names: set[str]) -> dict[str, int]:
    text = adaptive_path.read_text(encoding="utf-8")
    mapping: dict[str, int] = {}
    for short_name in short_names:
        pattern = rf'"{re.escape(short_name)}":\s*\{{[^}}]*?"csound_voice":\s*(\d+)'
        match = re.search(pattern, text, flags=re.S)
        if not match:
            raise ValueError(f"Could not find csound_voice for {short_name} in adaptive_tuning_util.py")
        mapping[short_name] = int(match.group(1))
    return mapping


def build_section_by_inst(
    wreckingcrew_path: Path, adaptive_path: Path, target_sections: tuple[str, ...]
) -> dict[int, str]:
    section_short_names = load_just_piano_samples_short_names(wreckingcrew_path, target_sections)
    all_short_names = {name for names in section_short_names.values() for name in names}
    csound_voice_map = load_csound_voice_map(adaptive_path, all_short_names)

    section_by_inst: dict[int, str] = {}
    collisions: dict[int, set[str]] = {}
    for section, names in section_short_names.items():
        for name in names:
            voice = csound_voice_map[name]
            collisions.setdefault(voice, set()).add(section)
            section_by_inst[voice] = section

    overlapping = {k: sorted(v) for k, v in collisions.items() if len(v) > 1}
    if overlapping:
        print(
            "Warning: requested sections share Csound voices; CSD-only mapping may be ambiguous. "
            "Use --source npy for exact per-section stats.",
        )
        print(f"Overlapping voices: {overlapping}")
    return section_by_inst


def score_row_from_values(vals: list[float]) -> ScoreRow:
    return ScoreRow(
        inst=int(round(vals[0])),
        start=float(vals[1]),
        hold=float(vals[2]),
        vel=float(vals[3]),
        ton=float(vals[4]),
        octv=float(vals[5]),
        voi=float(vals[6]),
        ste=float(vals[7]),
        en1=float(vals[8]),
        gls=float(vals[9]),
        ups=float(vals[10]),
        ren=float(vals[11]),
        gl2=float(vals[12]),
        gl3=float(vals[13]),
        vol=float(vals[14]),
    )


def can_use_npy(target_sections: tuple[str, ...]) -> bool:
    return all(Path(SECTION_TO_NPY[s]).exists() for s in target_sections if s in SECTION_TO_NPY)


def main() -> None:
    parser = argparse.ArgumentParser(description="Measure section density from CSD score lines")
    parser.add_argument("--csd", default="new_output.csd", help="Path to CSD file (default: new_output.csd)")
    parser.add_argument(
        "--expr",
        default="hold*audible_amp",
        help="Expression per note, e.g. 'hold', 'hold*audible', 'hold*audible_amp', 'audible_amp'",
    )
    parser.add_argument(
        "--bin-seconds",
        type=float,
        default=5.0,
        help="Time bin size in seconds for min/max/avg bin density (default: 5.0)",
    )
    parser.add_argument(
        "--wreckingcrew",
        default="WreckingCrew.py",
        help="Path to WreckingCrew.py for active just_piano_samples section mapping",
    )
    parser.add_argument(
        "--adaptive",
        default="adaptive_tuning_util.py",
        help="Path to adaptive_tuning_util.py for csound_voice lookup",
    )
    parser.add_argument(
        "--section-set",
        choices=tuple(SECTION_SETS.keys()),
        default="percussive",
        help="Preset section group to analyze (default: percussive)",
    )
    parser.add_argument(
        "--sections",
        default="",
        help="Comma-separated sections to analyze; overrides --section-set",
    )
    parser.add_argument(
        "--source",
        choices=("auto", "csd", "npy"),
        default="auto",
        help="Data source for section stats (default: auto)",
    )
    args = parser.parse_args()

    if args.sections.strip():
        target_sections = tuple(s.strip() for s in args.sections.split(",") if s.strip())
        if not target_sections:
            raise SystemExit("No valid sections provided in --sections")
    else:
        target_sections = SECTION_SETS[args.section_set]

    csd_path = Path(args.csd)
    if not csd_path.exists():
        raise SystemExit(f"CSD file not found: {csd_path}")

    wreckingcrew_path = Path(args.wreckingcrew)
    if not wreckingcrew_path.exists():
        raise SystemExit(f"WreckingCrew file not found: {wreckingcrew_path}")

    adaptive_path = Path(args.adaptive)
    if not adaptive_path.exists():
        raise SystemExit(f"adaptive_tuning_util file not found: {adaptive_path}")

    expr_code = safe_compile_expr(args.expr)
    section_by_inst = build_section_by_inst(wreckingcrew_path, adaptive_path, target_sections)

    rows_by_section: dict[str, list[tuple[ScoreRow, float]]] = {s: [] for s in target_sections}

    use_npy = False
    if args.source == "npy":
        use_npy = True
    elif args.source == "auto":
        use_npy = can_use_npy(target_sections)

    if use_npy:
        missing = [s for s in target_sections if s not in SECTION_TO_NPY or not Path(SECTION_TO_NPY[s]).exists()]
        if missing:
            raise SystemExit(
                f"Requested --source npy, but section .npy files are missing for: {missing}"
            )
        for section in target_sections:
            arr = __import__("numpy").load(SECTION_TO_NPY[section])
            for vals in arr:
                row = score_row_from_values(vals[:15].tolist())
                value = eval_expr(expr_code, row)
                rows_by_section[section].append((row, value))
    else:
        with csd_path.open("r", encoding="utf-8", errors="ignore") as f:
            for line in f:
                line = line.strip()
                if not line.startswith("i "):
                    continue
                row = parse_score_line(line)
                if row is None:
                    continue
                section = section_by_inst.get(int(row.voi))
                if section not in rows_by_section:
                    continue
                value = eval_expr(expr_code, row)
                rows_by_section[section].append((row, value))

    print(f"CSD: {csd_path}")
    print(f"Expression: {args.expr}")
    print(f"Bin size: {args.bin_seconds:.3f}s")
    print(f"Sections: {target_sections}")
    print(f"Source: {'npy' if use_npy else 'csd'}")
    print(f"Section voices: {section_by_inst}")
    print()

    means = {}
    sums = {}

    for section in target_sections:
        section_rows = rows_by_section[section]
        values = [v for _, v in section_rows]
        s = stats(values)
        bins = build_bin_series(section_rows, args.bin_seconds)
        bs = stats(bins)

        means[section] = s["mean"]
        sums[section] = s["sum"]

        def fmt(v: float) -> str:
            return f"{v:,.1f}"

        print(f"[{section}]")
        print(
            "note-level: "
            f"count={int(s['count']):,} min={fmt(s['min'])} max={fmt(s['max'])} "
            f"mean={fmt(s['mean'])} sum={fmt(s['sum'])}"
        )
        print(
            "bin-level:  "
            f"bins={int(bs['count']):,} min={fmt(bs['min'])} max={fmt(bs['max'])} "
            f"mean={fmt(bs['mean'])} sum={fmt(bs['sum'])}"
        )
        print()

    print("Ratios")
    base = target_sections[0]
    for section in target_sections[1:]:
        print(f"mean({section}) / mean({base}) = {ratio(means[section], means[base]):.4f}")
    valid_mean = [means[s] for s in target_sections if means[s] > 0]
    valid_sum = [sums[s] for s in target_sections if sums[s] > 0]
    if valid_mean:
        print(f"mean spread (max/min) = {max(valid_mean) / min(valid_mean):.4f}")
    if valid_sum:
        print(f"sum spread  (max/min) = {max(valid_sum) / min(valid_sum):.4f}")


if __name__ == "__main__":
    main()
