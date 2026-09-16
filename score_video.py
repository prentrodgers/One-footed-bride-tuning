#!/usr/bin/env python3
"""A two-part score video for a --short_repeats rendering of a chorale.

Top half: the four-staff score (soprano, alto, tenor, bass) engraved by
LilyPond on one long line with strictly proportional spacing, scrolling left
at constant speed under a fixed cursor.  Bottom half: chord_report.py's
output for the tuning that was rendered, scrolling in step, the sounding
chord highlighted, with the two previous and two following chords in view.

    python score_video.py --chorale bwv261 --tempo 34 \\
        --mp3 Uploads/ball9-t61a_lm17_r1.25_df5_t3_d02_22_t034.mp3 \\
        --report chord_report_bwv261.txt --out score_bwv261.mp4

--report is the saved output of
    python chord_report.py --input_numpy_file <the -opt.npy that was rendered>
Timing: a --short_repeats rendering plays the chorale's sixteenth-note grid
at --tempo quarter notes per minute, so column c sounds at c * 15 / tempo
seconds; chord_report numbers its chords by that column.

Needs lilypond (only fs2 has it), ffmpeg, Pillow, music21.  Working files go
in --work (default: a directory next to --out).
"""
import argparse
import math
import os
import re
import subprocess
import sys
from fractions import Fraction

import numpy as np
from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

FPS = 30
W, H = 1920, 1080
CURSOR_X = int(W * 0.3)          # the fixed cursor, 30% in from the left
MONO = '/usr/share/fonts/adwaita-mono-fonts/AdwaitaMono-Regular.ttf'
MONO_BOLD = '/usr/share/fonts/adwaita-mono-fonts/AdwaitaMono-Bold.ttf'


# ── LilyPond source from music21, one note per line ─────────────────────────
STEP = {'C': 'c', 'D': 'd', 'E': 'e', 'F': 'f', 'G': 'g', 'A': 'a', 'B': 'b'}
DUR = {'whole': '1', 'half': '2', 'quarter': '4', 'eighth': '8', '16th': '16', '32nd': '32'}


def ly_pitch(p):
    name = STEP[p.step]
    if p.accidental is not None:
        alter = int(p.accidental.alter)
        name += ('is' * alter) if alter > 0 else ('es' * -alter)
    o = p.octave
    return name + ("'" * (o - 3) if o >= 3 else ',' * (3 - o))


def ly_dur(d):
    return DUR[d.type] + '.' * d.dots


def ly_key(key):
    t = key.tonic
    tonic = STEP[t.step]
    if t.accidental is not None:
        alter = int(t.accidental.alter)
        tonic += ('is' * alter) if alter > 0 else ('es' * -alter)
    return f'\\key {tonic} \\{key.mode}'


def ly_clef(clef):
    base = {'G': 'treble', 'F': 'bass', 'C': 'alto'}[clef.sign]
    if clef.octaveChange == -1:
        base += '_8'
    return f'\\clef "{base}"'


def build_ly(version, prop_denominator, paper_height_mm=80.0):
    """Return (ly_text, note_lines) where note_lines maps a source line number
    (1-based) to (part_index, onset in quarter notes) for every note."""
    import logging
    logging.disable(logging.CRITICAL)
    from music21 import corpus, note, chord
    s = corpus.parse(f'bach/{version}')
    key = s.analyze('key')
    parts = list(s.parts)[:4]
    names = ['S', 'A', 'T', 'B']
    lines = [
        '\\version "2.24.0"',
        '\\pointAndClickOn',
        '\\paper {',
        '  indent = 0 ragged-right = ##t',
        f'  paper-height = {paper_height_mm:.1f}\\mm top-margin = 2\\mm bottom-margin = 2\\mm',
        '  left-margin = 4\\mm right-margin = 4\\mm',
        '  page-breaking = #ly:one-line-breaking print-page-number = ##f tagline = ##f',
        '}',
        '\\layout {',
        '  \\context { \\Score',
        # LilyPond 2.26 wants a plain rational here; the older
        # #(ly:make-moment ...) form is ignored with a warning.
        f'    proportionalNotationDuration = #1/{prop_denominator}',
        '    \\override SpacingSpanner.strict-note-spacing = ##t',
        '    \\override SpacingSpanner.uniform-stretching = ##t',
        '    \\override BarNumber.break-visibility = ##(#t #t #t)',
        '    \\override BarNumber.self-alignment-X = #LEFT',
        '  }',
        '  \\context { \\Staff',
        '    \\override VerticalAxisGroup.staff-staff-spacing = '
        "#'((basic-distance . 8) (minimum-distance . 7) (padding . 1))",
        '  }',
        '}',
        '\\score {',
        '  \\new ChoirStaff <<',
    ]
    note_lines = {}
    for pi, p in enumerate(parts):
        clef = p.flatten().getElementsByClass('Clef')[0]
        ts = p.flatten().getElementsByClass('TimeSignature')[0]
        # The tenor reads best in the octave treble clef whatever the corpus
        # file says (bwv261 gives it a bass clef and a forest of ledger lines).
        clef_str = '\\clef "treble_8"' if pi == 2 else ly_clef(clef)
        lines.append(f'    \\new Staff = "{names[pi]}" {{')
        lines.append(f'      {clef_str} {ly_key(key)} \\time {ts.ratioString}')
        measures = list(p.getElementsByClass('Measure'))
        if measures and measures[0].duration.quarterLength < ts.barDuration.quarterLength:
            pickup = Fraction(measures[0].duration.quarterLength).limit_denominator(64)
            lines.append(f'      \\partial {int(4 / pickup)}')
        for m in measures:
            src = m.voices[0] if m.voices else m
            for e in src.notesAndRests:
                onset = float(m.offset + e.offset)
                if isinstance(e, note.Rest):
                    lines.append(f'      r{ly_dur(e.duration)}')
                    continue
                pitch = e.pitches[-1] if isinstance(e, chord.Chord) else e.pitch
                tie = '~' if (e.tie is not None and e.tie.type in ('start', 'continue')) else ''
                lines.append(f'      {ly_pitch(pitch)}{ly_dur(e.duration)}{tie}')
                note_lines[len(lines)] = (pi, onset)
            lines.append('      |')
        lines.append('    }')
    lines += ['  >>', '}', '']
    return '\n'.join(lines), note_lines


# ── LilyPond output: positions from the SVG, pixels from the PNG ────────────
# Emmentaler notehead outlines as they begin in LilyPond's SVG: solid, half, whole.
HEAD_GLYPHS = ('M0 -46c0 91', 'M-6 78c0 59', 'M0 -46', 'M-6 ')
def engrave(ly_text, work, stem):
    path = os.path.join(work, stem + '.ly')
    with open(path, 'w') as f:
        f.write(ly_text)
    subprocess.run(['lilypond', '-dbackend=svg', '-o', os.path.join(work, stem), path],
                   check=True, capture_output=True)
    return path, os.path.join(work, stem + '.svg')


def rasterize(ly_path, work, stem, dpi):
    subprocess.run(['lilypond', '--png', f'-dresolution={dpi}', '-danti-alias-factor=2',
                    '-o', os.path.join(work, stem), ly_path], check=True, capture_output=True)
    return os.path.join(work, stem + '.png')


def parse_svg(svg_path, note_lines):
    """(mm per svg unit, page width mm, page height mm,
        notes [(part, onset, x_units)], staff centre y per staff [units])"""
    text = open(svg_path).read()
    head = re.search(r'<svg[^>]*width="([\d.]+)mm"[^>]*height="([\d.]+)mm"[^>]*viewBox="[\d.-]+ [\d.-]+ ([\d.]+) ([\d.]+)"', text)
    w_mm, h_mm, vb_w, vb_h = map(float, head.groups())
    mm_per_unit = w_mm / vb_w
    # Each note's anchor wraps its glyphs; take the notehead's position, not
    # an accidental's (which comes first in the anchor when there is one).
    notes = []
    for m in re.finditer(r'<a [^>]*textedit://[^"]*:(\d+):\d+:\d+">(.*?)</a>', text, re.S):
        line = int(m.group(1))
        if line not in note_lines:
            continue
        for gx, gy, d in re.findall(r'<g transform="translate\(([\d.-]+), ([\d.-]+)\)">\s*<path[^>]*d="([^"]{0,12})', m.group(2)):
            if d.startswith(HEAD_GLYPHS):
                pi, onset = note_lines[line]
                notes.append((pi, onset, float(gx), float(gy)))
                break
    # staff lines: long horizontal lines; five per staff, one unit apart
    ys = []
    for m in re.finditer(r'<g transform="translate\(([\d.-]+), ([\d.-]+)\)">\s*<line [^>]*x1="0\.0500" y1="0" x2="([\d.]+)" y2="0"/>', text):
        if float(m.group(3)) > 50:
            ys.append(float(m.group(2)))
    ys.sort()
    staves = []
    group = [ys[0]]
    for y in ys[1:]:
        if y - group[-1] < 1.5:
            group.append(y)
        else:
            staves.append(sum(group) / len(group)); group = [y]
    staves.append(sum(group) / len(group))
    return mm_per_unit, w_mm, h_mm, notes, staves


def fit_time_axis(notes):
    """x_units = x0 + k * onset_quarters, least squares over every note."""
    a = np.array([[1.0, n[1]] for n in notes])
    x = np.array([n[2] for n in notes])
    (x0, k), *_ = np.linalg.lstsq(a, x, rcond=None)
    resid = x - (x0 + k * a[:, 1])
    return x0, k, float(np.abs(resid).max())


# ── chord_report text ───────────────────────────────────────────────────────
def parse_report(path):
    """[(column, [chord line, interval line 1, interval line 2])], plus the
    header lines (key, top notes) for the static strip."""
    lines = open(path, encoding='utf-8').read().expandtabs(8).splitlines()
    blocks, header = [], []
    i = 0
    while i < len(lines):
        m = re.match(r'^(\d+): ', lines[i])
        if m:
            blk = [lines[i]]
            j = i + 1
            while j < len(lines) and not re.match(r'^\d+: ', lines[j]):
                if not lines[j].lstrip().startswith('# Fr/To'):
                    blk.append(lines[j])
                j += 1
            blocks.append((int(m.group(1)), [l for l in blk if l.strip()]))
            i = j
        else:
            if not blocks and lines[i].strip():
                header.append(lines[i])
            i += 1
    return blocks, header


# ── video encoder ───────────────────────────────────────────────────────────
def encoder_args(choice):
    """ffmpeg arguments before the inputs and after them for the H.264 encoder
    to use.  fs2's ffmpeg has no libx264, but its iGPU encodes through VAAPI."""
    have = subprocess.run(['ffmpeg', '-hide_banner', '-encoders'], capture_output=True, text=True).stdout
    options = {
        'libx264': {'name': 'libx264', 'pre': [],
                    'post': ['-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-preset', 'medium', '-crf', '18']},
        'vaapi': {'name': 'h264_vaapi', 'pre': ['-vaapi_device', '/dev/dri/renderD128'],
                  'post': ['-vf', 'format=nv12,hwupload', '-c:v', 'h264_vaapi', '-qp', '18']},
        'av1': {'name': 'libsvtav1', 'pre': [],
                'post': ['-c:v', 'libsvtav1', '-preset', '6', '-crf', '22', '-pix_fmt', 'yuv420p']},
        'openh264': {'name': 'libopenh264', 'pre': [],
                     'post': ['-c:v', 'libopenh264', '-pix_fmt', 'yuv420p', '-b:v', '12M']},
    }
    if choice != 'auto':
        return options[choice]
    # vaapi is never picked automatically: Fedora's stock Mesa lists the
    # encoder but has no H.264 profile, so it fails only once frames arrive.
    # AV1 comes before OpenH264 because Fedora's VLC cannot play OpenH264's
    # output (its avcodec wrapper stalls on the libopenh264 decoder, giving a
    # black picture with sound) but plays AV1 through dav1d.
    if ' libx264 ' in have:
        return options['libx264']
    if ' libsvtav1 ' in have:
        return options['av1']
    return options['openh264']


# ── frames ──────────────────────────────────────────────────────────────────
def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0],
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--chorale', required=True)
    ap.add_argument('--tempo', type=float, required=True, help='quarter notes per minute of the rendering')
    ap.add_argument('--mp3', required=True)
    ap.add_argument('--report', required=True, help='saved chord_report.py output for the rendered tuning')
    ap.add_argument('--out', required=True)
    ap.add_argument('--work', default=None)
    ap.add_argument('--measures', type=float, default=2.0, help='measures visible across the width')
    ap.add_argument('--encoder', default='auto',
                    help='libx264, av1 (SVT-AV1), openh264, vaapi, or auto: libx264 if present, else av1')
    ap.add_argument('--stills', default=None, help='comma-separated seconds: write those frames as PNGs and stop')
    args = ap.parse_args()

    work = args.work or os.path.splitext(args.out)[0] + '_work'
    os.makedirs(work, exist_ok=True)
    stem = args.chorale

    # Calibration pass at 1/16, then re-engrave with the note spacing that
    # makes --measures measures fill the width at a height that fits the top half.
    ly, note_lines = build_ly(args.chorale, 16)
    ly_path, svg = engrave(ly, work, stem + '_cal')
    mm_per_unit, w_mm, h_mm, notes, staves = parse_svg(svg, note_lines)
    x0, k, resid = fit_time_axis(notes)
    beats_per_measure = 4.0
    top_h = H // 2
    # Page just tall enough for the four staves, bar numbers above and ledger
    # lines below; that height fills the top half, which fixes the scale, and
    # the note spacing is then chosen so --measures measures span the width.
    system_units = (staves[-1] - staves[0]) + 14
    paper_mm = system_units * mm_per_unit + 4.0
    px_per_unit = top_h / (paper_mm / mm_per_unit)
    window_units = W / px_per_unit
    denom = max(8, int(round(16 * (window_units / (args.measures * beats_per_measure)) / k)))
    print(f'calibration: {k:.3f} units/quarter at 1/16, residual {resid:.3f}; '
          f'system {system_units:.1f} units -> page {paper_mm:.1f} mm, spacing 1/{denom}')
    ly, note_lines = build_ly(args.chorale, denom, paper_mm)
    ly_path, svg = engrave(ly, work, stem)
    mm_per_unit, w_mm, h_mm, notes, staves = parse_svg(svg, note_lines)
    x0, k, resid = fit_time_axis(notes)
    print(f'final: {k:.3f} units/quarter, residual {resid:.3f} units, page {w_mm:.0f}x{h_mm:.0f} mm, '
          f'{len(notes)} notes, staves at {[round(s, 1) for s in staves]}')
    if resid > 0.5:
        print('WARNING: spacing is not proportional; the cursor will drift', file=sys.stderr)

    px_per_unit = top_h / (h_mm / mm_per_unit)
    dpi = px_per_unit * 25.4 / mm_per_unit
    png = rasterize(ly_path, work, stem, dpi)
    score = Image.open(png).convert('RGB')
    print(f'score image {score.size}, {px_per_unit:.2f} px/unit, {dpi:.0f} dpi')
    # LilyPond may round the resolution; measure the true scale from the page width.
    px_per_unit = score.size[0] / (w_mm / mm_per_unit)
    if score.size[1] > top_h:
        print(f'WARNING: score is {score.size[1]} px tall, cropping to {top_h}', file=sys.stderr)
    score_y = max(0, (top_h - score.size[1]) // 2)

    # Audio length sets the frame count.
    dur = float(subprocess.run(['ffprobe', '-v', 'error', '-show_entries', 'format=duration',
                                '-of', 'csv=p=0', args.mp3], capture_output=True, text=True).stdout)
    n_frames = math.ceil(dur * FPS)
    sec_per_col = 15.0 / args.tempo
    blocks, header = parse_report(args.report)
    block_times = [c * sec_per_col for c, _ in blocks]

    font = ImageFont.truetype(MONO, 22)
    font_b = ImageFont.truetype(MONO_BOLD, 22)
    font_small = ImageFont.truetype(MONO, 18)
    line_h = 28
    block_h = 3 * line_h + 14
    bottom_top = top_h
    strip_h = 2 * line_h + 10                     # static header strip
    scroll_top = bottom_top + strip_h
    anchor = scroll_top + 2 * block_h + 8         # current block sits here: two above, two+ below
    label_font = ImageFont.truetype(MONO_BOLD, 26)
    key_line = next((l for l in header if l.startswith('Key:')), '')
    title = f'{args.chorale}   {key_line}   tempo {args.tempo:g}   {os.path.basename(args.report)}'
    col_head = ' #   cents (S A T B)       note names    score      intervals: # from to  cents  ratio'

    def frame_at(t):
        im = Image.new('RGB', (W, H), (255, 255, 255))
        beat = t * args.tempo / 60.0
        x_units = x0 + k * beat
        x_px = int(round(x_units * px_per_unit))
        im.paste(score, (CURSOR_X - x_px, score_y))
        d = ImageDraw.Draw(im)
        # staff labels pinned at the left edge
        d.rectangle([0, 0, 44, top_h], fill=(255, 255, 255))
        for name, sy in zip('SATB', staves):
            y = score_y + sy * px_per_unit
            d.text((12, y - 14), name, font=label_font, fill=(40, 40, 40))
        d.line([CURSOR_X, 4, CURSOR_X, top_h - 4], fill=(200, 30, 30), width=3)
        # bottom half
        d.rectangle([0, bottom_top, W, H], fill=(16, 20, 26))
        d.line([0, bottom_top, W, bottom_top], fill=(90, 90, 90), width=2)
        d.text((24, bottom_top + 8), title, font=font_b, fill=(230, 230, 230))
        d.text((24, bottom_top + 8 + line_h), col_head, font=font_small, fill=(150, 150, 150))
        # which block sounds now, and how far through it we are
        i = max(0, np.searchsorted(block_times, t, side='right') - 1)
        t_i = block_times[i]
        t_next = block_times[i + 1] if i + 1 < len(blocks) else dur
        frac = min(1.0, max(0.0, (t - t_i) / max(1e-6, t_next - t_i)))
        # The chord list scrolls inside its own panel so nothing spills into
        # the header or the score above.
        panel = Image.new('RGB', (W, H - scroll_top), (16, 20, 26))
        pd = ImageDraw.Draw(panel)
        for j in range(max(0, i - 3), min(len(blocks), i + 5)):
            y = (anchor - scroll_top) + (j - i - frac) * block_h
            if y + block_h < 0 or y > panel.size[1]:
                continue
            col, lines = blocks[j]
            if j == i:
                pd.rectangle([12, y - 6, W - 12, y + block_h - 10], fill=(64, 52, 10))
                colour, f0 = (255, 220, 90), font_b
            else:
                colour, f0 = (185, 190, 200), font
            for li, text in enumerate(lines[:3]):
                pd.text((24, y + li * line_h), text, font=f0 if li == 0 else font, fill=colour)
        im.paste(panel, (0, scroll_top))
        d.line([0, scroll_top - 1, W, scroll_top - 1], fill=(60, 60, 60), width=1)
        return im

    if args.stills:
        for s in args.stills.split(','):
            t = float(s)
            p = os.path.join(work, f'still_{t:07.2f}.png')
            frame_at(t).save(p)
            print('wrote', p)
        return

    cmd = ['ffmpeg', '-y', '-loglevel', 'error']
    video = encoder_args(args.encoder)
    cmd += video['pre']
    cmd += ['-f', 'rawvideo', '-pix_fmt', 'rgb24', '-s', f'{W}x{H}', '-r', str(FPS), '-i', '-',
            '-i', args.mp3] + video['post'] + ['-c:a', 'aac', '-shortest', args.out]
    print('encoder:', video['name'])
    proc = subprocess.Popen(cmd, stdin=subprocess.PIPE)
    for f in range(n_frames):
        proc.stdin.write(frame_at(f / FPS).tobytes())
        if f % 600 == 0:
            print(f'frame {f}/{n_frames}', flush=True)
    proc.stdin.close()
    proc.wait()
    print('wrote', args.out, 'frames', n_frames, 'exit', proc.returncode)


if __name__ == '__main__':
    main()
