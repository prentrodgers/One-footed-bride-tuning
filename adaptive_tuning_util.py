"""
adaptive_tuning_util.py — Internal copy
This file is an internal repository copy of the project's adaptive tuning utilities.
Author: Prent Rodgers (project owner).
Date: 2026-02-03
"""

from . import diamond_music_utils as dmu
import numpy as np
from fractions import Fraction
rng = np.random.default_rng()
from functools import cache
import os
import threading
import math
import multiprocessing as mp
import music21 as m21
import logging
from collections import defaultdict
from itertools import count, combinations, permutations


def set_accidentals(flats):
    if flats:
        keys = np.array(['C♮', 'D♭', 'D♮', 'E♭', 'E♮', 'F♮', 'G♭', 'G♮', 'A♭', 'A♮', 'B♭', 'B♮'])
    else:
        keys = np.array(['C♮', 'C♯', 'D♮', 'D♯', 'E♮', 'F♮', 'F♯', 'G♮', 'G♯', 'A♮', 'A♯', 'B♮'])
    return keys

def windows_compliant_filename(filename):
    replacements = {
        ":": "_",
        "?": "",
        "/": "-"
    }
    for char, replacement in replacements.items():
        filename = filename.replace(char, replacement)
    return filename

# this is a dictionary of all the instruments that will be used in the piece. It keeps track of their names, what voice number in the csound input file to use for the instrument, time_tracker_number, which stores the total duration of all the notes added to the instrument so far, volume_factor, which increases the volume of all notes by a fixed amount, the minimum and maximum octaves to limit the octaves used. It has no relationship to the use of sections in the WreckingCrew.ipynb. 

# "time_tracker_number" value is reset at the end of the function to consecutive numbers 0-n
def init_voice_time():
      voice_time = { 
            "fing1": {"full_name": "finger piano 1", "start": 0, "csound_voice": 1,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 2, "max_oct": 7},
            "fing2": {"full_name": "finger piano 2", "start": 0, "csound_voice": 1,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 2, "max_oct": 7},
            "fing3": {"full_name": "finger piano 3", "start": 0, "csound_voice": 1,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 2, "max_oct": 7},
            "bfin1": {"full_name": "bass finger piano 1", "start": 0, "csound_voice": 24,"time_tracker_number": 0,  "volume_factor": 1, "min_oct": 1, "max_oct": 5},
            "fing4": {"full_name": "finger piano 4", "start": 0, "csound_voice": 1,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 2, "max_oct": 7},
            "fing5": {"full_name": "finger piano 5", "start": 0, "csound_voice": 1,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 2, "max_oct": 7},
            "fing6": {"full_name": "finger piano 6", "start": 0, "csound_voice": 1,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 2, "max_oct": 7},
            "fing7": {"full_name": "finger piano 7", "start": 0, "csound_voice": 1,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 2, "max_oct": 7},
            "fing8": {"full_name": "finger piano 8", "start": 0, "csound_voice": 1,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 2, "max_oct": 7},
            "fing9": {"full_name": "finger piano 9", "start": 0, "csound_voice": 1,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 2, "max_oct": 7},
            "fing10": {"full_name": "finger piano 10", "start": 0, "csound_voice": 1,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 2, "max_oct": 7},
            "fing11": {"full_name": "finger piano 11", "start": 0, "csound_voice": 1,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 2, "max_oct": 7},
            "fing12": {"full_name": "finger piano 12", "start": 0, "csound_voice": 1,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 2, "max_oct": 7},
            "fing13": {"full_name": "finger piano 13", "start": 0, "csound_voice": 1,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 2, "max_oct": 7},
            "fing14": {"full_name": "finger piano 14", "start": 0, "csound_voice": 1,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 2, "max_oct": 7},
            "fing15": {"full_name": "finger piano 15", "start": 0, "csound_voice": 1,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 2, "max_oct": 7},
            "fing16": {"full_name": "finger piano 16", "start": 0, "csound_voice": 1,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 2, "max_oct": 7},
            
            "bfin2": {"full_name": "bass finger piano 2", "start": 0, "csound_voice": 24,"time_tracker_number": 0,  "volume_factor": 1, "min_oct": 1, "max_oct": 5},

            "vlip1": {"full_name": "violin pizzicato1", "start": 0, "csound_voice": 2,"time_tracker_number": 0,  "volume_factor": 1, "min_oct": 3, "max_oct": 7},
            "vlip2": {"full_name": "violin pizzicato2", "start": 0, "csound_voice": 2,"time_tracker_number": 0,  "volume_factor": 1, "min_oct": 3, "max_oct": 7},
            "vlap1": {"full_name": "viola pizzicato1", "start": 0, "csound_voice": 3,"time_tracker_number": 0,  "volume_factor": 1, "min_oct": 2, "max_oct": 6},
            "celp1": {"full_name": "cello pizzicato1", "start": 0, "csound_voice": 4,"time_tracker_number": 0,  "volume_factor": 1, "min_oct": 1, "max_oct": 5},
            "vlip3": {"full_name": "violin pizzicato3", "start": 0, "csound_voice": 2,"time_tracker_number": 0,  "volume_factor": 1, "min_oct": 3, "max_oct": 7},
            "vlip4": {"full_name": "violin pizzicato4", "start": 0, "csound_voice": 2,"time_tracker_number": 0,  "volume_factor": 1, "min_oct": 3, "max_oct": 7},
            "vlap2": {"full_name": "viola pizzicato2", "start": 0, "csound_voice": 3,"time_tracker_number": 0,  "volume_factor": 1, "min_oct": 2, "max_oct": 6},
            "celp2": {"full_name": "cello pizzicato2", "start": 0, "csound_voice": 4,"time_tracker_number": 0,  "volume_factor": 1, "min_oct": 1, "max_oct": 5},

            "mari1": {"full_name": "marimba1", "start": 0, "csound_voice": 5,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 3, "max_oct": 7},
            "mari2": {"full_name": "marimba2", "start": 0, "csound_voice": 5,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 3, "max_oct": 7},
            "mari3": {"full_name": "marimba3", "start": 0, "csound_voice": 5,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 3, "max_oct": 7},
            "mari4": {"full_name": "marimba4", "start": 0, "csound_voice": 5,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 3, "max_oct": 7},
            "mari5": {"full_name": "marimba5", "start": 0, "csound_voice": 5,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 3, "max_oct": 7},
            "mari6": {"full_name": "marimba6", "start": 0, "csound_voice": 5,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 3, "max_oct": 7},
            "mari7": {"full_name": "marimba7", "start": 0, "csound_voice": 5,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 3, "max_oct": 7},
            "mari8": {"full_name": "marimba8", "start": 0, "csound_voice": 5,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 3, "max_oct": 7},
            
            "xylp1": {"full_name": "xylophone1", "start": 0, "csound_voice": 6,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 4, "max_oct": 7},
            "vibp1": {"full_name": "vibraphone1", "start": 0, "csound_voice": 7,"time_tracker_number": 0,  "volume_factor": 1, "min_oct": 4, "max_oct": 7},
            "harp1": {"full_name": "harp1", "start": 0, "csound_voice": 8,"time_tracker_number": 0,  "volume_factor": 2, "min_oct": 2, "max_oct": 7},

            "bgui1": {"full_name": "baritone guitar1", "start": 0, "csound_voice": 20,"time_tracker_number": 0,  "volume_factor": 1, "min_oct": 1, "max_oct": 6},
            "ebss1": {"full_name": "Ernie Ball Super Slinky1", "start": 0, "csound_voice": 21,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 1, "max_oct": 6},
            "ebss2": {"full_name": "Ernie Ball Super Slinky2", "start": 0, "csound_voice": 21,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 1, "max_oct": 6},
            "ebss3": {"full_name": "Ernie Ball Super Slinky3", "start": 0, "csound_voice": 21,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 1, "max_oct": 6},
            "ebss4": {"full_name": "Ernie Ball Super Slinky4", "start": 0, "csound_voice": 21,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 1, "max_oct": 6},
            "ebss5": {"full_name": "Ernie Ball Super Slinky5", "start": 0, "csound_voice": 21,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 1, "max_oct": 6},
            "ebss6": {"full_name": "Ernie Ball Super Slinky6", "start": 0, "csound_voice": 21,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 1, "max_oct": 6},
            "ebss7": {"full_name": "Ernie Ball Super Slinky7", "start": 0, "csound_voice": 21,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 1, "max_oct": 6},
            "ebss8": {"full_name": "Ernie Ball Super Slinky8", "start": 0, "csound_voice": 21,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 1, "max_oct": 6},
            "long1": {"full_name": "long string1", "start": 0, "csound_voice": 22,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 1, "max_oct": 7},
            "stri1": {"full_name": "original string1", "start": 0, "csound_voice": 23,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 1, "max_oct": 7},
            "stri2": {"full_name": "original string2", "start": 0, "csound_voice": 23,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 1, "max_oct": 7},
            "stri3": {"full_name": "original string3", "start": 0, "csound_voice": 23,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 1, "max_oct": 7},
            "stri4": {"full_name": "original string4", "start": 0, "csound_voice": 23,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 1, "max_oct": 7},
            "stri5": {"full_name": "original string5", "start": 0, "csound_voice": 23,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 1, "max_oct": 7},
            "stri6": {"full_name": "original string6", "start": 0, "csound_voice": 23,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 1, "max_oct": 7},
            "stri7": {"full_name": "original string7", "start": 0, "csound_voice": 23,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 1, "max_oct": 7},
            "stri8": {"full_name": "original string8", "start": 0, "csound_voice": 23,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 1, "max_oct": 7},
            
            "vlim1": {"full_name": "violin martele1", "start": 0, "csound_voice": 9,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 3, "max_oct": 6},
            "vlim2": {"full_name": "violin martele2", "start": 0, "csound_voice": 9,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 3, "max_oct": 6},
            "vlim3": {"full_name": "violin martele3", "start": 0, "csound_voice": 9,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 3, "max_oct": 6},
            "vlim4": {"full_name": "violin martele4", "start": 0, "csound_voice": 9,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 3, "max_oct": 6},
            "vlam1": {"full_name": "viola martele1", "start": 0, "csound_voice": 10,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 3, "max_oct": 5},
            "vlam2": {"full_name": "viola martele2", "start": 0, "csound_voice": 10,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 2, "max_oct": 5},
            "celm1": {"full_name": "cello martele1", "start": 0, "csound_voice": 11,"time_tracker_number": -1,  "volume_factor": 0, "min_oct": 2, "max_oct": 5},
            "celm2": {"full_name": "cello martele2", "start": 0, "csound_voice": 11,"time_tracker_number": -1,  "volume_factor": 0, "min_oct": 2, "max_oct": 5},

            "clar1": {"full_name": "clarinet1", "start": 0, "csound_voice": 13,"time_tracker_number": 0,  "volume_factor": -1, "min_oct": 3, "max_oct": 6},
            "clar2": {"full_name": "clarinet2", "start": 0, "csound_voice": 13,"time_tracker_number": 0,  "volume_factor": -1, "min_oct": 3, "max_oct": 6},
            "flut1": {"full_name": "flute1", "start": 0, "csound_voice": 14,"time_tracker_number": 0,  "volume_factor": 2, "min_oct": 3, "max_oct": 6},
            "flut2": {"full_name": "flute2", "start": 0, "csound_voice": 14,"time_tracker_number": 0,  "volume_factor": 2, "min_oct": 3, "max_oct": 6},
            "oboe1": {"full_name": "oboe1", "start": 0, "csound_voice": 15,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 3, "max_oct": 6},
            "oboe2": {"full_name": "oboe2", "start": 0, "csound_voice": 15,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 3, "max_oct": 6},
            "frnh1": {"full_name": "french horn1", "start": 0, "csound_voice": 16,"time_tracker_number": 0,  "volume_factor": 1, "min_oct": 1, "max_oct": 5},
            "frnh2": {"full_name": "french horn2", "start": 0, "csound_voice": 16,"time_tracker_number": 0,  "volume_factor": 1, "min_oct": 1, "max_oct": 5},
            "basn1": {"full_name": "bassoon1", "start": 0, "csound_voice": 12,"time_tracker_number": 0,  "volume_factor": 1, "min_oct": 1, "max_oct": 6},
            "basn2": {"full_name": "bassoon2", "start": 0, "csound_voice": 12,"time_tracker_number": 0,  "volume_factor": 1, "min_oct": 1, "max_oct": 6},
            
            "vliv1": {"full_name": "violin with vib1", "start": 0, "csound_voice": 17,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 3, "max_oct": 7},
            "vliv2": {"full_name": "violin with vib2", "start": 0, "csound_voice": 17,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 3, "max_oct": 7},
            "vliv3": {"full_name": "violin with vib3", "start": 0, "csound_voice": 17,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 3, "max_oct": 7},
            "vliv4": {"full_name": "violin with vib4", "start": 0, "csound_voice": 17,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 3, "max_oct": 7},
            "vlav1": {"full_name": "viola with vib1", "start": 0, "csound_voice": 18,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 3, "max_oct": 5},
            "vlav2": {"full_name": "viola with vib2", "start": 0, "csound_voice": 18,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 3, "max_oct": 5},
            "celv1": {"full_name": "cello with vib1", "start": 0, "csound_voice": 19,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 1, "max_oct": 5},
            "celv2": {"full_name": "cello with vib2", "start": 0, "csound_voice": 19,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 1, "max_oct": 5},

            "trmp1": {"full_name": "trumpet1", "start": 0, "csound_voice": 25,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 2, "max_oct": 6},
            "trmp2": {"full_name": "trumpet2", "start": 0, "csound_voice": 25,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 2, "max_oct": 6},
            "trmp3": {"full_name": "trumpet3", "start": 0, "csound_voice": 25,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 2, "max_oct": 6},
            "trmp4": {"full_name": "trumpet4", "start": 0, "csound_voice": 25,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 2, "max_oct": 6},
            "trmb1": {"full_name": "trombone1", "start": 0, "csound_voice": 26,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 1, "max_oct": 5},
            "trmb2": {"full_name": "trombone2", "start": 0, "csound_voice": 26,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 1, "max_oct": 5},
            "tuba1": {"full_name": "tuba1", "start": 0, "csound_voice": 27,"time_tracker_number": 0,  "volume_factor": 1, "min_oct": 1, "max_oct": 4},
            "tuba2": {"full_name": "tuba2", "start": 0, "csound_voice": 27,"time_tracker_number": 0,  "volume_factor": 1, "min_oct": 1, "max_oct": 4},
                 
            "bfin3": {"full_name": "bass finger piano 3", "start": 0, "csound_voice": 24,"time_tracker_number": 0,  "volume_factor": 1, "min_oct": 2, "max_oct": 5},
            "bfin4": {"full_name": "bass finger piano 4", "start": 0, "csound_voice": 24,"time_tracker_number": 0,  "volume_factor": 1, "min_oct": 2, "max_oct": 5},
            "bfin5": {"full_name": "bass finger piano 5", "start": 0, "csound_voice": 24,"time_tracker_number": 0,  "volume_factor": 1, "min_oct": 2, "max_oct": 5},
            "bfin6": {"full_name": "bass finger piano 6", "start": 0, "csound_voice": 24,"time_tracker_number": 0,  "volume_factor": 1, "min_oct": 2, "max_oct": 5},
            "bfin7": {"full_name": "bass finger piano 7", "start": 0, "csound_voice": 24,"time_tracker_number": 0,  "volume_factor": 1, "min_oct": 2, "max_oct": 5},
            "bfin8": {"full_name": "bass finger piano 8", "start": 0, "csound_voice": 24,"time_tracker_number": 0,  "volume_factor": 1, "min_oct": 2, "max_oct": 5},
            
            "celp3": {"full_name": "cello pizzicato3", "start": 0, "csound_voice": 4,"time_tracker_number": 0,  "volume_factor": 1, "min_oct": 1, "max_oct": 5},
            "celp4": {"full_name": "cello pizzicato4", "start": 0, "csound_voice": 4,"time_tracker_number": 0,  "volume_factor": 1, "min_oct": 1, "max_oct": 4},
            
            "celp5": {"full_name": "cello pizzicato5", "start": 0, "csound_voice": 4,"time_tracker_number": 0,  "volume_factor": 1, "min_oct": 2, "max_oct": 4},
            "celp6": {"full_name": "cello pizzicato6", "start": 0, "csound_voice": 4,"time_tracker_number": 0,  "volume_factor": 1, "min_oct": 2, "max_oct": 4},
            "celp7": {"full_name": "cello pizzicato7", "start": 0, "csound_voice": 4,"time_tracker_number": 0,  "volume_factor": 1, "min_oct": 2, "max_oct": 4},
            "celp8": {"full_name": "cello pizzicato8", "start": 0, "csound_voice": 4,"time_tracker_number": 0,  "volume_factor": 1, "min_oct": 2, "max_oct": 4},
            "bgui2": {"full_name": "baritone guitar2", "start": 0, "csound_voice": 20,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 1, "max_oct": 6},
            "bgui3": {"full_name": "baritone guitar3", "start": 0, "csound_voice": 20,"time_tracker_number": 0,  "volume_factor": 1, "min_oct": 1, "max_oct": 6},
            "bgui4": {"full_name": "baritone guitar4", "start": 0, "csound_voice": 20,"time_tracker_number": 0,  "volume_factor": 1, "min_oct": 1, "max_oct": 6},
            "bgui5": {"full_name": "baritone guitar5", "start": 0, "csound_voice": 20,"time_tracker_number": 0,  "volume_factor": 1, "min_oct": 1, "max_oct": 6},
            "bgui6": {"full_name": "baritone guitar6", "start": 0, "csound_voice": 20,"time_tracker_number": 0,  "volume_factor": 1, "min_oct": 1, "max_oct": 6},
            "bgui7": {"full_name": "baritone guitar7", "start": 0, "csound_voice": 20,"time_tracker_number": 0,  "volume_factor": 1, "min_oct": 1, "max_oct": 6},
            "bgui8": {"full_name": "baritone guitar8", "start": 0, "csound_voice": 20,"time_tracker_number": 0,  "volume_factor": 1, "min_oct": 1, "max_oct": 6},
            
            "long2": {"full_name": "long string2", "start": 0, "csound_voice": 22,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 1, "max_oct": 7},
            "long3": {"full_name": "long string3", "start": 0, "csound_voice": 22,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 1, "max_oct": 7},
            "long4": {"full_name": "long string4", "start": 0, "csound_voice": 22,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 1, "max_oct": 7},
            "long5": {"full_name": "long string5", "start": 0, "csound_voice": 22,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 1, "max_oct": 7},
            "long6": {"full_name": "long string6", "start": 0, "csound_voice": 22,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 1, "max_oct": 7},
            "long7": {"full_name": "long string7", "start": 0, "csound_voice": 22,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 1, "max_oct": 7},
            "long8": {"full_name": "long string8", "start": 0, "csound_voice": 22,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 1, "max_oct": 7},
            
            "flut3": {"full_name": "flute3", "start": 0, "csound_voice": 14,"time_tracker_number": 0,  "volume_factor": 2, "min_oct": 3, "max_oct": 6},
            "oboe3": {"full_name": "oboe3", "start": 0, "csound_voice": 15,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 3, "max_oct": 6},
            "basn4": {"full_name": "bassoon4", "start": 0, "csound_voice": 12,"time_tracker_number": 0,  "volume_factor": 1, "min_oct": 1, "max_oct": 6},
            "trmp5": {"full_name": "trumpet5", "start": 0, "csound_voice": 25,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 2, "max_oct": 6},
            "frnh3": {"full_name": "french horn3", "start": 0, "csound_voice": 16,"time_tracker_number": 0,  "volume_factor": 1, "min_oct": 1, "max_oct": 5},
            }
      for inx, voice in zip(count(0,1), voice_time):
            # logging.info(voice)
            voice_time[voice]["time_tracker_number"] = inx
      return (voice_time)


def find_root_mode(midi_file_name):
      keys = set_accidentals(False) # this use of keys is to search through the letters. It requires only the naturals and sharps
      # logging.debug(f'determining root & mode for: {file_name = }')
      s = m21.converter.parse(midi_file_name)
      fis = str(s.analyze('key'))
      # logging.debug(f'music21 says: {fis = }')
      key_name, mode = fis.split()
      # logging.debug(f'after split. {key_name = }, {mode = }')
      i = 0
      root = 9999
      for key in keys:
            letter_only = key[0]
            # logging.debug(f'{letter_only = }, {key_name = }')
            if letter_only.upper() == key_name.upper():
                  root = i
                  # logging.debug(f'found a match between music21 {letter_only = }, and {key = } as {root = }, {mode = }')
                  break
            i += 1
      if root == 9999: return (9999)
      return (root, mode, s)

def load_from_midi_file(file_name, quantization = 4):
      logging.debug(f'{file_name = }, {quantization = }')
      mid = mido.MidiFile(file_name, clip = True)
      logging.debug(f'{mid.length = }') # total playback time in seconds 24.5
      measures = int(mid.length)
      ticks_per_beat = mid.ticks_per_beat
      slots_per_quarter = ticks_per_beat // quantization
      logging.debug(f'{ticks_per_beat = }, {slots_per_quarter = }, {ticks_per_beat // slots_per_quarter * quantization * 12 = }')
      logging.debug(f'{mid.length = }')
      chorale = np.zeros((4, ticks_per_beat // slots_per_quarter * quantization * measures), dtype = int)
      logging.debug(f'{chorale.shape = },')
      mido_keys = [['A', 'A#m', 'Ab', 'Abm', 'Am', 'B', 'Bb', 'Bbm', 'Bm', 'C', 'C#', 'C#m', 'Cb', 'Cm', 'D', 'D#m', 'Db',\
               'Dm', 'E', 'Eb', 'Ebm', 'Em', 'F', 'F#', 'F#m', 'Fm', 'G', 'G#m', 'Gb', 'Gm'],
            [9, 10, 8, 8, 9, 11, 10, 10, 11, 0, 1, 1, 11, 0, 2, 3, 1, 2, 4, 3, 3, 4, 5, 6, 6, 5, 7, 8, 6, 7],
             ['maj', 'min', 'maj', 'min', 'min', 'maj', 'maj', 'min', 'min', 'maj', 'maj', 'min', 'maj', 'min', 'maj', 'min', 'maj',\
             'min', 'maj', 'maj', 'min', 'min', 'maj', 'maj', 'min', 'min', 'maj', 'min', 'maj', 'min']]
      for track_num, track in enumerate(mid.tracks):
            chorale_num = 0
            voice = track_num - 1
            for msg_num, msg in zip(count(0,1), track):
                  if msg.is_meta:
                        if msg.type == 'key_signature':
                              root = msg.key
                              logging.debug(f'{msg_num = }, {track_num = }: {root = }')
                        elif msg.type == 'time_signature':
                              time_sig_num = msg.numerator
                              time_sig_den = msg.denominator
                              time_sig_clocks = msg.clocks_per_click
                              ticks_32_per_beat = msg.notated_32nd_notes_per_beat
                              logging.debug(f'{msg_num = }, {track_num = }: {time_sig_num = }, {time_sig_den = }, {time_sig_clocks = }, {ticks_32_per_beat = }')
                        elif msg.type == 'set_tempo':
                              tempo = msg.tempo
                              logging.debug(f'{msg_num = }, {track_num = }: {tempo = }')
                        elif msg.type == 'end_of_track': pass
                              # end_of_track = msg.time
                              # logging.info(f'{msg_num = }, {track_num = }: {end_of_track = }')
                  else: # not meta
                        if msg.type == 'note_on': pass
                        elif msg.type == 'note_off':
                              slots = msg.time // slots_per_quarter
                              logging.debug(f'note off: {voice = }, {msg.time = }, note info: {msg.note}, {msg.note // 12}, {slots = }, {chorale_num = }')
                              chorale[voice, chorale_num:chorale_num + slots] = msg.note
                              # logging.info(f'chorale[{voice}, {chorale_num}:{chorale_num + slots}], {chorale[voice, chorale_num:chorale_num + slots] = }')
                              chorale_num += slots
                        elif msg.type == 'pitchwheel': pass
                        elif msg.type == 'program_change': pass
                        else: logging.info(f'{msg_num = }, {voice = }: {msg = }')
      chorale = chorale[:voice + 1, :chorale_num]
      
      time_sig = str(time_sig_num) + '/' + str(time_sig_den)
      
      for root_num in np.arange(len(mido_keys[0])):
            if mido_keys[0][root_num] == root:
                  break
      root_note = mido_keys[1][root_num]
      mode = mido_keys[2][root_num]
      if mode == 'min': mode = 'minor'
      elif mode == 'maj': mode = 'major'
      logging.debug(f'{root = }, {mode = }, {chorale_num = }, {quantization = }, {slots_per_quarter = }')
      return chorale, root_note, mode, time_sig 

def read_from_midi(midi_file_name, quantizer = 4):
      root, mode, s = find_root_mode(midi_file_name)
      # logging.info(f'{len(s) = }')
      music = muspy.from_music21(s, resolution=24) # convert the music21 object to a muspy object
      # logging.info(f'{len(music) = }')
      sample, root, mode, pit_cl_ent, pcu = muspy_to_sample_root_mode(music, quantizer = quantizer)  
      return sample.T, root, mode, s, pit_cl_ent, pcu

# (continued...)