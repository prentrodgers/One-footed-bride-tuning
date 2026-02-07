#!/bin/bash
# set -v
# set +o pipefail # is this illegal?
export SFDIR='~/Music/sflib' # where to store the audio files.
echo $SFDIR
# $1 ball9 
# $2 40o9_q05_r08_f1.00_c0538_a0.09_w0.28_d11:01_t100 
# $3 ~/One-footed-bride-tuning
# $4 ~/One-footed-bride-tuning/Uploads 
echo 'here are the values used in trim.sh'
echo $@
csound -U sndinfo $SFDIR/"$1".wav
csound "$3"/"$1"c.csd 
sox $SFDIR/"$1"a-c.wav -p reverse | sox -p -p silence 1 .01 .01 | sox -p -p reverse | sox -p -p silence 1 0.01 0.01 | sox -p $SFDIR/"$1"-t"$2".wav 
csound -U sndinfo $SFDIR/"$1"-t"$2".wav
ls -lth $SFDIR/"$1"-t"$2".wav | head
if [ -z "$4" ]; then
  echo "\$4 is empty or not provided"
else
  sox $SFDIR/"$1"-t"$2".wav -C640 $SFDIR/"$1"-t"$2".mp3
  mv $SFDIR/"$1"-t"$2".mp3 $4
#   ls -lth "$4"/"$1"-t"$2".mp3
fi
