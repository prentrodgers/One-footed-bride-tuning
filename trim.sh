#!/bin/bash
# set -v
# set +o pipefail # is this illegal?
# export SFDIR='/var/home/core/Music/sflib' # use this if running on CoreOS
export SFDIR='/home/prent/Music/sflib' # use this for Kubernetes
echo $SFDIR
# $1 ball9 
# $2 40o9_q05_r08_f1.00_c0538_a0.09_w0.28_d11:01_t100 
# $3 /home/prent/Dropbox/Tutorials/TonicNet
# $4 /home/prent/Dropbox/Uploads 
echo 'here are the values used in trim.sh'
echo $@
csound -U sndinfo $SFDIR/"$1".wav
csound "$3"/"$1"c.csd 
sox $SFDIR/"$1"a-c.wav -p reverse | sox -p -p silence 1 .01 .01 | sox -p -p reverse | sox -p -p silence 1 0.01 0.01 | sox -p $SFDIR/"$1"-t"$2".wav # trim the silence at the start and the end. Why two -p's?
csound -U sndinfo $SFDIR/"$1"-t"$2".wav
ls -lth $SFDIR/"$1"-t"$2".wav | head
if [ -z "$4" ]; then
  echo "\$4 is empty or not provided"
else
  sox $SFDIR/"$1"-t"$2".wav -C640 $SFDIR/"$1"-t"$2".mp3
  mv $SFDIR/"$1"-t"$2".mp3 $4
  # chown dropbox:dropbox "$4"/"$1"-t"$2".mp3 
  ls -lth "$4"/"$1"-t"$2".mp3
fi
