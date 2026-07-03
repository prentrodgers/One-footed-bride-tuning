#!/usr/bin/env python3.10
"""
Post one finished Bach chorale (just-intonation rendering) to Twitter/X daily.
Links to mp3 files hosted on ripnread.com.

Crontab entry (6:00 AM every day):
    0 6 * * * /usr/bin/python3.10 /home/prent/Dropbox/Tutorials/TonicNet/daily_chorale_tweet.py >> /tmp/daily_chorale_tweet.log 2>&1

Before first use:
    1. pip install tweepy
    2. Create a Twitter/X developer account and app at https://developer.twitter.com
    3. Create ~/.daily_chorale_tweet.env with:
         TWITTER_API_KEY=...
         TWITTER_API_SECRET=...
         TWITTER_ACCESS_TOKEN=...
         TWITTER_ACCESS_SECRET=...
    4. Upload mp3 album to ripnread.com/listen/ once a month.
    5. Update MP3_DIR to point to the local copy (for filename scanning).
"""

import os
import re
import json
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
BASE_URL = "http://ripnread.com/listen"
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
    r"sf([\d.]+)_"                    # stability factor
    r"(?:md|df)(\d+)_"                # detail value (legacy md max-delta / newer df density-level)
    r"sp(\d+)_"                       # spread
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
    url = f"{base_url}/{quote(fname)}"

    m = FILENAME_RE.match(fname)
    if not m:
        return None, f"{fname}\n{url}", url

    track, variant, limit, ratio, sf, detail_value, sp, tol, dur_m, dur_s, tempo = m.groups()
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


def find_latest_album_dir(uploads_root=UPLOADS_ROOT):
    """Find the most recent b* directory containing ball9-*.mp3 files."""
    root = Path(uploads_root)
    candidates = sorted(
        (d for d in root.iterdir() if d.is_dir() and d.name.startswith("c")
         and list(d.glob("ball9-*.mp3"))),
        key=lambda d: d.stat().st_mtime,
        reverse=True,
    )
    if not candidates:
        print(f"No album directories with ball9-*.mp3 in {uploads_root}", file=sys.stderr)
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
    """Load the index of the next file to post."""
    if os.path.exists(STATE_FILE):
        with open(STATE_FILE) as f:
            return json.load(f)
    return {"posted": [], "next_index": 0, "mp3_dir": MP3_DIR}


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
    if args.reset:
        state = {"posted": [], "next_index": 0, "mp3_dir": mp3_dir}

    # If the directory changed, reset
    if state.get("mp3_dir") != mp3_dir:
        state = {"posted": [], "next_index": 0, "mp3_dir": mp3_dir}

    idx = state["next_index"]
    if idx >= len(files):
        # Wrap around for rotation
        idx = 0
        state["next_index"] = 0
        print("Completed full rotation, starting over.")

    fname = files[idx]
    bwv, description, url = parse_filename(fname, base_url=args.base_url)

    success = post_tweet(fname, description, url, dry_run=args.dry_run)

    if success:
        state["posted"].append(fname)
        state["next_index"] = idx + 1
        save_state(state)
        remaining = len(files) - state["next_index"]
        print(f"\n{remaining} chorales until next rotation.")


if __name__ == "__main__":
    main()
