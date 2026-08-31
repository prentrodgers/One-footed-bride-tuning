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


def test_parse_filename_uses_https_for_mp3_links():
    mod = load_module()
    _, _, url = mod.parse_filename("ball9-t54c_lm17_r1.12_df1_t3_d05_32_t080.mp3")
    assert url.startswith("https://ripnread.com/listen/")
