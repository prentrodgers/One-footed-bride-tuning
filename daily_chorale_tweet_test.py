import importlib.util
import sys
import types


def load_module():
    tweepy = types.ModuleType("tweepy")
    tweepy.Client = object
    sys.modules["tweepy"] = tweepy
    spec = importlib.util.spec_from_file_location(
        "daily_chorale_tweet",
        "/home/prent/Repos/One-footed-bride-tuning/daily_chorale_tweet.py",
    )
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


NEW_NAME = "b424f_df0_t3_d04_08_t092_ap4_lm19_r1.25.mp3"
# --short_repeats renders carry no _ap token at all.
NEW_NAME_NO_AP = "b424f_df0_t3_d04_08_t092_lm19_r1.25.mp3"
OLD_NAME = "ball9-t54c_lm17_r1.12_df1_t3_d05_32_t080.mp3"


def test_mp3_url_uses_https_for_mp3_links():
    """mp3_url upgrades http to https. Asserted against an explicit base_url rather
    than the configured host, which has already moved once (the previous version of
    this test still expected ripnread.com and never ran to notice)."""
    mod = load_module()
    url = mod.mp3_url(f"2026-09/{NEW_NAME}", base_url="http://audio.example.test")
    assert url.startswith("https://audio.example.test/")
    assert url.endswith(NEW_NAME)
    assert mod.mp3_url(f"2026-09/{NEW_NAME}").startswith("https://")


def test_parse_filename_reads_the_new_scheme():
    mod = load_module()
    url = "https://example.test/x.mp3"
    bwv, desc = mod.parse_filename(NEW_NAME, url)
    assert bwv == "424"
    assert "BWV 424" in desc
    assert "19-limit" in desc          # lm now lives at the tail
    assert "4:08" in desc              # duration still parsed
    assert url in desc


def test_parse_filename_without_ap_tag():
    """_ap is absent on --short_repeats renders; the rest must still parse."""
    mod = load_module()
    bwv, desc = mod.parse_filename(NEW_NAME_NO_AP, "https://example.test/x.mp3")
    assert bwv == "424"
    assert "19-limit" in desc


def test_parse_filename_rejects_the_old_scheme():
    """Big-bang rename: old names are no longer understood, and say so plainly
    by falling back to the bare filename rather than mis-parsing."""
    mod = load_module()
    bwv, desc = mod.parse_filename(OLD_NAME, "https://example.test/x.mp3")
    assert bwv is None
    assert OLD_NAME in desc


def test_bucket_filter_is_anchored():
    """A bare startswith('b') would sweep up every object in the bucket."""
    mod = load_module()
    assert mod.BUCKET_FILE_RE.match(NEW_NAME)
    assert mod.BUCKET_FILE_RE.match(NEW_NAME_NO_AP)
    assert not mod.BUCKET_FILE_RE.match(OLD_NAME)
    assert not mod.BUCKET_FILE_RE.match("backup-of-something.mp3")
    assert not mod.BUCKET_FILE_RE.match("b42f_df0_t3.mp3")      # only 2 digits
