#!/usr/bin/env python3
"""
Post one finished Bach chorale (just-intonation rendering) to Twitter/X daily.
Links to mp3 files hosted on Cloudflare R2 at audio.microtonalnotes.net.
X rewrites every outbound link to https://, so the host must have a real cert.

Which album: the newest one IN THE R2 BUCKET — the album whose most recent
upload is the most recent of all.  The bucket is what the links point at, so
it is the only thing worth asking.  Earlier versions scanned
~/Dropbox/Uploads for the highest c*/d* directory, which went wrong three
ways: a directory named outside the pattern (DB-09-16-26) was ignored, a
directory dropped in Dropbox just to listen to on a walk could become the
daily album by its name alone, and nothing checked that what it picked had
actually been published.

Which file: random, without repeats, until the album is exhausted; then the
rotation starts over.  A new album on R2 starts a new rotation on its own.

The link is checked (HEAD, expects 200 audio/mpeg) before anything is posted.
A tweet with a dead link is worse than a day without a tweet, so on any
problem — no credentials, the bucket unreachable, the object missing — this
exits non-zero and posts nothing.  The cron log says why.

    daily_chorale_tweet.py --list        # albums on R2, newest first
    daily_chorale_tweet.py --dry-run     # what would be posted, no tweet
    daily_chorale_tweet.py --album DB-09-16-26 --dry-run   # a particular album

Crontab entry (6:00 AM every day), on fs7:
    0 6 * * * /home/prent/miniforge3/bin/mamba run -n csound python \
        /home/prent/Repos/One-footed-bride-tuning/daily_chorale_tweet.py >> /tmp/daily_chorale_tweet.log 2>&1

Before first use:
    1. In the csound env:  pip install tweepy boto3
    2. Twitter/X developer app at https://developer.twitter.com; its four
       keys go in ~/.daily_chorale_tweet.env (below).
    3. An R2 API token that can READ the bucket: Cloudflare dashboard ->
       R2 -> Manage R2 API Tokens -> Create, permission "Object Read only",
       bucket microtonalnotes-audio.  The page shows an Access Key ID, a
       Secret Access Key and the S3 endpoint for the account.
    4. ~/.daily_chorale_tweet.env, mode 600:
         TWITTER_API_KEY=...
         TWITTER_API_SECRET=...
         TWITTER_ACCESS_TOKEN=...
         TWITTER_ACCESS_SECRET=...
         R2_ENDPOINT=https://<account id>.r2.cloudflarestorage.com
         R2_ACCESS_KEY_ID=...
         R2_SECRET_ACCESS_KEY=...
         R2_BUCKET=microtonalnotes-audio        (optional; this is the default)
    5. Publish an album:  cd ~/Repos/file-service && ./scripts/publish-album.sh <dir>
       It is in the rotation the next morning; nothing here to update.
       Objects are keyed <album dir>/<filename>, and so are the links.
"""

import json
import os
import random
import re
import sys
import urllib.error
import urllib.request
from urllib.parse import quote

try:
    import tweepy
except ImportError:
    print("Install tweepy: pip install tweepy", file=sys.stderr)
    sys.exit(1)

# ── Configuration ──────────────────────────────────────────────────────────
BASE_URL = "https://audio.microtonalnotes.net"
DEFAULT_BUCKET = "microtonalnotes-audio"
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
    # 267 and 415-438, checked against bach-chorales.com on 19 Sep 2026
    "267": "An Wasserflüssen Babylon",
    "415": "Valet will ich dir geben",
    "416": "Vater unser im Himmelreich",
    "417": "Von Gott will ich nicht lassen",
    "418": "Von Gott will ich nicht lassen",
    "419": "Von Gott will ich nicht lassen",
    "420": "Warum betrübst du dich, mein Herz",
    "421": "Warum betrübst du dich, mein Herz",
    "422": "Warum sollt ich mich denn grämen",
    "423": "Was betrübst du dich, mein Herze",
    "424": "Was bist du doch, o Seele so betrübet",
    "425": "Was willst du dich, o meine Seele, kränken",
    "426": "Weltlich Ehr und zeitlich Gut",
    "427": "Wenn ich in Angst und Not",
    "428": "Wenn mein Stündlein vorhanden ist",
    "429": "Wenn mein Stündlein vorhanden ist",
    "430": "Wenn mein Stündlein vorhanden ist",
    "431": "Wenn wir in höchsten Nöten sein",
    "432": "Wenn wir in höchsten Nöten sein",
    "433": "Wer Gott vertraut, hat wohl gebaut",
    "434": "Wer nur den lieben Gott lässt walten",
    "435": "Wie bist du, Seele, in mir so gar betrübt",
    "436": "Wie schön leuchtet der Morgenstern",
    "437": "Wir glauben all an einen Gott",
    "438": "Wo Gott zum Haus nicht gibt sein Gunst",
}

# Filename pattern (renamed 9/24/26; everything before that is the old
# ball9-t53a_lm23_r1.50_..._t110.mp3 scheme, which this no longer reads):
#   b424f_df0_t3_d04_08_t092_ap4_lm19_r1.25.mp3
#
# Abbreviations:
#   b        = the rendered chorale (Csound orchestra ball9.csd)
#   424f     = BWV 424, variant f — always 3 digits, so 433 and 233 cannot collide
#   df0      = density level: higher is denser (4-5), lower is sparser (0-1)
#   md33     = legacy max delta, written instead of df when density_level is None
#   t3       = tolerance: ±3 cents from the ideal just-intonation ratio
#   d04_08   = duration: 4 minutes 8 seconds
#   t092     = tempo: 92 BPM
#   ap4      = repeat pattern drawn for this run: ap4 is the even pattern
#              (4,4,8,8,16,16), ap1 the prime one (1,3,5,11,17,31), ap3 the
#              slow-floor one (3,3,6,6,9,9,18,18).  ABSENT on --short_repeats.
#   lm19     = limit: 19-limit tonality diamond (just intonation)
#   r1.25    = ratio factor: scaling weight for interval ratios
#
# The settings that vary least (ap/lm/r) sit at the tail, so the leading ~20
# characters carry chorale, variant, density, tolerance and running time — which
# is all a phone or car display shows.  Tempo is therefore NOT the last token.

FILENAME_RE = re.compile(
    r"b(\d{3})(\w?)_"                 # BWV number + variant letter
    r"(?:md|df)(\d+)_"                # detail value (legacy md max-delta / newer df density-level)
    r"t(\d+)_"                        # tolerance
    r"d(\d+)_(\d+)_"                  # duration mm_ss
    r"t(\d+)"                         # tempo
    r"(?:_ap(\d+))?"                  # repeat pattern (absent on --short_repeats)
    r"_lm(\d+)"                       # limit
    r"_r([\d.]+)"                     # ratio factor
    r"\.mp3$"
)

# Which bucket objects are ours.  The prefix is now a single "b", so a bare
# startswith("b") would sweep up anything at all — anchor on b + three digits.
BUCKET_FILE_RE = re.compile(r"^b\d{3}[A-Za-z]?_.*\.mp3$")


def load_env():
    """Load credentials from env file if environment vars are not set."""
    if os.path.exists(ENV_FILE):
        with open(ENV_FILE) as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#") and "=" in line:
                    k, v = line.split("=", 1)
                    os.environ.setdefault(k.strip(), v.strip())


def mp3_url(key, base_url=BASE_URL):
    """The public URL of an object.  The key is <album>/<filename>, and the
    album part is what keeps two albums' identical filenames apart."""
    base = base_url.strip().rstrip("/")
    if base.startswith("http://"):
        base = "https://" + base.removeprefix("http://")
    return f"{base}/{quote(key)}"


def parse_filename(fname, url):
    """Parse an mp3 filename into (bwv, tweet text)."""
    m = FILENAME_RE.match(fname)
    if not m:
        return None, f"{fname}\n{url}"

    # Group order follows the filename: lm and r moved to the tail on 9/24/26.
    bwv, variant, detail_value, tol, dur_m, dur_s, tempo, _primes, limit, ratio = m.groups()
    # The BWV number is always three digits now, so no hundreds digit to infer.
    title = BWV_TITLES.get(bwv, "Bach Chorale")

    desc = (
        f"Bach BWV {bwv} – \"{title}\"\n"
        f"{limit}-limit just intonation (tonality diamond).\n"
        f"{int(dur_m)}:{dur_s} at {tempo} BPM.\n"
        f"Composed by Prent Rodgers, with the help of Claude Code Opus 5.\n"
        f"{url}"
    )
    return bwv, desc


# ── The bucket ─────────────────────────────────────────────────────────────
def r2_client():
    """An S3 client for the R2 bucket, from the R2_* variables in the env file."""
    load_env()
    endpoint = os.environ.get("R2_ENDPOINT")
    key_id = os.environ.get("R2_ACCESS_KEY_ID")
    secret = os.environ.get("R2_SECRET_ACCESS_KEY")
    if not all([endpoint, key_id, secret]):
        print("Set R2_ENDPOINT, R2_ACCESS_KEY_ID and R2_SECRET_ACCESS_KEY in "
              f"{ENV_FILE} (see the docstring for where they come from)", file=sys.stderr)
        sys.exit(1)
    try:
        import boto3
        from botocore.config import Config
    except ImportError:
        print("Install boto3 in the csound env: pip install boto3", file=sys.stderr)
        sys.exit(1)
    return boto3.client(
        "s3", endpoint_url=endpoint, region_name="auto",
        aws_access_key_id=key_id, aws_secret_access_key=secret,
        config=Config(signature_version="s3v4", retries={"max_attempts": 3}),
    )


def list_albums(bucket=None):
    """Every album in the bucket: {album: {"files": [...], "newest": datetime}}.

    An album is the first path component of a key; its files are the
    b<NNN>*.mp3 objects under it.  Objects at the bucket root — the flat
    uploads from before keys carried the album — are ignored: publish-album.sh
    left them for old tweets to link to, and they belong to no album.
    """
    bucket = bucket or os.environ.get("R2_BUCKET", DEFAULT_BUCKET)
    s3 = r2_client()
    albums = {}
    try:
        for page in s3.get_paginator("list_objects_v2").paginate(Bucket=bucket):
            for obj in page.get("Contents", []):
                album, _, fname = obj["Key"].partition("/")
                if not fname or "/" in fname or not BUCKET_FILE_RE.match(fname):
                    continue
                # LastModified is UTC; shown in local time, as the cron log is read.
                when = obj["LastModified"].astimezone()
                a = albums.setdefault(album, {"files": [], "newest": when})
                a["files"].append(fname)
                a["newest"] = max(a["newest"], when)
    except Exception as e:                       # botocore raises a zoo of these
        print(f"Could not list bucket {bucket}: {e}", file=sys.stderr)
        sys.exit(1)
    if not albums:
        print(f"No <album>/b<NNN>*.mp3 objects in bucket {bucket} "
              f"(renamed 9/24/26 — files published under the old ball9-t* scheme "
              f"are no longer matched)", file=sys.stderr)
        sys.exit(1)
    for a in albums.values():
        a["files"].sort()
    return albums


def latest_album(albums):
    """The album whose most recent upload is the most recent of all."""
    return max(albums, key=lambda a: albums[a]["newest"])


def check_url(url):
    """True if the object is there: HEAD 200 and served as audio.

    The User-Agent matters: Cloudflare answers 403 to Python's default
    "Python-urllib/3.x" on this host and 200 to anything else (curl, a
    made-up name).  Without the header every link would fail the check."""
    try:
        req = urllib.request.Request(url, method="HEAD",
                                     headers={"User-Agent": "daily_chorale_tweet/1.0"})
        with urllib.request.urlopen(req, timeout=20) as r:
            ctype = r.headers.get("Content-Type", "")
            if r.status == 200 and ctype.startswith("audio/"):
                return True
            print(f"Link check: HTTP {r.status}, content-type {ctype!r} — not posting", file=sys.stderr)
    except urllib.error.HTTPError as e:
        print(f"Link check: HTTP {e.code} for {url} — not posting", file=sys.stderr)
    except Exception as e:
        print(f"Link check failed: {e} — not posting", file=sys.stderr)
    return False


# ── State ──────────────────────────────────────────────────────────────────
def load_state():
    """Which files of which album have been posted.  A state file from before
    the R2 switch has 'mp3_dir' instead of 'album' and simply does not match,
    so the rotation restarts — on a new album, as it would anyway."""
    if os.path.exists(STATE_FILE):
        with open(STATE_FILE) as f:
            return json.load(f)
    return {"posted": [], "album": None}


def save_state(state):
    with open(STATE_FILE, "w") as f:
        json.dump(state, f, indent=2)


# ── Twitter ────────────────────────────────────────────────────────────────
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

    return tweepy.Client(
        consumer_key=api_key,
        consumer_secret=api_secret,
        access_token=access_token,
        access_token_secret=access_secret,
    )


def post_tweet(key, description, dry_run=False):
    """Post a text tweet with a link to the mp3 on R2."""
    tweet_text = description
    if len(tweet_text) > 280:
        tweet_text = tweet_text[:277] + "..."

    if dry_run:
        print("=== DRY RUN ===")
        print(f"Object: {key}")
        print(f"Tweet ({len(tweet_text)} chars):\n{tweet_text}")
        return True

    client = twitter_client()
    print(f"Posting tweet for {key} ...")
    response = client.create_tweet(text=tweet_text)
    tweet_id = response.data["id"]
    print(f"Posted: https://twitter.com/prentrodgers/status/{tweet_id}")
    return True


# ── Main ───────────────────────────────────────────────────────────────────
def main():
    import argparse

    parser = argparse.ArgumentParser(description="Post a daily chorale tweet from the newest album on R2",
                                     allow_abbrev=False)
    parser.add_argument("--dry-run", action="store_true",
                        help="Print what would be posted without actually tweeting")
    parser.add_argument("--list", action="store_true",
                        help="List the albums in the bucket, newest first, and exit")
    parser.add_argument("--album", default=None,
                        help="Post from this album (its key prefix in the bucket) instead of the newest")
    parser.add_argument("--base-url", default=BASE_URL,
                        help=f"Public host of the bucket (default: {BASE_URL})")
    parser.add_argument("--reset", action="store_true",
                        help="Forget what has been posted and start the rotation over")
    parser.add_argument("--no-check", action="store_true",
                        help="Skip the HEAD check of the link before posting")
    args = parser.parse_args()

    albums = list_albums()
    newest = latest_album(albums)

    if args.list:
        for name in sorted(albums, key=lambda a: albums[a]["newest"], reverse=True):
            a = albums[name]
            mark = "  <- newest" if name == newest else ""
            print(f"{a['newest']:%Y-%m-%d %H:%M}  {len(a['files']):>3} files  {name}{mark}")
        return

    album = args.album or newest
    if album not in albums:
        print(f"No album {album!r} in the bucket — --list shows what is there", file=sys.stderr)
        sys.exit(1)
    files = albums[album]["files"]
    print(f"Album: {album} ({len(files)} files, newest upload {albums[album]['newest']:%Y-%m-%d %H:%M})")

    state = load_state()
    if args.reset or state.get("album") != album:
        state = {"posted": [], "album": album}

    posted = set(state["posted"])
    remaining = [f for f in files if f not in posted]
    if not remaining:
        print("Completed full rotation, starting over.")
        state["posted"] = []
        remaining = files[:]

    fname = random.choice(remaining)
    key = f"{album}/{fname}"
    url = mp3_url(key, base_url=args.base_url)
    bwv, description = parse_filename(fname, url)

    if not args.no_check and not check_url(url):
        sys.exit(1)

    post_tweet(key, description, dry_run=args.dry_run)
    if args.dry_run:
        print(f"\n(dry run: state untouched; {len(remaining)} chorales remaining in rotation)")
        return
    state["posted"].append(fname)
    save_state(state)
    print(f"\n{len(remaining) - 1} chorales remaining in rotation.")


if __name__ == "__main__":
    main()
