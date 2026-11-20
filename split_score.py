#!/usr/bin/env python3
"""Cut a MusicXML score into pieces by bar range, keeping the engraving as it is.

The Open Well-Tempered Clavier on MuseScore gives each prelude and fugue as one
file (prelude-and-fugue-6-openwtc.mxl: the prelude's bars, then the fugue's).
This writes them as Scores/bwv851p.mxl and Scores/bwv851f.mxl, like the ones
downloaded singly.  The XML is cut, not re-exported by music21, so hidden notes,
ornaments and voices stay as MuseScore wrote them.  Each piece's bars are
renumbered from 1, and its first bar gets the divisions, key, time, staves and
clefs in force there, so a fugue starts with its own signature.  An upbeat bar
(MuseScore's implicit X1) becomes bar 0 of its piece.

    split_score.py Scores/prelude-and-fugue-6-openwtc.mxl 1-26:Scores/bwv851p.mxl 27-70:Scores/bwv851f.mxl
"""
import copy
import io
import sys
import zipfile
import xml.etree.ElementTree as ET

CONTAINER = ('<?xml version="1.0" encoding="UTF-8"?>\n<container><rootfiles>'
             '<rootfile full-path="score.xml" media-type="application/vnd.recordare.musicxml+xml"/>'
             '</rootfiles></container>\n')
ORDER = ['footnote', 'level', 'divisions', 'key', 'time', 'staves', 'part-symbol', 'instruments',
         'clef', 'staff-details', 'transpose', 'directive', 'measure-style']


def read(path):
    with zipfile.ZipFile(path) as z:
        root = ET.fromstring(z.read('META-INF/container.xml'))
        name = root.find('.//rootfile').get('full-path')
        return z.read(name)


def state_key(el):
    """Which setting an attributes child holds: clef 2 and clef 1 are separate."""
    return (el.tag, el.get('number'))


def cut(xml, first, last):
    tree = ET.ElementTree(ET.fromstring(xml))
    for part in tree.getroot().findall('part'):
        state = {}                               # the attributes in force, by setting
        kept = []
        prev = 0
        for m in list(part.findall('measure')):
            # MuseScore numbers an uncounted bar X1 (implicit="yes"): the fugue's upbeat in
            # 11 (BWV 856).  It goes with the bar after it.
            num = m.get('number')
            n = int(num) if num.isdigit() else prev + 1
            prev = n if num.isdigit() else prev
            if n < first:
                for a in m.findall('attributes'):
                    for child in a:
                        state[state_key(child)] = child
            if first <= n <= last:
                kept.append(m)
            else:
                part.remove(m)
        if not kept:
            sys.exit(f'no bars {first}-{last}')
        head = kept[0]
        attrs = head.find('attributes')
        if attrs is None:
            attrs = ET.Element('attributes')
            head.insert(0, attrs)
        have = {state_key(c) for c in attrs}
        for key, child in state.items():
            if key not in have and key[0] in ORDER:
                attrs.append(copy.deepcopy(child))
        attrs[:] = sorted(attrs, key=lambda c: ORDER.index(c.tag) if c.tag in ORDER else len(ORDER))
        start = 0 if kept[0].get('implicit') == 'yes' else 1   # an upbeat is bar 0
        for i, m in enumerate(kept, start):
            m.set('number', str(i))
    buf = io.BytesIO()
    tree.write(buf, encoding='UTF-8', xml_declaration=True)
    return buf.getvalue()


def write(path, xml):
    with zipfile.ZipFile(path, 'w', zipfile.ZIP_DEFLATED) as z:
        z.writestr('META-INF/container.xml', CONTAINER)
        z.writestr('score.xml', xml)


if __name__ == '__main__':
    xml = read(sys.argv[1])
    for spec in sys.argv[2:]:
        bars, out = spec.split(':', 1)
        a, b = (int(x) for x in bars.split('-'))
        write(out, cut(xml, a, b))
        print(f'{out}: bars {a}-{b}')
