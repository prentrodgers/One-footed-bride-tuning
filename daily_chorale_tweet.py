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
    # 265-366 added 10 Nov 2026 (BWV 354-366 were tweeting as "Bach Chorale"), from the
    # rows of Wikipedia's list that link bach-chorales.com/BWV0NNN.htm (the site itself
    # refuses scripted fetches; the same parse matched 77 of the 85 entries already here,
    # the rest differing only in spelling). 283, 299, 325, 335, 339 and 343 are rowspan
    # rows, read by hand; where two texts share one setting the first is used, as for 267.
    "265": "Als Jesus Christus in der Nacht",
    "266": "Als vierzig Tag nach Ostern warn",
    "268": "Auf, auf, mein Herz, und du, mein ganzer Sinn",
    "269": "Aus meines Herzens Grunde",
    "270": "Befiehl du deine Wege",
    "271": "Befiehl du deine Wege",
    "272": "Befiehl du deine Wege",
    "273": "Christ, der du bist der helle Tag",
    "274": "Christe, der du bist Tag und Licht",
    "275": "Christe, du Beistand deiner Kreuzgemeine",
    "276": "Christ ist erstanden",
    "277": "Christ lag in Todesbanden",
    "278": "Christ lag in Todesbanden",
    "279": "Christ lag in Todesbanden",
    "280": "Christ unser Herr zum Jordan kam",
    "281": "Christus, der ist mein Leben",
    "282": "Christus, der ist mein Leben",
    "283": "Christus, der uns selig macht",
    "284": "Christus ist erstanden, hat überwunden",
    "285": "Da der Herr Christ zu Tische saß",
    "286": "Danket dem Herrn, denn er ist sehr freundlich",
    "287": "Dank sei Gott in der Höhe",
    "288": "Das alte Jahr vergangen ist",
    "289": "Das alte Jahr vergangen ist",
    "290": "Das walt Gott Vater und Gott Sohn",
    "291": "Das walt mein Gott",
    "292": "Den Vater dort oben",
    "293": "Der du bist drei in Einigkeit",
    "294": "Der Tag, der ist so freudenreich",
    "295": "Des Heilgen Geistes reiche Gnad",
    "296": "Die Nacht ist kommen",
    "297": "Die Sonn hat sich mit ihrem Glanz",
    "298": "Dies sind die heilgen zehn Gebot",
    "299": "Dir, dir, Jehova, will ich singen",
    "300": "Du großer Schmerzensmann",
    "301": "Du, o schönes Weltgebäude",
    "302": "Ein feste Burg ist unser Gott",
    "303": "Ein feste Burg ist unser Gott",
    "304": "Eins ist not, ach Herr, dies Eine",
    "305": "Erbarm dich mein, o Herre Gott",
    "306": "Erstanden ist der heilge Christ",
    "307": "Es ist gewißlich an der Zeit",
    "308": "Es spricht der Unweisen Mund wohl",
    "309": "Es stehn vor Gottes Throne",
    "310": "Es wird schier der letzte Tag herkommen",
    "311": "Es woll uns Gott genädig sein",
    "312": "Es woll uns Gott genädig sein",
    "313": "Für Freuden laßt uns springen",
    "314": "Gelobet seist du, Jesu Christ",
    "315": "Gib dich zufrieden und sei stille",
    "316": "Gott, der du selber bist das Licht",
    "317": "Gott der Vater wohn uns bei",
    "318": "Gottes Sohn ist kommen",
    "319": "Gott hat das Evangelium",
    "320": "Gott lebet noch",
    "321": "Gottlob, es geht nunmehr zu Ende",
    "322": "Gott sei gelobet und gebenedeiet",
    "323": "Gott sei uns gnädig und barmherzig",
    "324": "Meine Seele erhebet den Herren",
    "325": "Heilig, heilig",
    "326": "Herr Gott, dich loben alle wir",
    "327": "Vor deinen Thron tret ich hiermit",
    "328": "Herr Gott, dich loben wir",
    "329": "Herr, ich denk an jene Zeit",
    "330": "Herr, ich habe mißgehandelt",
    "331": "Herr, ich habe mißgehandelt",
    "332": "Herr Jesu Christ, dich zu uns wend",
    "333": "Herr Jesu Christ, du hast bereit'",
    "334": "Herr Jesu Christ, du höchstes Gut",
    "335": "Herr Jesu Christ, meins Lebens Licht",
    "336": "Herr Jesu Christ, wahr Mensch und Gott",
    "337": "Herr, nun laß in Friede",
    "338": "Herr, straf mich nicht in deinem Zorn",
    "339": "Wer in dem Schutz des Höchsten ist",
    "340": "Herzlich lieb hab ich dich, o Herr",
    "341": "Heut ist, o Mensch, ein großer Trauertag",
    "342": "Heut triumphieret Gottes Sohn",
    "343": "Hilf, Gott, daß mirs gelinge",
    "344": "Hilf, Herr Jesu, laß gelingen",
    "345": "Ich bin ja, Herr, in deiner Macht",
    "346": "Ich dank dir, Gott, für all Wohltat",
    "347": "Ich dank dir, lieber Herre",
    "348": "Ich dank dir, lieber Herre",
    "349": "Ich dank dir schon durch deinen Sohn",
    "350": "Ich danke dir, o Gott, in deinem Throne",
    "351": "Ich hab mein Sach Gott heimgestellt",
    "352": "Jesu, der du meine Seele",
    "353": "Jesu, der du meine Seele",
    "354": "Jesu, der du meine Seele",
    "355": "Jesu, der du selbsten wohl",
    "356": "Jesu, du mein liebstes Leben",
    "357": "Jesu, Jesu, du bist mein",
    "358": "Jesu, meine Freude",
    "359": "Jesu meiner Seelen Wonne",
    "360": "Jesu, meiner Seelen Wonne",
    "361": "Jesu, meines Herzens Freud",
    "362": "Jesu, nun sei gepreiset",
    "363": "Jesus Christus, unser Heiland, der von uns den Gotteszorn wandt",
    "364": "Jesus Christus, unser Heiland, der den Tod überwand",
    "365": "Jesus, meine Zuversicht",
    "366": "Ihr Gestirn, ihr hohlen Lüfte",
    # 267 and 415-438, checked against bach-chorales.com on 19 Sep 2026
    "267": "An Wasserflüssen Babylon",
    # 367-378 added 25 Oct 2026, each checked against bach-chorales.com/BWV0NNN.htm.
    # Wikipedia's list read one row off here (it put 378's title on 379), so these
    # came from the per-BWV pages, worded as Wikipedia words them.
    "367": "In allen meinen Taten",
    "368": "In dulci jubilo",
    "369": "Keinen hat Gott verlassen",
    "370": "Komm, Gott Schöpfer, Heiliger Geist",
    "371": "Kyrie, Gott Vater in Ewigkeit",
    "372": "Lass, o Herr, dein Ohr sich neigen",
    "373": "Liebster Jesu, wir sind hier",
    "374": "Lobet den Herren, denn er ist sehr freundlich",
    "375": "Lobt Gott, ihr Christen, allzugleich",
    "376": "Lobt Gott, ihr Christen, allzugleich",
    "377": "Machs mit mir, Gott, nach deiner Güt",
    "378": "Mein Augen schließ ich jetzt",
    # 379-414 added 21 Oct 2026 (BWV 413 was tweeting as "Bach Chorale"), from the
    # rows of Wikipedia's "List of chorale harmonisations by J. S. Bach" that link
    # bach-chorales.com/BWV0NNN.htm; the same parse matched 33 of the entries above
    # exactly and the other 4 up to spelling, so the numbering is not shifted.
    # 379 and 380 are two melodies to one hymn; the last word tells them apart.
    "379": "Meinen Jesum laß ich nicht, Jesus",
    "380": "Meinen Jesum laß ich nicht, weil",
    "381": "Meines Lebens letzte Zeit",
    "382": "Mit Fried und Freud ich fahr dahin",
    "383": "Mitten wir im Leben sind",
    "384": "Nicht so traurig, nicht so sehr",
    "385": "Nun bitten wir den Heiligen Geist",
    "386": "Nun danket alle Gott",
    "387": "Nun freut euch, Gottes Kinder all",
    "388": "Nun freut euch, lieben Christen g'mein",
    "389": "Nun lob, mein Seel, den Herren",
    "390": "Nun lob, mein Seel, den Herren",
    "391": "Nun preiset alle Gottes Barmherzigkeit",
    "392": "Nun ruhen alle Wälder",
    "393": "O Welt, sieh hier dein Leben",
    "394": "O Welt, sieh hier dein Leben",
    "395": "O Welt, sieh hier dein Leben",
    "396": "Nun sich der Tag geendet hat",
    "397": "O Ewigkeit, du Donnerwort",
    "398": "O Gott, du frommer Gott",
    "399": "O Gott, du frommer Gott",
    "400": "O Herzensangst, o Bangigkeit",
    "401": "O Lamm Gottes, unschuldig",
    "402": "O Mensch, bewein dein Sünde groß",
    "403": "O Mensch, schau Jesum Christum an",
    "404": "O Traurigkeit, o Herzeleid",
    "405": "O wie selig seid ihr doch, ihr Frommen",
    "406": "O wie selig seid ihr doch, ihr Frommen",
    "407": "O wir armen Sünder",
    "408": "Schaut, ihr Sünder",
    "409": "Seelenbräutigam",
    "410": "Sei gegrüßet, Jesu gütig",
    "411": "Singt dem Herrn ein neues Lied",
    "412": "So gibst du nun, mein Jesu, gute Nacht",
    "413": "Sollt ich meinem Gott nicht singen",
    "414": "Uns ist ein Kindlein heut geborn",
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

# Chorales inside the cantatas, passions and oratorios: "<work>.<movement>", as
# music21 names them (bwv244.10 = St Matthew Passion no. 10) and WreckingCrew_v2.py
# writes them (b244.10a_...). From the same Wikipedia list, keyed by each row's
# bach-chorales.com/BWV0WWW_M.htm link, 10 Nov 2026.
BWV_TITLES.update({
    "1.6": "Wie schön leuchtet der Morgenstern",
    "2.6": "Ach Gott, vom Himmel sieh darein",
    "3.6": "Ach Gott, wie manches Herzeleid",
    "4.8": "Christ lag in Todesbanden",
    "5.7": "Wo soll ich fliehen hin",
    "6.6": "Erhalt uns, Herr, bei deinem Wort",
    "7.7": "Christ unser Herr zum Jordan kam",
    "8.6": "Liebster Gott, wenn werd ich sterben",
    "9.7": "Es ist das Heil uns kommen her",
    "10.7": "Meine Seele erhebt den Herren",
    "11.6": "Du Lebensfürst, Herr Jesu Christ",
    "12.7": "Was Gott tut, das ist wohlgetan",
    "13.6": "In allen meinen Taten",
    "14.5": "Wär Gott nicht mit uns diese Zeit",
    "16.6": "Helft mir Gotts Güte preisen",
    "17.7": "Nun lob, mein Seel, den Herren",
    "18.5": "Durch Adams Fall ist ganz verderbt",
    "19.7": "Freu dich sehr, o meine Seele",
    "22.5": "Herr Christ, der einge Gottessohn",
    "24.6": "O Gott, du frommer Gott",
    "25.6": "Treuer Gott, ich muss dir klagen",
    "26.6": "Ach wie flüchtig, ach wie nichtig",
    "27.6": "Welt, ade! Ich bin dein müde",
    "28.6": "Helft mir Gotts Güte preisen",
    "29.8": "Nun lob, mein Seel, den Herren",
    "30.6": "Tröstet, tröstet meine Lieben",
    "31.9": "Wenn mein Stündlein vorhanden ist",
    "32.6": "Weg, mein Herz, mit den Gedanken",
    "33.6": "Allein zu dir, Herr Jesu Christ",
    "36.4": "Wie schön leuchtet der Morgenstern",
    "36.8": "Nun komm, der Heiden Heiland",
    "37.6": "Ich dank dir, lieber Herre",
    "38.6": "Aus tiefer Not schrei ich zu dir",
    "39.7": "Kommt, laßt euch den Herren lehren",
    "40.3": "Wir Christenleut habn jetzund Freud",
    "40.6": "Schwing dich auf zu deinem Gott",
    "40.8": "Freuet euch, ihr Christen alle",
    "41.6": "Jesu, nun sei gepreiset",
    "42.7": "Verleih uns Frieden gnädlich",
    "43.11": "Du Lebensfürst, Herr Jesu Christ",
    "44.7": "In allen meinen Taten",
    "45.7": "O Gott, du frommer Gott",
    "46.6": "O großer Gott von Macht",
    "47.5": "Warum betrübst du dich, mein Herz",
    "48.3": "Ach Gott und Herr",
    "48.7": "Herr Jesu Christ, ich schrei zu dir",
    "52.6": "In dich hab ich gehoffet, Herr",
    "55.5": "Werde munter, mein Gemüte",
    "56.5": "Du, o schönes Weltgebäude",
    "57.8": "Hast du denn, Jesu, dein Angesicht",
    "59.3": "Komm, Heiliger Geist, Herre Gott",
    "60.5": "Es ist genug",
    "62.6": "Nun komm, der Heiden Heiland",
    "64.2": "Gelobet seist du, Jesu Christ",
    "64.4": "Was frag ich nach der Welt",
    "64.8": "Jesu, meine Freude",
    "65.2": "Ein Kind geborn zu Bethlehem",
    "65.7": "Ich hab in Gottes Herz und Sinn",
    "66.6": "Christ ist erstanden",
    "67.4": "Erschienen ist der herrlich Tag",
    "67.7": "Du Friedefürst, Herr Jesu Christ",
    "69.6": "Es woll uns Gott genädig sein",
    "70.7": "Freu dich sehr, o meine Seele",
    "70.11": "Meinen Jesum laß ich nicht",
    "72.6": "Was mein Gott will, das g'scheh allzeit",
    "73.5": "Von Gott will ich nicht lassen",
    "74.8": "Gott Vater, sende deinen Geist",
    "77.6": "Wenn einer alle Ding verstünd",
    "78.7": "Jesu, der du meine Seele",
    "79.3": "Nun danket alle Gott",
    "79.6": "Nun laßt uns Gott dem Herren",
    "80.8": "Ein feste Burg ist unser Gott",
    "81.7": "Jesu, meine Freude",
    "83.5": "Mit Fried und Freud ich fahr dahin",
    "84.5": "Wer weiß, wie nahe mir mein Ende",
    "85.6": "Ist Gott mein Schild und Helfersmann",
    "86.6": "Es ist das Heil uns kommen her",
    "87.7": "Selig ist die Seele",
    "88.7": "Wer nur den lieben Gott läßt walten",
    "89.6": "Wo soll ich fliehen hin",
    "90.5": "Nimm von uns, Herr, du treuer Gott",
    "91.6": "Gelobet seist du, Jesu Christ",
    "92.9": "Ich hab in Gottes Herz und Sinn",
    "93.7": "Wer nur den lieben Gott läßt walten",
    "94.8": "Was frag ich nach der Welt",
    "95.7": "Wenn mein Stündlein vorhanden ist",
    "96.6": "Herr Christ, der einge Gottessohn",
    "97.9": "In allen meinen Taten",
    "99.6": "Was Gott tut, das ist wohlgetan",
    "100.6": "Was Gott tut, das ist wohlgetan",
    "101.7": "Nimm von uns, Herr, du treuer Gott",
    "102.7": "So wahr ich lebe, spricht dein Gott",
    "103.6": "Barmherzger Vater, höchster Gott",
    "104.6": "Der Herr ist mein getreuer Hirt",
    "105.6": "Jesu, der du meine Seele",
    "107.7": "Was willst du dich betrüben",
    "108.6": "Gott Vater, sende deinen Geist",
    "110.7": "Wir Christenleut habn jetzund Freud",
    "111.6": "Was mein Gott will, das g'scheh allzeit",
    "112.5": "Der Herr ist mein getreuer Hirt",
    "113.1": "Herr Jesu Christ, du höchstes Gut",
    "113.8": "Herr Jesu Christ, du höchstes Gut",
    "114.7": "Ach lieben Christen, seid getrost",
    "115.6": "Mache dich, mein Geist, bereit",
    "116.6": "Du Friedefürst, Herr Jesu Christ",
    "119.9": "Herr Gott, dich loben wir",
    "120.6": "Herr Gott, dich loben wir",
    "121.6": "Christum wir sollen loben schon",
    "122.6": "Das neugeborne Kindelein",
    "123.6": "Liebster Immanuel, Herzog der Frommen",
    "124.6": "Meinen Jesum laß ich nicht, weil",
    "125.6": "Mit Fried und Freud ich fahr dahin",
    "126.6": "Verleih uns Frieden gnädlich",
    "127.5": "Herr Jesu Christ, wahr Mensch und Gott",
    "128.5": "O Jesu, meine Lust",
    "129.5": "Gelobet sei der Herr, mein Gott",
    "130.6": "Herr Gott, dich loben alle wir",
    "133.6": "Ich freue mich in dir",
    "135.6": "Ach Herr, mich armen Sünder",
    "136.6": "Wo soll ich fliehen hin",
    "137.5": "Lobe den Herren, den mächtigen König der Ehren",
    "139.6": "Wohl dem, der sich auf seinen Gott",
    "140.7": "Wachet auf, ruft uns die Stimme",
    "144.3": "Was Gott tut, das ist wohlgetan",
    "144.6": "Was mein Gott will, das g'scheh allzeit",
    "145.5": "Erschienen ist der herrlich Tag",
    "146.8": "Freu dich sehr, o meine Seele",
    "148.6": "Wo soll ich fliehen hin",
    "149.7": "Herzlich lieb hab ich dich, o Herr",
    "151.5": "Lobt Gott, ihr Christen, allzugleich",
    "153.1": "Schau, lieber Gott, wie meine Feind",
    "153.5": "Befiehl du deine Wege",
    "153.9": "Ach Gott, wie manches Herzeleid",
    "154.3": "Jesu, meiner Seelen Wonne",
    "154.8": "Meinen Jesum laß ich nicht, weil",
    "155.5": "Es ist das Heil uns kommen her",
    "156.6": "Herr, wie du willst, so schicks mit mir",
    "157.5": "Meinen Jesum laß ich nicht, weil",
    "158.4": "Christ lag in Todesbanden",
    "159.5": "Jesu Leiden, Pein und Tod",
    "161.6": "Herzlich tut mich verlangen",
    "162.6": "Alle Menschen müssen sterben",
    "164.6": "Herr Christ, der einge Gottessohn",
    "165.6": "Nun laßt uns Gott dem Herren",
    "166.6": "Wer weiß, wie nahe mir mein Ende",
    "167.5": "Nun lob, mein Seel, den Herren",
    "168.6": "Herr Jesu Christ, du höchstes Gut",
    "169.7": "Nun bitten wir den Heiligen Geist",
    "171.6": "Jesu, nun sei gepreiset",
    "172.6": "Wie schön leuchtet der Morgenstern",
    "174.5": "Herzlich lieb hab ich dich, o Herr",
    "175.7": "O Gottes Geist, mein Trost und Rat",
    "176.6": "Was alle Weisheit in der Welt",
    "177.5": "Ich ruf zu dir, Herr Jesu Christ",
    "178.7": "Wo Gott der Herr nicht bei uns hält",
    "179.6": "Ich armer Mensch, ich armer Sünder",
    "180.7": "Schmücke dich, o liebe Seele",
    "183.5": "Zeuch ein zu deinen Toren",
    "184.5": "O Herre Gott, dein göttlich Wort",
    "185.6": "Ich ruf zu dir, Herr Jesu Christ",
    "187.7": "Singen wir aus Herzensgrund",
    "188.6": "Auf meinen lieben Gott",
    "190.7": "Jesu, nun sei gepreiset",
    "194.6": "Treuer Gott, ich muss dir klagen",
    "194.12": "Wach auf, mein Herz, und singe",
    "195.6": "Nun danket all und bringet Ehr",
    "197.5": "Nun bitten wir den Heiligen Geist",
    "197.10": "Wer nur den lieben Gott läßt walten",
    "226.2": "Komm, Heiliger Geist, Herre Gott",
    "227.3": "Jesu, meine Freude",
    "227.7": "Jesu, meine Freude",
    "229.2": "Komm, Jesu, komm",
    "244.3": "Herzliebster Jesu",
    "244.10": "O Welt, sieh hier dein Leben",
    "244.15": "O Haupt voll Blut und Wunden",
    "244.17": "O Haupt voll Blut und Wunden",
    "244.25": "Was mein Gott will, das g'scheh allzeit",
    "244.32": "In dich hab ich gehoffet, Herr",
    "244.37": "O Welt, sieh hier dein Leben",
    "244.40": "Werde munter, mein Gemüte",
    "244.44": "Befiehl du deine Wege",
    "244.46": "Herzliebster Jesu",
    "244.54": "O Haupt voll Blut und Wunden",
    "244.62": "O Haupt voll Blut und Wunden",
    "245.3": "Herzliebster Jesu",
    "245.5": "Vater unser im Himmelreich",
    "245.11": "O Welt, sieh hier dein Leben",
    "245.14": "Jesu Leiden, Pein und Tod",
    "245.15": "Christus, der uns selig macht",
    "245.17": "Herzliebster Jesu",
    "245.22": "Durch dein Gefängnis, Gottes Sohn",
    "245.26": "Valet will ich dir geben",
    "245.28": "Jesu Leiden, Pein und Tod",
    "245.37": "Christus, der uns selig macht",
    "245.40": "Herzlich lieb hab ich dich, o Herr",
    "248.5": "Wie soll ich dich empfangen",
    "248.9": "Vom Himmel hoch, da komm ich her",
    "248.12": "Ermuntre dich, mein schwacher Geist",
    "248.17": "Schaut, schaut, was ist für Wunder dar",
    "248.23": "Wir singen dir, Immanuel",
    "248.28": "Gelobet seist du, Jesu Christ",
    "248.33": "Fröhlich soll mein Herze springen",
    "248.35": "Lasst Furcht und Pein",
    "248.42": "Hilf, Herr Jesu, laß gelingen",
    "248.46": "Nun, liebe Seel, nun ist es Zeit",
    "248.53": "Ihr Gestirn, ihr hohlen Lüfte",
    "248.59": "Ich steh an deiner Krippen hier",
    "248.64": "Ihr Christen, auserkoren",
})
# not chorales, but rendered note for note by WreckingCrew_v2.py
BWV_TITLES["846"] = "Prelude in C major, The Well-Tempered Clavier I"

# Filename pattern (renamed 9/24/26; everything before that is the old
# ball9-t53a_lm23_r1.50_..._t110.mp3 scheme, which this no longer reads):
#   b424f_df0_t3_d04_08_t092_ap4_lm19_r1.25.mp3
#
# Abbreviations:
#   b        = the rendered chorale (Csound orchestra ball9.csd)
#   424f     = BWV 424, variant f — the number in full (3 or 4 digits, so 433 and
#              233 cannot collide; 244.10f for a chorale inside a larger work)
#   df0      = density level: higher is denser (4-5), lower is sparser (0-1)
#   df4c3214 = a chaconne render: density 4, then c + each chaconne copy's level
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
    # BWV number: three or four digits (b354, b1048), or a chorale inside a larger
    # work as <work>.<movement> (b244.10 = St Matthew Passion no. 10, b2.6) -- then
    # the variant letter
    r"b(\d{1,4}\.\d{1,2}|\d{3,4})([A-Za-z]?)_"
    r"(?:(?:md|df)(\d+)"              # detail value (legacy md max-delta / newer df density-level);
    r"(?:c\d+)?_)?"                   # chaconne copies' levels (df4c3214); WreckingCrew_v2.py writes none
    r"t(\d+)_"                        # tolerance
    r"d(\d+)_(\d+)_"                  # duration mm_ss
    r"t(\d+)"                         # tempo
    r"(?:_ap(\d+))?"                  # repeat pattern (absent on --short_repeats)
    r"_lm(\d+)"                       # limit
    r"_r([\d.]+)"                     # ratio factor
    r"\.mp3$"
)

# Which bucket objects are ours.  The prefix is now a single "b", so a bare
# startswith("b") would sweep up anything at all — anchor on b + a BWV number
# (three or four digits, or <work>.<movement>).
BUCKET_FILE_RE = re.compile(r"^b(?:\d{1,4}\.\d{1,2}|\d{3,4})[A-Za-z]?_.*\.mp3$")


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
    # The BWV number is written out in full, so no hundreds digit to infer.
    title = BWV_TITLES.get(bwv)
    if title is None:
        # loud in the log: a missing title tweets as "Bach Chorale" (BWV 354-366, Nov 2026)
        print(f"WARNING: no title for BWV {bwv} in BWV_TITLES; tweeting it as \"Bach Chorale\"")
        title = "Bach Chorale"
    shown = bwv.replace(".", "/")                     # 244.10 is written BWV 244/10

    desc = (
        f"Bach BWV {shown} – \"{title}\"\n"
        f"{limit}-limit just intonation (tonality diamond).\n"
        f"{int(dur_m)}:{dur_s} at {int(tempo)} BPM.\n"   # t092 in the name, 92 in the tweet
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
