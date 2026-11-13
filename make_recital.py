#!/usr/bin/env python3
"""
make_recital.py - one recital video's soundtrack, notes and timeline from several rendered pieces.

    python make_recital.py Uploads/b858pa_werck3_d01_39_t058 Uploads/b858fa_werck3_d01_47_t084 \
        --applause sfx/applause_tepid.mp3 --out Uploads/b858r_recital

writes, beside --out:
  * <out>.mp3          the whole soundtrack: applause as the curtain opens, each piece in turn after a
                       short pause, applause again after the last one;
  * <out>.npy          every piece's notes in one array, timed in seconds from the first piece's start
                       (render at --tempo 60);
  * <out>.recital.json the timeline concert_stage.py and concert_recital.Recital follow: the title on the
                       closed curtain, the curtain, the applause, where each piece starts and ends.

The applause is never under the music: the first piece starts --after-applause seconds after the
applause has ended, and the closing applause starts --before-applause seconds after the last piece's
mp3 (whose end is its reverberation dying away). No applause between pieces.

Then render with BLEND=Alcorcon_Recital.blend (concert_recital.py) and the command this prints; the
mp3, npy and .recital.json must be on the PVC as well (render_farm.sh checks).
"""
import argparse
import json
import os
import re
import subprocess
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
VENUE = "Teatro Buero Vallejo, Alcorcon (Madrid)"


def length(path):
    out = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", path],
                         capture_output=True, text=True, check=True).stdout
    return float(out.strip())


def tempo_of(stem):
    m = re.search(r"_t(\d{2,3})(?=_|$)", os.path.basename(stem))          # the tolerance is the one-digit _t3_
    if not m:
        raise SystemExit(f"no tempo (_tNNN) in {stem!r}; give --tempos")
    return float(m.group(1))


def default_title(stems):
    """The WTC heading for one prelude, one fugue, or the pair (concert_title.heading_for)."""
    import concert_title as ct
    names = [re.match(r"b(\d+)([pf]?)", os.path.basename(s)) for s in stems]
    if all(names) and len({m.group(1) for m in names}) == 1 and {m.group(2) for m in names} == {"p", "f"}:
        head = ct.heading_for(f"bwv{names[0].group(1)}p")
        return head.replace("Prelude No.", "Prelude and Fugue No.")
    if len(stems) == 1 and names[0]:
        return ct.heading_for(f"bwv{names[0].group(1)}{names[0].group(2)}")
    raise SystemExit("give --title: can't name this programme from the file names")


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[1])
    ap.add_argument("pieces", nargs="+", help="Uploads/<piece> stems (an .mp3 and .npy each), in order")
    ap.add_argument("--applause", required=True, help="applause recording (mp3, wav ...)")
    ap.add_argument("--out", required=True, help="output stem, e.g. Uploads/b858r_recital")
    ap.add_argument("--tempos", default=None, help="comma-separated tempos, if not in the names (_t058)")
    ap.add_argument("--title", default=None, help="the title line (default: from the names, for the WTC)")
    ap.add_argument("--venue", default=VENUE)
    ap.add_argument("--title-seconds", type=float, default=5.0, help="title on the closed curtain (default 5)")
    ap.add_argument("--curtain-seconds", type=float, default=4.0, help="the curtain takes this long to part")
    ap.add_argument("--after-applause", type=float, default=1.0,
                    help="silence between the end of the applause and the first note (default 1)")
    ap.add_argument("--gap", type=float, default=2.5, help="silence after each piece's mp3 before the next")
    ap.add_argument("--before-applause", type=float, default=0.5, help="after the last mp3, before the applause")
    ap.add_argument("--applause-gain", type=float, default=0.0, help="dB on the applause (default 0)")
    ap.add_argument("--end-hold", type=float, default=2.0, help="seconds after the closing applause")
    args = ap.parse_args()

    stems = [p[:-4] if p.endswith((".mp3", ".npy")) else p for p in args.pieces]
    tempos = [float(x) for x in args.tempos.split(",")] if args.tempos else [tempo_of(s) for s in stems]
    if len(tempos) != len(stems):
        raise SystemExit("one tempo per piece")
    clap = length(args.applause)

    # the timeline, video seconds
    title_end = args.title_seconds
    a1 = title_end                                           # the curtain parts as the applause starts
    t = a1 + clap + args.after_applause                      # the applause is over before the first note
    pieces = []
    for s in stems:
        n = length(s + ".mp3")
        pieces.append(dict(name=os.path.basename(s), start=round(t, 3), end=round(t + n, 3)))
        t += n + args.gap
    music_start, music_end = pieces[0]["start"], pieces[-1]["end"]
    a2 = music_end + args.before_applause
    end = a2 + clap + args.end_hold
    spec = dict(title=[args.title or default_title(stems), args.venue], title_end=title_end, title_fade=1.0,
                curtain_open=[a1, a1 + args.curtain_seconds],
                curtain_close=[round(a2 + 2.5, 3), round(a2 + 2.5 + args.curtain_seconds + 1.0, 3)],
                applause=[[a1, round(a1 + clap, 3)], [round(a2, 3), round(a2 + clap, 3)]],
                music_start=music_start, music_end=music_end, end=round(end, 3), pieces=pieces,
                sources=dict(pieces=stems, tempos=tempos, applause=args.applause))

    # the notes: each piece's beats to seconds (tempo 60), from the first piece's start
    arrs = []
    for s, tempo, p in zip(stems, tempos, pieces):
        a = np.load(s + ".npy").astype(float).copy()
        k = 60.0 / tempo
        a[:, 1] = a[:, 1] * k + (p["start"] - music_start)
        a[:, 2] = a[:, 2] * k
        arrs.append(a)
    notes = np.concatenate(arrs)
    notes = notes[np.argsort(notes[:, 1], kind="stable")]
    np.save(args.out + ".npy", notes)

    # the soundtrack
    inputs, chains, labels = [], [], []
    srcs = [(args.applause, a1, args.applause_gain)] + [(s + ".mp3", p["start"], 0.0) for s, p in zip(stems, pieces)] \
        + [(args.applause, a2, args.applause_gain)]
    for i, (path, at, gain) in enumerate(srcs):
        inputs += ["-i", path]
        chains.append(f"[{i}:a]aresample=44100,aformat=channel_layouts=stereo,volume={gain}dB,"
                      f"adelay=delays={int(round(at * 1000))}:all=1[s{i}]")
        labels.append(f"[s{i}]")
    graph = ";".join(chains) + f";{''.join(labels)}amix=inputs={len(srcs)}:normalize=0:duration=longest," \
                               f"apad=whole_dur={end:.3f},atrim=end={end:.3f}[out]"
    subprocess.run(["ffmpeg", "-nostdin", "-y", "-v", "error", *inputs, "-filter_complex", graph, "-map", "[out]",
                    "-c:a", "libmp3lame", "-b:a", "320k", args.out + ".mp3"], check=True)

    with open(args.out + ".recital.json", "w", encoding="utf-8") as f:
        json.dump(spec, f, indent=1)
        f.write("\n")

    got = length(args.out + ".mp3")
    print(f"{args.out}.mp3: {got:.2f} s;  {args.out}.npy: {len(notes)} notes;  {args.out}.recital.json")
    print(f"  title 0-{title_end:g} s: {spec['title'][0]} / {spec['title'][1]}")
    print(f"  curtain opens {a1:g}-{a1 + args.curtain_seconds:g} s, applause {a1:g}-{a1 + clap:.2f} s")
    for p, tempo in zip(pieces, tempos):
        print(f"  {p['name']}: {p['start']:.2f}-{p['end']:.2f} s (tempo {tempo:g})")
    print(f"  applause {a2:.2f}-{a2 + clap:.2f} s, curtain closes {spec['curtain_close'][0]:g}-"
          f"{spec['curtain_close'][1]:g} s, video ends {end:.2f} s")
    print("render (copy the three files to the PVC first):")
    print(f"  PER_CARD=2 SCRIPT=concert_stage.py BLEND=Alcorcon_Recital.blend ./render_farm.sh --npy {args.out}.npy "
          f"--tempo 60 --duration {end:.2f} --out frames_{os.path.basename(args.out)}_v1 --engine cycles "
          f"--cycles-hw-rt --title none")
    print(f"mux:  ./concert_mux.sh frames_{os.path.basename(args.out)}_v1 {args.out} {os.path.basename(args.out)}_v1.mp4")


if __name__ == "__main__":
    main()
