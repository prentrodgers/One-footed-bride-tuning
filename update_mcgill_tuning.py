#!/usr/bin/env python3
"""Update McGill.dat cent adjustment values from sample_tuning_report.csv."""

import argparse
import csv
import os
import shutil
import sys


def format_cent(v: int) -> str:
    """Left-justified in 3 chars. Zero has no sign."""
    s = "0" if v == 0 else f"{v:+d}"
    return f"{s:<3}"


def load_csv(csv_path: str, max_cents: int) -> dict:
    """Load CSV into {basename: rounded_cent} dict, skipping outliers."""
    mapping = {}
    skipped = []
    with open(csv_path, newline="") as f:
        reader = csv.DictReader(f)
        for row in reader:
            basename = row["file"].strip()
            offset = float(row["cent_offset"])
            if abs(offset) > max_cents:
                skipped.append((basename, offset))
                print(f"  WARNING: skipping {basename}  offset={offset:+.2f}c (>{max_cents}c)")
                continue
            mapping[basename] = round(offset)
    if skipped:
        print(f"  Skipped {len(skipped)} entries exceeding ±{max_cents} cents.\n")
    return mapping


def process(csv_path: str, mcgill_path: str, output_path: str,
            max_cents: int, dry_run: bool) -> None:
    mapping = load_csv(csv_path, max_cents)
    print(f"Loaded {len(mapping)} entries from {csv_path}\n")

    with open(mcgill_path, "rb") as f:
        raw = f.read()

    # Detect line ending style
    if b"\r\n" in raw:
        line_ending = "\r\n"
    else:
        line_ending = "\n"

    lines = raw.decode("latin-1").splitlines(keepends=True)

    updated = 0
    unchanged = 0
    output_lines = []

    for line in lines:
        stripped = line.rstrip("\r\n")

        # Pass through comment lines and short lines unchanged
        if stripped.startswith(";") or len(stripped) < 23:
            output_lines.append(line)
            unchanged += 1
            continue

        # Extract basename from path at position 22+
        path_part = stripped[22:]
        basename = os.path.basename(path_part.strip())

        if basename in mapping:
            new_cent = mapping[basename]
            old_cent_str = stripped[18:21]
            new_cent_str = format_cent(new_cent)
            new_stripped = stripped[:18] + new_cent_str + stripped[21:]
            # Preserve original line ending
            ending = line[len(stripped):]
            new_line = new_stripped + ending
            output_lines.append(new_line)
            print(f"  UPDATED: {basename:<40}  old={old_cent_str!r}  new={new_cent_str!r}")
            updated += 1
        else:
            output_lines.append(line)
            unchanged += 1

    print(f"\nSummary: {updated} updated, {unchanged} unchanged")

    if dry_run:
        print("\n[dry-run] No files written.")
        return

    # Backup original
    bak_path = mcgill_path + ".bak"
    shutil.copy2(mcgill_path, bak_path)
    print(f"Backup written to {bak_path}")

    with open(output_path, "wb") as f:
        f.write("".join(output_lines).encode("latin-1"))
    print(f"Output written to {output_path}")


def main():
    parser = argparse.ArgumentParser(
        description="Update McGill.dat cent adjustment values from tuning CSV."
    )
    parser.add_argument("--csv", default="sample_tuning_report.csv",
                        help="Input CSV (default: sample_tuning_report.csv)")
    parser.add_argument("--mcgill", default="McGill.dat",
                        help="Input McGill.dat (default: McGill.dat)")
    parser.add_argument("--output", default=None,
                        help="Output path (default: overwrite --mcgill after backup)")
    parser.add_argument("--max-cents", type=int, default=50,
                        help="Skip measurements beyond this value (default: 50)")
    parser.add_argument("--dry-run", action="store_true",
                        help="Print changes without writing")
    args = parser.parse_args()

    output_path = args.output if args.output else args.mcgill

    process(
        csv_path=args.csv,
        mcgill_path=args.mcgill,
        output_path=output_path,
        max_cents=args.max_cents,
        dry_run=args.dry_run,
    )


if __name__ == "__main__":
    main()
