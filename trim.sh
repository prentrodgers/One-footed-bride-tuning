#!/bin/bash
# set -v
# set +o pipefail # is this illegal?
export SFDIR='Music/sflib' # where to store the audio files.
echo $SFDIR
# $1 ball9
# $2 424f_df0_t3_d04_08_t092_ap4_lm19_r1.25
# $3 ~/One-footed-bride-tuning
# $4 ~/One-footed-bride-tuning/Uploads
# 9/24/26: the output is now b<$2>, was <$1>-t<$2> (i.e. ball9-t...). Note $1 still names
# the INPUT orchestra files — ball9.wav, ball9c.csd, ball9a-c.wav — which are unchanged;
# only the rendered wav/mp3 that gets published is renamed.
OUT="b$2"
# NORM_DB: the peak the mix is normalised to, in dB below full scale (default -1, about 29,200 of
# 32,767). WreckingCrew_v2.py --level_by_velocity / --peak_db set it so a quiet piece stays quieter.
echo 'here are the values used in trim.sh'
echo $@
csound -U sndinfo $SFDIR/"$1".wav
csound "$3"/"$1"c.csd 
# Trim the silence at each end, then normalise. TRIM_DB is the trim threshold in dB below the peak
# (default -60): the mix is first brought to full scale, so a quiet render (--velocity 64) is trimmed
# at the same point as a loud one. Until 22 Nov 2026 the threshold was a fixed 0.01 of full scale,
# only 10 dB under the peak of a velocity-58 prelude: it cut into the first note and dropped the
# last 4.6 s of the hall's decay.
sox $SFDIR/"$1"a-c.wav -p gain -n | sox -p -p reverse | sox -p -p silence 1 0.01 ${TRIM_DB:--60}d | sox -p -p reverse | sox -p -p silence 1 0.01 ${TRIM_DB:--60}d | sox -p --norm=${NORM_DB:--1} $SFDIR/"$OUT".wav
csound -U sndinfo $SFDIR/"$OUT".wav
ls -lth $SFDIR/"$OUT".wav | head
if [ -z "$4" ]; then
  echo "\$4 is empty or not provided"
else
  sox $SFDIR/"$OUT".wav -C640 $SFDIR/"$OUT".mp3
  mv $SFDIR/"$OUT".mp3 $4
#   ls -lth "$4"/"$OUT".mp3
fi
