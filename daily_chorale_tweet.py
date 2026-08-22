#!/usr/bin/env python3.10
"""
Post one finished Bach chorale (just-intonation rendering) to Twitter/X daily.
Links to mp3 files hosted on Cloudflare R2 at audio.microtonalnotes.net.
X rewrites every outbound link to https://, so the host must have a real cert.

Crontab entry (6:00 AM every day):
    0 6 * * * /home/prent/miniforge3/bin/mamba run -n csound python \
        /home/prent/Repos/One-footed-bride-tuning/daily_chorale_tweet.py >> /tmp/daily_chorale_tweet.log 2>&1
    (this runs on fs7)

Before first use:
    1. pip install tweepy
    2. Create a Twitter/X developer account and app at https://developer.twitter.com
    3. Create ~/.daily_chorale_tweet.env with:
         TWITTER_API_KEY=...
         TWITTER_API_SECRET=...
         TWITTER_ACCESS_TOKEN=...
         TWITTER_ACCESS_SECRET=...
    4. Publish the mp3 album to the R2 bucket once a month:
         cd ~/Repos/file-service && ./scripts/publish-album.sh <album-dir>
    5. Update MP3_DIR to point to the local copy (for filename scanning).
"""

import os
import re
import json
import random
import sys
from pathlib import Path
from urllib.parse import quote

try:
    import tweepy
except ImportError:
    print("Install tweepy: pip install tweepy", file=sys.stderr)
    sys.exit(1)

# ── Configuration ──────────────────────────────────────────────────────────
UPLOADS_ROOT = os.path.expanduser("~/Dropbox/Uploads")
MP3_DIR = None  # auto-detected from latest a* directory in UPLOADS_ROOT
BASE_URL = "https://audio.microtonalnotes.net"
STATE_FILE = os.path.expanduser("~/.daily_chorale_tweet_state.json")
ENV_FILE = os.path.expanduser("~/.daily_chorale_tweet.env")

# ── BWV title lookup ──────────────────────────────────────────────────────
BWV_TITLES = {
    "253": "Ach bleib bei uns, Herr Jesu Christ",
    "254": "Ach Gott, erhör mein Seufzen und Wehklagen",
    "255": "Ach Gott und Herr, wie groß und schwer",
    "256": "Ach lieben Christen, seid getrost",
    "257": "Wär Gott nicht mit uns diese Zeit",
    "258": "Wo Gott der Herr nicht bei uns hält",
    "259": "Ach, was soll ich Sünder machen",
    "260": "Allein Gott in der Höh sei Ehr",
    "261": "Allein zu dir, Herr Jesu Christ",
    "262": "Alle Menschen müssen sterben",
    "263": "Alles ist an Gottes Segen",
    "264": "Als der gütige Gott",
}

# Filename pattern:
#   ball9-t53a_lm23_r1.50_sf1.25_md33_sp07_t1_d09_55_t110.mp3
#
# Abbreviations:
#   ball9    = Csound orchestra file (ball9.csd)
#   t53a     = track 53 variant a → BWV 253  (last 2 digits = BWV suffix)
#   lm23     = limit: 23-limit tonality diamond (just intonation)
#   r1.50    = ratio factor: 1.50 (scaling weight for interval ratios)
#   sf1.25   = stability factor: weighting for pitch stability across chords
#   md33     = legacy max delta: 33 cents max allowed shift for repeated pitch classes
#   df5      = density level: higher values are denser (e.g. 4-5), lower values are sparser (e.g. 0-1)
#   sp07     = spread: 7 (weighted pitch-class cent-spread parameter)
#   t1       = tolerance: ±1 cent from ideal just-intonation ratio
#   d09_55   = duration: 9 minutes 55 seconds
#   t110     = tempo: 110 BPM

FILENAME_RE = re.compile(
    r"ball9-t(\d{2,3})(\w?)_"        # track number + variant letter
    r"lm(\d+)_"                       # limit
    r"r([\d.]+)_"                     # ratio factor
    r"(?:sf[\d.]+_)?"                 # stability factor (optional — removed from new filenames)
    r"(?:md|df)(\d+)_"                # detail value (legacy md max-delta / newer df density-level)
    r"(?:sp\d+_)?"                    # spread (optional — removed from new filenames)
    r"t(\d+)_"                        # tolerance
    r"d(\d+)_(\d+)_"                  # duration mm_ss
    r"t(\d+)"                         # tempo
    r"\.mp3$"
)


def load_env():
    """Load credentials from env file if environment vars are not set."""
    if os.path.exists(ENV_FILE):
        with open(ENV_FILE) as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#") and "=" in line:
                    k, v = line.split("=", 1)
                    os.environ.setdefault(k.strip(), v.strip())


def parse_filename(fname, base_url=BASE_URL):
    """Parse an mp3 filename into a human-readable description and URL."""
    normalized_base = base_url.strip().rstrip("/")
    if normalized_base.startswith("http://"):
        normalized_base = "https://" + normalized_base.removeprefix("http://")
    url = f"{normalized_base}/{quote(fname)}"

    m = FILENAME_RE.match(fname)
    if not m:
        return None, f"{fname}\n{url}", url

    track, variant, limit, ratio, detail_value, tol, dur_m, dur_s, tempo = m.groups()
    bwv = f"2{track}"  # e.g. track 53 → BWV 253
    title = BWV_TITLES.get(bwv, "Bach Chorale")

    desc = (
        f"Bach BWV {bwv} – \"{title}\"\n"
        f"{limit}-limit just intonation (tonality diamond).\n"
        f"{int(dur_m)}:{dur_s} at {tempo} BPM.\n"
        f"Composed by Prent Rodgers, with the help of Dr. Claude.\n"
        f"{url}"
    )
    return bwv, desc, url


SERIES = ("c", "d")


def _album_key(d):
    """Album directories are named c0, c1, ... c9, then d0, d1, ... - sort on
    the series letter first, then the number.

    The letter has to lead, because the d series supersedes the c one: d0 is
    newer than c9 even though 0 < 9. Sorting on the number alone would rank
    every d album below every c album, and the d series would never be picked
    up at all - the daily post would go on serving c9 with no error to show
    for it.

    Deliberately NOT st_mtime. Dropbox rewrites mtime to whenever it synced a
    directory down, so the ordering differs per machine: on fs2 all ten albums
    carry the same nine-minute timestamp and c0 sorts newest, which would post
    the June first-pass instead of the current album. fs7 is only correct today
    because that is where the albums were created; a resync would break it
    silently. The name means the same thing on every machine.

    Returns (-1, -1) for a directory with no number after the letter - notably
    compositions/, which also starts with c and also holds ball9-*.mp3 files
    (three of them) - so it sorts last and is never chosen over a real album.
    """
    m = re.match(r"([cd])(\d+)", d.name)
    if not m:
        return (-1, -1)
    return (SERIES.index(m.group(1)), int(m.group(2)))


def find_latest_album_dir(uploads_root=UPLOADS_ROOT):
    """Find the highest c*/d* directory containing ball9-*.mp3 files."""
    root = Path(uploads_root)
    candidates = sorted(
        (d for d in root.iterdir() if d.is_dir()
         and d.name.startswith(SERIES) and list(d.glob("ball9-*.mp3"))),
        key=_album_key,
        reverse=True,
    )
    if not candidates or _album_key(candidates[0])[0] < 0:
        print(f"No numbered album directory (c0, c1, ... d0, d1, ...) in {uploads_root}", file=sys.stderr)
        sys.exit(1)
    return str(candidates[0])


def get_mp3_files(directory):
    """Return sorted list of .mp3 files in directory."""
    p = Path(directory)
    if not p.is_dir():
        print(f"Directory not found: {directory}", file=sys.stderr)
        sys.exit(1)
    files = sorted(f.name for f in p.glob("ball9-*.mp3"))
    if not files:
        print(f"No ball9-*.mp3 files in {directory}", file=sys.stderr)
        sys.exit(1)
    return files


def load_state():
    """Load posted-file tracking state."""
    if os.path.exists(STATE_FILE):
        with open(STATE_FILE) as f:
            return json.load(f)
    return {"posted": [], "mp3_dir": MP3_DIR}


def save_state(state):
    with open(STATE_FILE, "w") as f:
        json.dump(state, f, indent=2)


def twitter_client():
    """Authenticate and return tweepy.Client for v2 tweets."""
    load_env()
    api_key = os.environ.get("TWITTER_API_KEY")
    api_secret = os.environ.get("TWITTER_API_SECRET")
    access_token = os.environ.get("TWITTER_ACCESS_TOKEN")
    access_secret = os.environ.get("TWITTER_ACCESS_SECRET")

    if not all([api_key, api_secret, access_token, access_secret]):
        print(
            "Set TWITTER_API_KEY, TWITTER_API_SECRET, "
            "TWITTER_ACCESS_TOKEN, TWITTER_ACCESS_SECRET",
            file=sys.stderr,
        )
        sys.exit(1)

    client = tweepy.Client(
        consumer_key=api_key,
        consumer_secret=api_secret,
        access_token=access_token,
        access_token_secret=access_secret,
    )
    return client


def post_tweet(fname, description, url, dry_run=False):
    """Post a text tweet with a link to the mp3 on ripnread.com."""
    tweet_text = description
    if len(tweet_text) > 280:
        tweet_text = tweet_text[:277] + "..."

    if dry_run:
        print("=== DRY RUN ===")
        print(f"File: {fname}")
        print(f"Tweet ({len(tweet_text)} chars):\n{tweet_text}")
        return True

    client = twitter_client()
    print(f"Posting tweet for {fname} ...")
    response = client.create_tweet(text=tweet_text)
    tweet_id = response.data["id"]
    print(f"Posted: https://twitter.com/prentrodgers/status/{tweet_id}")
    return True


def main():
    import argparse

    parser = argparse.ArgumentParser(description="Post a daily chorale tweet")
    parser.add_argument("--dry-run", action="store_true",
                        help="Print what would be posted without actually tweeting")
    parser.add_argument("--mp3-dir", default=None,
                        help="Directory with mp3 files (default: latest a* dir in Uploads)")
    parser.add_argument("--base-url", default=BASE_URL,
                        help=f"Base URL for mp3 hosting (default: {BASE_URL})")
    parser.add_argument("--reset", action="store_true",
                        help="Reset state and start from the first file")
    args = parser.parse_args()

    mp3_dir = args.mp3_dir or find_latest_album_dir()
    print(f"Album directory: {mp3_dir}")
    files = get_mp3_files(mp3_dir)

    state = load_state()
    if args.reset or state.get("mp3_dir") != mp3_dir:
        state = {"posted": [], "mp3_dir": mp3_dir}

    posted = set(state["posted"])
    remaining = [f for f in files if f not in posted]
    if not remaining:
        print("Completed full rotation, starting over.")
        state["posted"] = []
        remaining = files[:]

    fname = random.choice(remaining)
    bwv, description, url = parse_filename(fname, base_url=args.base_url)

    success = post_tweet(fname, description, url, dry_run=args.dry_run)

    if success:
        state["posted"].append(fname)
        save_state(state)
        print(f"\n{len(remaining) - 1} chorales remaining in rotation.")


if __name__ == "__main__":
    main()
