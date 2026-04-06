import sys
import diamond_music_utils as dmu
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
from collections import defaultdict, Counter
from itertools import count, combinations, permutations

def set_accidentals(flats):
    """
    Generate an array of note names with either flats or sharps.
    
    Parameters
    ----------
    flats : bool
        If True, uses flats (D♭, E♭, etc.). If False, uses sharps (C♯, D♯, etc.).
    
    Returns
    -------
    np.ndarray
        Array of 12 note names (C through B) with accidentals as specified.
    """
    if flats: 
        keys = np.array(['C♮', 'D♭', 'D♮', 'E♭', 'E♮', 'F♮', 'G♭', 'G♮', 'A♭', 'A♮', 'B♭', 'B♮'])
    else: keys = np.array(['C♮', 'C♯', 'D♮', 'D♯', 'E♮', 'F♮', 'F♯', 'G♮', 'G♯', 'A♮', 'A♯', 'B♮'])
    return keys

def windows_compliant_filename(filename):
    """
    Replace Windows-incompatible characters in a filename.
    
    Parameters
    ----------
    filename : str
        Original filename that may contain invalid characters.
    
    Returns
    -------
    str
        Filename with Windows-incompatible characters replaced:
        - ':' -> '_'
        - '?' -> '' (removed)
        - '/' -> '-'
    """
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
    """
    Initialize a dictionary of all instruments/voices with their configuration.
    
    Each instrument entry contains:
    - full_name: Human-readable name
    - start: Starting offset (typically 0)
    - csound_voice: Voice number for Csound input file
    - time_tracker_number: Sequential number (0-n) assigned at end of function
    - volume_factor: Volume adjustment offset
    - min_oct: Minimum octave for this instrument
    - max_oct: Maximum octave for this instrument
    
    Returns
    -------
    dict
        Dictionary mapping instrument short names (e.g., 'fing1', 'bfin1') to their
        configuration dictionaries. The time_tracker_number values are reset to consecutive
        integers starting from 0.
    """
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
            "vlap1": {"full_name": "viola pizzicato1", "start": 0, "csound_voice": 3,"time_tracker_number": 0,  "volume_factor": 1, "min_oct":  2, "max_oct": 6},
            "celp1": {"full_name": "cello pizzicato1", "start": 0, "csound_voice": 4,"time_tracker_number": 0,  "volume_factor": 1, "min_oct": 1, "max_oct": 5},
            "vlip3": {"full_name": "violin pizzicato3", "start": 0, "csound_voice": 2,"time_tracker_number": 0,  "volume_factor": 1, "min_oct": 3, "max_oct": 7},
            "vlip4": {"full_name": "violin pizzicato4", "start": 0, "csound_voice": 2,"time_tracker_number": 0,  "volume_factor": 1, "min_oct": 3, "max_oct": 7},
            "vlap2": {"full_name": "viola pizzicato2", "start": 0, "csound_voice": 3,"time_tracker_number": 0,  "volume_factor": 1, "min_oct":  2, "max_oct": 6},
            "celp2": {"full_name": "cello pizzicato2", "start": 0, "csound_voice": 4,"time_tracker_number": 0,  "volume_factor": 1, "min_oct": 1, "max_oct": 5},

            "mari1": {"full_name": "marimba1", "start": 0, "csound_voice": 5,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 2, "max_oct": 7},
            "mari2": {"full_name": "marimba2", "start": 0, "csound_voice": 5,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 3, "max_oct": 7},
            "mari3": {"full_name": "marimba3", "start": 0, "csound_voice": 5,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 2, "max_oct": 7},
            "mari4": {"full_name": "marimba4", "start": 0, "csound_voice": 5,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 3, "max_oct": 7},
            "mari5": {"full_name": "marimba5", "start": 0, "csound_voice": 5,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 2, "max_oct": 7},
            "mari6": {"full_name": "marimba6", "start": 0, "csound_voice": 5,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 3, "max_oct": 7},
            "mari7": {"full_name": "marimba7", "start": 0, "csound_voice": 5,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 2, "max_oct": 7},
            "mari8": {"full_name": "marimba8", "start": 0, "csound_voice": 5,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 3, "max_oct": 7},
            
            "xylp1": {"full_name": "xylophone1", "start": 0, "csound_voice": 6,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 4, "max_oct": 7},
            "vibp1": {"full_name": "vibraphone1", "start": 0, "csound_voice": 7,"time_tracker_number": 0,  "volume_factor": 1, "min_oct": 4, "max_oct": 7},
            "harp1": {"full_name": "harp1", "start": 0, "csound_voice": 8,"time_tracker_number": 0,  "volume_factor": 2, "min_oct": 3, "max_oct": 7},

            "bgui1": {"full_name": "baritone guitar1", "start": 0, "csound_voice": 20,"time_tracker_number": 0,  "volume_factor": 1, "min_oct": 1, "max_oct": 7},
            "ebss1": {"full_name": "Ernie Ball Super Slinky1", "start": 0, "csound_voice": 21,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 1, "max_oct": 7},
            "ebss2": {"full_name": "Ernie Ball Super Slinky2", "start": 0, "csound_voice": 21,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 1, "max_oct": 7},
            "ebss3": {"full_name": "Ernie Ball Super Slinky3", "start": 0, "csound_voice": 21,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 1, "max_oct": 7},
            "ebss4": {"full_name": "Ernie Ball Super Slinky4", "start": 0, "csound_voice": 21,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 1, "max_oct": 7},
            "ebss5": {"full_name": "Ernie Ball Super Slinky5", "start": 0, "csound_voice": 21,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 1, "max_oct": 7},
            "ebss6": {"full_name": "Ernie Ball Super Slinky6", "start": 0, "csound_voice": 21,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 1, "max_oct": 7},
            "ebss7": {"full_name": "Ernie Ball Super Slinky7", "start": 0, "csound_voice": 21,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 1, "max_oct": 7},
            "ebss8": {"full_name": "Ernie Ball Super Slinky8", "start": 0, "csound_voice": 21,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 1, "max_oct": 7},
            "long1": {"full_name": "long string1", "start": 0, "csound_voice": 22,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 1, "max_oct": 7},
            "long2": {"full_name": "long string2", "start": 0, "csound_voice": 22,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 1, "max_oct": 7},
            "long3": {"full_name": "long string3", "start": 0, "csound_voice": 22,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 1, "max_oct": 7},
            "long4": {"full_name": "long string4", "start": 0, "csound_voice": 22,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 1, "max_oct": 7},
            "long5": {"full_name": "long string5", "start": 0, "csound_voice": 22,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 1, "max_oct": 7},
            "long6": {"full_name": "long string6", "start": 0, "csound_voice": 22,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 1, "max_oct": 7},
            "long7": {"full_name": "long string7", "start": 0, "csound_voice": 22,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 1, "max_oct": 7},
            "long8": {"full_name": "long string8", "start": 0, "csound_voice": 22,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 1, "max_oct": 7},
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
                 
            "bfin3": {"full_name": "bass finger piano 3", "start": 0, "csound_voice": 24,"time_tracker_number": 0,  "volume_factor": 1, "min_oct": 1, "max_oct": 5},
            "bfin4": {"full_name": "bass finger piano 4", "start": 0, "csound_voice": 24,"time_tracker_number": 0,  "volume_factor": 1, "min_oct": 1, "max_oct": 5},
            "bfin5": {"full_name": "bass finger piano 5", "start": 0, "csound_voice": 24,"time_tracker_number": 0,  "volume_factor": 1, "min_oct": 1, "max_oct": 5},
            "bfin6": {"full_name": "bass finger piano 6", "start": 0, "csound_voice": 24,"time_tracker_number": 0,  "volume_factor": 1, "min_oct": 1, "max_oct": 5},
            "bfin7": {"full_name": "bass finger piano 7", "start": 0, "csound_voice": 24,"time_tracker_number": 0,  "volume_factor": 1, "min_oct": 1, "max_oct": 5},
            "bfin8": {"full_name": "bass finger piano 8", "start": 0, "csound_voice": 24,"time_tracker_number": 0,  "volume_factor": 1, "min_oct": 1, "max_oct": 5},
            
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
            
            "flut3": {"full_name": "flute3", "start": 0, "csound_voice": 14,"time_tracker_number": 0,  "volume_factor": 2, "min_oct": 3, "max_oct": 6},
            "oboe3": {"full_name": "oboe3", "start": 0, "csound_voice": 15,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 3, "max_oct": 6},
            "basn4": {"full_name": "bassoon4", "start": 0, "csound_voice": 12,"time_tracker_number": 0,  "volume_factor": 1, "min_oct": 1, "max_oct": 6},
            "trmp5": {"full_name": "trumpet5", "start": 0, "csound_voice": 25,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 2, "max_oct": 6},
            "frnh3": {"full_name": "french horn3", "start": 0, "csound_voice": 16,"time_tracker_number": 0,  "volume_factor": 1, "min_oct": 1, "max_oct": 5},
            "trian1": {"full_name": "triangle wave1", "start": 0, "csound_voice":29, "time_tracker_number": 0,  "volume_factor": 1, "min_oct": 1, "max_oct": 7},   
            "trian2": {"full_name": "triangle wave2", "start": 0, "csound_voice":29,"time_tracker_number": 0,  "volume_factor": 1, "min_oct": 1, "max_oct": 7},
            "trian3": {"full_name": "triangle wave3", "start": 0, "csound_voice":29,"time_tracker_number": 0,  "volume_factor": 1, "min_oct": 1, "max_oct": 7},
            "trian4": {"full_name": "triangle wave4", "start": 0, "csound_voice":29,"time_tracker_number": 0,  "volume_factor": 1, "min_oct": 1, "max_oct": 7},
            "trian5": {"full_name": "triangle wave5", "start": 0, "csound_voice":29,"time_tracker_number": 0,  "volume_factor": 1, "min_oct": 1, "max_oct": 7},
            "trian6": {"full_name": "triangle wave6", "start": 0, "csound_voice":29,"time_tracker_number": 0,  "volume_factor": 1, "min_oct": 1, "max_oct": 7},
            "trian7": {"full_name": "triangle wave7", "start": 0, "csound_voice":29,"time_tracker_number": 0,  "volume_factor": 1, "min_oct": 1, "max_oct": 7},
            "trian8": {"full_name": "triangle wave8", "start": 0, "csound_voice":29,"time_tracker_number": 0,  "volume_factor": 1, "min_oct": 1, "max_oct": 7},

            # ── Additional voices (pad every instrument type to at least 8) ──

            # violin pizzicato (was 4, add 4 with varied ranges)
            "vlip5": {"full_name": "violin pizzicato5", "start": 0, "csound_voice": 2,"time_tracker_number": 0,  "volume_factor": 1, "min_oct": 3, "max_oct": 7},
            "vlip6": {"full_name": "violin pizzicato6", "start": 0, "csound_voice": 2,"time_tracker_number": 0,  "volume_factor": 1, "min_oct": 3, "max_oct": 6},
            "vlip7": {"full_name": "violin pizzicato7", "start": 0, "csound_voice": 2,"time_tracker_number": 0,  "volume_factor": 1, "min_oct": 4, "max_oct": 7},
            "vlip8": {"full_name": "violin pizzicato8", "start": 0, "csound_voice": 2,"time_tracker_number": 0,  "volume_factor": 1, "min_oct": 3, "max_oct": 6},

            # viola pizzicato (was 2, add 6)
            "vlap3": {"full_name": "viola pizzicato3", "start": 0, "csound_voice": 3,"time_tracker_number": 0,  "volume_factor": 1, "min_oct": 2, "max_oct": 6},
            "vlap4": {"full_name": "viola pizzicato4", "start": 0, "csound_voice": 3,"time_tracker_number": 0,  "volume_factor": 1, "min_oct": 2, "max_oct": 5},
            "vlap5": {"full_name": "viola pizzicato5", "start": 0, "csound_voice": 3,"time_tracker_number": 0,  "volume_factor": 1, "min_oct": 3, "max_oct": 6},
            "vlap6": {"full_name": "viola pizzicato6", "start": 0, "csound_voice": 3,"time_tracker_number": 0,  "volume_factor": 1, "min_oct": 2, "max_oct": 5},
            "vlap7": {"full_name": "viola pizzicato7", "start": 0, "csound_voice": 3,"time_tracker_number": 0,  "volume_factor": 1, "min_oct": 3, "max_oct": 6},
            "vlap8": {"full_name": "viola pizzicato8", "start": 0, "csound_voice": 3,"time_tracker_number": 0,  "volume_factor": 1, "min_oct": 2, "max_oct": 6},

            # xylophone (was 1, add 7 — bright, upper register)
            "xylp2": {"full_name": "xylophone2", "start": 0, "csound_voice": 6,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 4, "max_oct": 7},
            "xylp3": {"full_name": "xylophone3", "start": 0, "csound_voice": 6,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 4, "max_oct": 7},
            "xylp4": {"full_name": "xylophone4", "start": 0, "csound_voice": 6,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 3, "max_oct": 7},
            "xylp5": {"full_name": "xylophone5", "start": 0, "csound_voice": 6,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 4, "max_oct": 7},
            "xylp6": {"full_name": "xylophone6", "start": 0, "csound_voice": 6,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 3, "max_oct": 7},
            "xylp7": {"full_name": "xylophone7", "start": 0, "csound_voice": 6,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 4, "max_oct": 7},
            "xylp8": {"full_name": "xylophone8", "start": 0, "csound_voice": 6,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 4, "max_oct": 7},

            # vibraphone (was 1, add 7)
            "vibp2": {"full_name": "vibraphone2", "start": 0, "csound_voice": 7,"time_tracker_number": 0,  "volume_factor": 1, "min_oct": 4, "max_oct": 7},
            "vibp3": {"full_name": "vibraphone3", "start": 0, "csound_voice": 7,"time_tracker_number": 0,  "volume_factor": 1, "min_oct": 3, "max_oct": 7},
            "vibp4": {"full_name": "vibraphone4", "start": 0, "csound_voice": 7,"time_tracker_number": 0,  "volume_factor": 1, "min_oct": 4, "max_oct": 7},
            "vibp5": {"full_name": "vibraphone5", "start": 0, "csound_voice": 7,"time_tracker_number": 0,  "volume_factor": 1, "min_oct": 3, "max_oct": 7},
            "vibp6": {"full_name": "vibraphone6", "start": 0, "csound_voice": 7,"time_tracker_number": 0,  "volume_factor": 1, "min_oct": 4, "max_oct": 7},
            "vibp7": {"full_name": "vibraphone7", "start": 0, "csound_voice": 7,"time_tracker_number": 0,  "volume_factor": 1, "min_oct": 3, "max_oct": 7},
            "vibp8": {"full_name": "vibraphone8", "start": 0, "csound_voice": 7,"time_tracker_number": 0,  "volume_factor": 1, "min_oct": 4, "max_oct": 7},

            # harp (was 1, add 7)
            "harp2": {"full_name": "harp2", "start": 0, "csound_voice": 8,"time_tracker_number": 0,  "volume_factor": 2, "min_oct": 3, "max_oct": 7},
            "harp3": {"full_name": "harp3", "start": 0, "csound_voice": 8,"time_tracker_number": 0,  "volume_factor": 2, "min_oct": 2, "max_oct": 7},
            "harp4": {"full_name": "harp4", "start": 0, "csound_voice": 8,"time_tracker_number": 0,  "volume_factor": 2, "min_oct": 3, "max_oct": 6},
            "harp5": {"full_name": "harp5", "start": 0, "csound_voice": 8,"time_tracker_number": 0,  "volume_factor": 2, "min_oct": 2, "max_oct": 7},
            "harp6": {"full_name": "harp6", "start": 0, "csound_voice": 8,"time_tracker_number": 0,  "volume_factor": 2, "min_oct": 3, "max_oct": 7},
            "harp7": {"full_name": "harp7", "start": 0, "csound_voice": 8,"time_tracker_number": 0,  "volume_factor": 2, "min_oct": 2, "max_oct": 6},
            "harp8": {"full_name": "harp8", "start": 0, "csound_voice": 8,"time_tracker_number": 0,  "volume_factor": 2, "min_oct": 3, "max_oct": 7},

            # violin martele (was 4, add 4)
            "vlim5": {"full_name": "violin martele5", "start": 0, "csound_voice": 9,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 3, "max_oct": 6},
            "vlim6": {"full_name": "violin martele6", "start": 0, "csound_voice": 9,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 4, "max_oct": 6},
            "vlim7": {"full_name": "violin martele7", "start": 0, "csound_voice": 9,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 3, "max_oct": 6},
            "vlim8": {"full_name": "violin martele8", "start": 0, "csound_voice": 9,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 3, "max_oct": 5},

            # viola martele (was 2, add 6)
            "vlam3": {"full_name": "viola martele3", "start": 0, "csound_voice": 10,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 2, "max_oct": 5},
            "vlam4": {"full_name": "viola martele4", "start": 0, "csound_voice": 10,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 3, "max_oct": 5},
            "vlam5": {"full_name": "viola martele5", "start": 0, "csound_voice": 10,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 2, "max_oct": 5},
            "vlam6": {"full_name": "viola martele6", "start": 0, "csound_voice": 10,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 3, "max_oct": 5},
            "vlam7": {"full_name": "viola martele7", "start": 0, "csound_voice": 10,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 2, "max_oct": 5},
            "vlam8": {"full_name": "viola martele8", "start": 0, "csound_voice": 10,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 2, "max_oct": 5},

            # cello martele (was 2, add 6)
            "celm3": {"full_name": "cello martele3", "start": 0, "csound_voice": 11,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 2, "max_oct": 5},
            "celm4": {"full_name": "cello martele4", "start": 0, "csound_voice": 11,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 1, "max_oct": 5},
            "celm5": {"full_name": "cello martele5", "start": 0, "csound_voice": 11,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 2, "max_oct": 4},
            "celm6": {"full_name": "cello martele6", "start": 0, "csound_voice": 11,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 1, "max_oct": 5},
            "celm7": {"full_name": "cello martele7", "start": 0, "csound_voice": 11,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 2, "max_oct": 5},
            "celm8": {"full_name": "cello martele8", "start": 0, "csound_voice": 11,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 2, "max_oct": 4},

            # bassoon (was 3, add 5 — note: basn3 was missing)
            "basn3": {"full_name": "bassoon3", "start": 0, "csound_voice": 12,"time_tracker_number": 0,  "volume_factor": 1, "min_oct": 1, "max_oct": 6},
            "basn5": {"full_name": "bassoon5", "start": 0, "csound_voice": 12,"time_tracker_number": 0,  "volume_factor": 1, "min_oct": 1, "max_oct": 5},
            "basn6": {"full_name": "bassoon6", "start": 0, "csound_voice": 12,"time_tracker_number": 0,  "volume_factor": 1, "min_oct": 2, "max_oct": 6},
            "basn7": {"full_name": "bassoon7", "start": 0, "csound_voice": 12,"time_tracker_number": 0,  "volume_factor": 1, "min_oct": 1, "max_oct": 5},
            "basn8": {"full_name": "bassoon8", "start": 0, "csound_voice": 12,"time_tracker_number": 0,  "volume_factor": 1, "min_oct": 1, "max_oct": 6},

            # clarinet (was 2, add 6)
            "clar3": {"full_name": "clarinet3", "start": 0, "csound_voice": 13,"time_tracker_number": 0,  "volume_factor": -1, "min_oct": 3, "max_oct": 6},
            "clar4": {"full_name": "clarinet4", "start": 0, "csound_voice": 13,"time_tracker_number": 0,  "volume_factor": -1, "min_oct": 2, "max_oct": 6},
            "clar5": {"full_name": "clarinet5", "start": 0, "csound_voice": 13,"time_tracker_number": 0,  "volume_factor": -1, "min_oct": 3, "max_oct": 6},
            "clar6": {"full_name": "clarinet6", "start": 0, "csound_voice": 13,"time_tracker_number": 0,  "volume_factor": -1, "min_oct": 2, "max_oct": 5},
            "clar7": {"full_name": "clarinet7", "start": 0, "csound_voice": 13,"time_tracker_number": 0,  "volume_factor": -1, "min_oct": 3, "max_oct": 6},
            "clar8": {"full_name": "clarinet8", "start": 0, "csound_voice": 13,"time_tracker_number": 0,  "volume_factor": -1, "min_oct": 3, "max_oct": 6},

            # flute (was 3, add 5)
            "flut4": {"full_name": "flute4", "start": 0, "csound_voice": 14,"time_tracker_number": 0,  "volume_factor": 2, "min_oct": 3, "max_oct": 6},
            "flut5": {"full_name": "flute5", "start": 0, "csound_voice": 14,"time_tracker_number": 0,  "volume_factor": 2, "min_oct": 4, "max_oct": 6},
            "flut6": {"full_name": "flute6", "start": 0, "csound_voice": 14,"time_tracker_number": 0,  "volume_factor": 2, "min_oct": 3, "max_oct": 6},
            "flut7": {"full_name": "flute7", "start": 0, "csound_voice": 14,"time_tracker_number": 0,  "volume_factor": 2, "min_oct": 3, "max_oct": 6},
            "flut8": {"full_name": "flute8", "start": 0, "csound_voice": 14,"time_tracker_number": 0,  "volume_factor": 2, "min_oct": 4, "max_oct": 6},

            # oboe (was 3, add 5)
            "oboe4": {"full_name": "oboe4", "start": 0, "csound_voice": 15,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 3, "max_oct": 6},
            "oboe5": {"full_name": "oboe5", "start": 0, "csound_voice": 15,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 3, "max_oct": 5},
            "oboe6": {"full_name": "oboe6", "start": 0, "csound_voice": 15,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 3, "max_oct": 6},
            "oboe7": {"full_name": "oboe7", "start": 0, "csound_voice": 15,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 3, "max_oct": 6},
            "oboe8": {"full_name": "oboe8", "start": 0, "csound_voice": 15,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 3, "max_oct": 5},

            # french horn (was 3, add 5)
            "frnh4": {"full_name": "french horn4", "start": 0, "csound_voice": 16,"time_tracker_number": 0,  "volume_factor": 1, "min_oct": 1, "max_oct": 5},
            "frnh5": {"full_name": "french horn5", "start": 0, "csound_voice": 16,"time_tracker_number": 0,  "volume_factor": 1, "min_oct": 2, "max_oct": 5},
            "frnh6": {"full_name": "french horn6", "start": 0, "csound_voice": 16,"time_tracker_number": 0,  "volume_factor": 1, "min_oct": 1, "max_oct": 5},
            "frnh7": {"full_name": "french horn7", "start": 0, "csound_voice": 16,"time_tracker_number": 0,  "volume_factor": 1, "min_oct": 1, "max_oct": 4},
            "frnh8": {"full_name": "french horn8", "start": 0, "csound_voice": 16,"time_tracker_number": 0,  "volume_factor": 1, "min_oct": 2, "max_oct": 5},

            # violin with vib (was 4, add 4)
            "vliv5": {"full_name": "violin with vib5", "start": 0, "csound_voice": 17,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 3, "max_oct": 7},
            "vliv6": {"full_name": "violin with vib6", "start": 0, "csound_voice": 17,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 4, "max_oct": 7},
            "vliv7": {"full_name": "violin with vib7", "start": 0, "csound_voice": 17,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 3, "max_oct": 6},
            "vliv8": {"full_name": "violin with vib8", "start": 0, "csound_voice": 17,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 3, "max_oct": 7},

            # viola with vib (was 2, add 6)
            "vlav3": {"full_name": "viola with vib3", "start": 0, "csound_voice": 18,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 3, "max_oct": 5},
            "vlav4": {"full_name": "viola with vib4", "start": 0, "csound_voice": 18,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 2, "max_oct": 5},
            "vlav5": {"full_name": "viola with vib5", "start": 0, "csound_voice": 18,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 3, "max_oct": 5},
            "vlav6": {"full_name": "viola with vib6", "start": 0, "csound_voice": 18,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 2, "max_oct": 5},
            "vlav7": {"full_name": "viola with vib7", "start": 0, "csound_voice": 18,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 3, "max_oct": 5},
            "vlav8": {"full_name": "viola with vib8", "start": 0, "csound_voice": 18,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 2, "max_oct": 5},

            # cello with vib (was 2, add 6)
            "celv3": {"full_name": "cello with vib3", "start": 0, "csound_voice": 19,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 1, "max_oct": 5},
            "celv4": {"full_name": "cello with vib4", "start": 0, "csound_voice": 19,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 2, "max_oct": 5},
            "celv5": {"full_name": "cello with vib5", "start": 0, "csound_voice": 19,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 1, "max_oct": 4},
            "celv6": {"full_name": "cello with vib6", "start": 0, "csound_voice": 19,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 2, "max_oct": 5},
            "celv7": {"full_name": "cello with vib7", "start": 0, "csound_voice": 19,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 1, "max_oct": 5},
            "celv8": {"full_name": "cello with vib8", "start": 0, "csound_voice": 19,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 1, "max_oct": 4},

            # trumpet (was 5, add 3)
            "trmp6": {"full_name": "trumpet6", "start": 0, "csound_voice": 25,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 2, "max_oct": 6},
            "trmp7": {"full_name": "trumpet7", "start": 0, "csound_voice": 25,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 3, "max_oct": 6},
            "trmp8": {"full_name": "trumpet8", "start": 0, "csound_voice": 25,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 2, "max_oct": 5},

            # trombone (was 2, add 6)
            "trmb3": {"full_name": "trombone3", "start": 0, "csound_voice": 26,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 1, "max_oct": 5},
            "trmb4": {"full_name": "trombone4", "start": 0, "csound_voice": 26,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 1, "max_oct": 4},
            "trmb5": {"full_name": "trombone5", "start": 0, "csound_voice": 26,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 2, "max_oct": 5},
            "trmb6": {"full_name": "trombone6", "start": 0, "csound_voice": 26,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 1, "max_oct": 5},
            "trmb7": {"full_name": "trombone7", "start": 0, "csound_voice": 26,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 1, "max_oct": 4},
            "trmb8": {"full_name": "trombone8", "start": 0, "csound_voice": 26,"time_tracker_number": 0,  "volume_factor": 0, "min_oct": 2, "max_oct": 5},

            # tuba (was 2, add 6)
            "tuba3": {"full_name": "tuba3", "start": 0, "csound_voice": 27,"time_tracker_number": 0,  "volume_factor": 1, "min_oct": 1, "max_oct": 4},
            "tuba4": {"full_name": "tuba4", "start": 0, "csound_voice": 27,"time_tracker_number": 0,  "volume_factor": 1, "min_oct": 1, "max_oct": 3},
            "tuba5": {"full_name": "tuba5", "start": 0, "csound_voice": 27,"time_tracker_number": 0,  "volume_factor": 1, "min_oct": 1, "max_oct": 4},
            "tuba6": {"full_name": "tuba6", "start": 0, "csound_voice": 27,"time_tracker_number": 0,  "volume_factor": 1, "min_oct": 1, "max_oct": 3},
            "tuba7": {"full_name": "tuba7", "start": 0, "csound_voice": 27,"time_tracker_number": 0,  "volume_factor": 1, "min_oct": 1, "max_oct": 4},
            "tuba8": {"full_name": "tuba8", "start": 0, "csound_voice": 27,"time_tracker_number": 0,  "volume_factor": 1, "min_oct": 1, "max_oct": 4},
            
            # bosendorfer piano (64 polyphonic slots for piano mode / ball11.csd)
            "bosen01": {"full_name": "bosendorfer piano 01", "start": 0, "csound_voice": 33, "time_tracker_number": 0, "volume_factor": 1, "min_oct": 1, "max_oct": 7},
            "bosen02": {"full_name": "bosendorfer piano 02", "start": 0, "csound_voice": 33, "time_tracker_number": 0, "volume_factor": 1, "min_oct": 1, "max_oct": 7},
            "bosen03": {"full_name": "bosendorfer piano 03", "start": 0, "csound_voice": 33, "time_tracker_number": 0, "volume_factor": 1, "min_oct": 1, "max_oct": 7},
            "bosen04": {"full_name": "bosendorfer piano 04", "start": 0, "csound_voice": 33, "time_tracker_number": 0, "volume_factor": 1, "min_oct": 1, "max_oct": 7},
            "bosen05": {"full_name": "bosendorfer piano 05", "start": 0, "csound_voice": 33, "time_tracker_number": 0, "volume_factor": 1, "min_oct": 1, "max_oct": 7},
            "bosen06": {"full_name": "bosendorfer piano 06", "start": 0, "csound_voice": 33, "time_tracker_number": 0, "volume_factor": 1, "min_oct": 1, "max_oct": 7},
            "bosen07": {"full_name": "bosendorfer piano 07", "start": 0, "csound_voice": 33, "time_tracker_number": 0, "volume_factor": 1, "min_oct": 1, "max_oct": 7},
            "bosen08": {"full_name": "bosendorfer piano 08", "start": 0, "csound_voice": 33, "time_tracker_number": 0, "volume_factor": 1, "min_oct": 1, "max_oct": 7},
            "bosen09": {"full_name": "bosendorfer piano 09", "start": 0, "csound_voice": 33, "time_tracker_number": 0, "volume_factor": 1, "min_oct": 1, "max_oct": 7},
            "bosen10": {"full_name": "bosendorfer piano 10", "start": 0, "csound_voice": 33, "time_tracker_number": 0, "volume_factor": 1, "min_oct": 1, "max_oct": 7},
            "bosen11": {"full_name": "bosendorfer piano 11", "start": 0, "csound_voice": 33, "time_tracker_number": 0, "volume_factor": 1, "min_oct": 1, "max_oct": 7},
            "bosen12": {"full_name": "bosendorfer piano 12", "start": 0, "csound_voice": 33, "time_tracker_number": 0, "volume_factor": 1, "min_oct": 1, "max_oct": 7},
            "bosen13": {"full_name": "bosendorfer piano 13", "start": 0, "csound_voice": 33, "time_tracker_number": 0, "volume_factor": 1, "min_oct": 1, "max_oct": 7},
            "bosen14": {"full_name": "bosendorfer piano 14", "start": 0, "csound_voice": 33, "time_tracker_number": 0, "volume_factor": 1, "min_oct": 1, "max_oct": 7},
            "bosen15": {"full_name": "bosendorfer piano 15", "start": 0, "csound_voice": 33, "time_tracker_number": 0, "volume_factor": 1, "min_oct": 1, "max_oct": 7},
            "bosen16": {"full_name": "bosendorfer piano 16", "start": 0, "csound_voice": 33, "time_tracker_number": 0, "volume_factor": 1, "min_oct": 1, "max_oct": 7},
            "bosen17": {"full_name": "bosendorfer piano 17", "start": 0, "csound_voice": 33, "time_tracker_number": 0, "volume_factor": 1, "min_oct": 1, "max_oct": 7},
            "bosen18": {"full_name": "bosendorfer piano 18", "start": 0, "csound_voice": 33, "time_tracker_number": 0, "volume_factor": 1, "min_oct": 1, "max_oct": 7},
            "bosen19": {"full_name": "bosendorfer piano 19", "start": 0, "csound_voice": 33, "time_tracker_number": 0, "volume_factor": 1, "min_oct": 1, "max_oct": 7},
            "bosen20": {"full_name": "bosendorfer piano 20", "start": 0, "csound_voice": 33, "time_tracker_number": 0, "volume_factor": 1, "min_oct": 1, "max_oct": 7},
            "bosen21": {"full_name": "bosendorfer piano 21", "start": 0, "csound_voice": 33, "time_tracker_number": 0, "volume_factor": 1, "min_oct": 1, "max_oct": 7},
            "bosen22": {"full_name": "bosendorfer piano 22", "start": 0, "csound_voice": 33, "time_tracker_number": 0, "volume_factor": 1, "min_oct": 1, "max_oct": 7},
            "bosen23": {"full_name": "bosendorfer piano 23", "start": 0, "csound_voice": 33, "time_tracker_number": 0, "volume_factor": 1, "min_oct": 1, "max_oct": 7},
            "bosen24": {"full_name": "bosendorfer piano 24", "start": 0, "csound_voice": 33, "time_tracker_number": 0, "volume_factor": 1, "min_oct": 1, "max_oct": 7},
            "bosen25": {"full_name": "bosendorfer piano 25", "start": 0, "csound_voice": 33, "time_tracker_number": 0, "volume_factor": 1, "min_oct": 1, "max_oct": 7},
            "bosen26": {"full_name": "bosendorfer piano 26", "start": 0, "csound_voice": 33, "time_tracker_number": 0, "volume_factor": 1, "min_oct": 1, "max_oct": 7},
            "bosen27": {"full_name": "bosendorfer piano 27", "start": 0, "csound_voice": 33, "time_tracker_number": 0, "volume_factor": 1, "min_oct": 1, "max_oct": 7},
            "bosen28": {"full_name": "bosendorfer piano 28", "start": 0, "csound_voice": 33, "time_tracker_number": 0, "volume_factor": 1, "min_oct": 1, "max_oct": 7},
            "bosen29": {"full_name": "bosendorfer piano 29", "start": 0, "csound_voice": 33, "time_tracker_number": 0, "volume_factor": 1, "min_oct": 1, "max_oct": 7},
            "bosen30": {"full_name": "bosendorfer piano 30", "start": 0, "csound_voice": 33, "time_tracker_number": 0, "volume_factor": 1, "min_oct": 1, "max_oct": 7},
            "bosen31": {"full_name": "bosendorfer piano 31", "start": 0, "csound_voice": 33, "time_tracker_number": 0, "volume_factor": 1, "min_oct": 1, "max_oct": 7},
            "bosen32": {"full_name": "bosendorfer piano 32", "start": 0, "csound_voice": 33, "time_tracker_number": 0, "volume_factor": 1, "min_oct": 1, "max_oct": 7},
            "bosen33": {"full_name": "bosendorfer piano 33", "start": 0, "csound_voice": 33, "time_tracker_number": 0, "volume_factor": 1, "min_oct": 1, "max_oct": 7},
            "bosen34": {"full_name": "bosendorfer piano 34", "start": 0, "csound_voice": 33, "time_tracker_number": 0, "volume_factor": 1, "min_oct": 1, "max_oct": 7},
            "bosen35": {"full_name": "bosendorfer piano 35", "start": 0, "csound_voice": 33, "time_tracker_number": 0, "volume_factor": 1, "min_oct": 1, "max_oct": 7},
            "bosen36": {"full_name": "bosendorfer piano 36", "start": 0, "csound_voice": 33, "time_tracker_number": 0, "volume_factor": 1, "min_oct": 1, "max_oct": 7},
            "bosen37": {"full_name": "bosendorfer piano 37", "start": 0, "csound_voice": 33, "time_tracker_number": 0, "volume_factor": 1, "min_oct": 1, "max_oct": 7},
            "bosen38": {"full_name": "bosendorfer piano 38", "start": 0, "csound_voice": 33, "time_tracker_number": 0, "volume_factor": 1, "min_oct": 1, "max_oct": 7},
            "bosen39": {"full_name": "bosendorfer piano 39", "start": 0, "csound_voice": 33, "time_tracker_number": 0, "volume_factor": 1, "min_oct": 1, "max_oct": 7},
            "bosen40": {"full_name": "bosendorfer piano 40", "start": 0, "csound_voice": 33, "time_tracker_number": 0, "volume_factor": 1, "min_oct": 1, "max_oct": 7},
            "bosen41": {"full_name": "bosendorfer piano 41", "start": 0, "csound_voice": 33, "time_tracker_number": 0, "volume_factor": 1, "min_oct": 1, "max_oct": 7},
            "bosen42": {"full_name": "bosendorfer piano 42", "start": 0, "csound_voice": 33, "time_tracker_number": 0, "volume_factor": 1, "min_oct": 1, "max_oct": 7},
            "bosen43": {"full_name": "bosendorfer piano 43", "start": 0, "csound_voice": 33, "time_tracker_number": 0, "volume_factor": 1, "min_oct": 1, "max_oct": 7},
            "bosen44": {"full_name": "bosendorfer piano 44", "start": 0, "csound_voice": 33, "time_tracker_number": 0, "volume_factor": 1, "min_oct": 1, "max_oct": 7},
            "bosen45": {"full_name": "bosendorfer piano 45", "start": 0, "csound_voice": 33, "time_tracker_number": 0, "volume_factor": 1, "min_oct": 1, "max_oct": 7},
            "bosen46": {"full_name": "bosendorfer piano 46", "start": 0, "csound_voice": 33, "time_tracker_number": 0, "volume_factor": 1, "min_oct": 1, "max_oct": 7},
            "bosen47": {"full_name": "bosendorfer piano 47", "start": 0, "csound_voice": 33, "time_tracker_number": 0, "volume_factor": 1, "min_oct": 1, "max_oct": 7},
            "bosen48": {"full_name": "bosendorfer piano 48", "start": 0, "csound_voice": 33, "time_tracker_number": 0, "volume_factor": 1, "min_oct": 1, "max_oct": 7},
            "bosen49": {"full_name": "bosendorfer piano 49", "start": 0, "csound_voice": 33, "time_tracker_number": 0, "volume_factor": 1, "min_oct": 1, "max_oct": 7},
            "bosen50": {"full_name": "bosendorfer piano 50", "start": 0, "csound_voice": 33, "time_tracker_number": 0, "volume_factor": 1, "min_oct": 1, "max_oct": 7},
            "bosen51": {"full_name": "bosendorfer piano 51", "start": 0, "csound_voice": 33, "time_tracker_number": 0, "volume_factor": 1, "min_oct": 1, "max_oct": 7},
            "bosen52": {"full_name": "bosendorfer piano 52", "start": 0, "csound_voice": 33, "time_tracker_number": 0, "volume_factor": 1, "min_oct": 1, "max_oct": 7},
            "bosen53": {"full_name": "bosendorfer piano 53", "start": 0, "csound_voice": 33, "time_tracker_number": 0, "volume_factor": 1, "min_oct": 1, "max_oct": 7},
            "bosen54": {"full_name": "bosendorfer piano 54", "start": 0, "csound_voice": 33, "time_tracker_number": 0, "volume_factor": 1, "min_oct": 1, "max_oct": 7},
            "bosen55": {"full_name": "bosendorfer piano 55", "start": 0, "csound_voice": 33, "time_tracker_number": 0, "volume_factor": 1, "min_oct": 1, "max_oct": 7},
            "bosen56": {"full_name": "bosendorfer piano 56", "start": 0, "csound_voice": 33, "time_tracker_number": 0, "volume_factor": 1, "min_oct": 1, "max_oct": 7},
            "bosen57": {"full_name": "bosendorfer piano 57", "start": 0, "csound_voice": 33, "time_tracker_number": 0, "volume_factor": 1, "min_oct": 1, "max_oct": 7},
            "bosen58": {"full_name": "bosendorfer piano 58", "start": 0, "csound_voice": 33, "time_tracker_number": 0, "volume_factor": 1, "min_oct": 1, "max_oct": 7},
            "bosen59": {"full_name": "bosendorfer piano 59", "start": 0, "csound_voice": 33, "time_tracker_number": 0, "volume_factor": 1, "min_oct": 1, "max_oct": 7},
            "bosen60": {"full_name": "bosendorfer piano 60", "start": 0, "csound_voice": 33, "time_tracker_number": 0, "volume_factor": 1, "min_oct": 1, "max_oct": 7},
            "bosen61": {"full_name": "bosendorfer piano 61", "start": 0, "csound_voice": 33, "time_tracker_number": 0, "volume_factor": 1, "min_oct": 1, "max_oct": 7},
            "bosen62": {"full_name": "bosendorfer piano 62", "start": 0, "csound_voice": 33, "time_tracker_number": 0, "volume_factor": 1, "min_oct": 1, "max_oct": 7},
            "bosen63": {"full_name": "bosendorfer piano 63", "start": 0, "csound_voice": 33, "time_tracker_number": 0, "volume_factor": 1, "min_oct": 1, "max_oct": 7},
            "bosen64": {"full_name": "bosendorfer piano 64", "start": 0, "csound_voice": 33, "time_tracker_number": 0, "volume_factor": 1, "min_oct": 1, "max_oct": 7},
            }
    for inx, voice in zip(count(0,1), voice_time):
            # logging.info(voice)
        voice_time[voice]["time_tracker_number"] = inx
    return (voice_time)


def find_root_mode(midi_file_name):
    """
    Analyze a MIDI file to determine its root note and mode (major/minor).
    
    Parameters
    ----------
    midi_file_name : str
        Path to the MIDI file to analyze.
    
    Returns
    -------
    tuple or int
        If successful: (root, mode, music21_stream)
            - root: int, pitch class (0-11) of the root note
            - mode: str, 'major' or 'minor'
            - music21_stream: music21.stream.Stream object
        If root not found: 9999
    """
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
    """
    Load a MIDI file and convert it to a chorale array with timing information.
    
    Parameters
    ----------
    file_name : str
        Path to the MIDI file to load.
    quantization : int, optional
        Quantization level (default: 4). Determines the time resolution.
        Higher values create finer time steps.
    
    Returns
    -------
    tuple
        (chorale, root_note, mode, time_sig)
        - chorale: np.ndarray, shape (voices, time_steps), MIDI note numbers
        - root_note: int, pitch class (0-11) of the root note
        - mode: str, 'major' or 'minor'
        - time_sig: str, time signature (e.g., '4/4')
    """
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
    """
    Read a MIDI file and convert it to a chorale array using muspy.
    
    Parameters
    ----------
    midi_file_name : str
        Path to the MIDI file to read.
    quantizer : int, optional
        Quantization level (default: 4). Controls time resolution.
    
    Returns
    -------
    tuple
        (chorale, root, mode, music21_stream, pit_cl_ent, pcu)
        - chorale: np.ndarray, shape (voices, time_steps), transposed MIDI notes
        - root: int, pitch class (0-11) of the root note
        - mode: str, 'major' or 'minor'
        - music21_stream: music21.stream.Stream object
        - pit_cl_ent: float, pitch class entropy of the chorale
        - pcu: int, number of pitch classes used (out of 12)
    """
    root, mode, s = find_root_mode(midi_file_name)
    # logging.info(f'{len(s) = }')
    music = muspy.from_music21(s, resolution=24) # convert the music21 object to a muspy object
    # logging.info(f'{len(music) = }')
    sample, root, mode, pit_cl_ent, pcu = muspy_to_sample_root_mode(music, quantizer = quantizer)  
    return sample.T, root, mode, s, pit_cl_ent, pcu

def midi_to_music21(midi_file_name, chorale_number):
    """
    Load a chorale from a numpy file and get its key information from a MIDI file.
    
    Parameters
    ----------
    midi_file_name : str
        Path to MIDI file used to determine root and mode.
    chorale_number : int
        Number used to construct the numpy filename ('chorale{chorale_number}.npy').
    
    Returns
    -------
    tuple
        (chorale, root, mode, music21_stream)
        - chorale: np.ndarray, shape (voices, time_steps), MIDI note numbers
        - root: int, pitch class (0-11) of the root note
        - mode: str, 'major' or 'minor'
        - music21_stream: music21.stream.Stream object
    """
    root, mode, s = find_root_mode(midi_file_name)
    logging.debug(f'just back from find_root_mode. {root = }')
    # mid = MidiFile(os.path.join(midi_file_name))
    numpy_file = 'chorale' + str(chorale_number) + '.npy'
    chorale = np.load(numpy_file)
    # chorale = np.concatenate((chorale, np.zeros((4,1),dtype=int)),axis = 1) # add a bit at the end so you don't loose the ending
    logging.debug(f'{chorale_number = }, {root = }, {mode = }, {chorale.shape = }')
    return chorale, root, mode, s

# this is passed a muspy music object - optimize quantizer
def muspy_to_sample_root_mode(music, quantizer = 4):
    """
    Convert a muspy music object to a sample array with root and mode information.
    
    Parameters
    ----------
    music : muspy.Music
        Muspy music object to convert.
    quantizer : int, optional
        Quantization level (default: 4). Controls time resolution.
        Higher values create finer time steps.
    
    Returns
    -------
    tuple
        (sample, root, mode, pit_cl_ent, pcu)
        - sample: np.ndarray, shape (time_steps, 4), MIDI note numbers per time step
        - root: int, pitch class (0-11) from key signature, or 0 if not found
        - mode: str, 'major' or 'minor', defaults to 'major' if not found
        - pit_cl_ent: float, pitch class entropy of the music
        - pcu: int, number of pitch classes used (out of 12)
    """
    if music.key_signatures != []: # check if the midi file includes a *key signature* - some don't
        root = music.key_signatures[0].root 
        mode = music.key_signatures[0].mode # major or minor
    else: 
        logging.debug('Warning: no key signature found. Assuming C major')
        mode = "major"
        root = 0    
    if music.time_signatures != []: # check if the midi file includes a *time signature* - some don't
        numerator = music.time_signatures[0].numerator
        denominator = music.time_signatures[0].denominator 
    else: 
        logging.debug('Warning: no time signature found. Assuming 4/4')
        numerator = 4
        denominator = 4
    # turn it into a piano roll
    piano_roll = muspy.to_pianoroll_representation(music, encode_velocity=False)
    q = music.resolution # quarter note value in this midi file. Default resolution is 24. 
#     beats = music.beats # list of beat times in seconds
    # This means each quarter note consumes 24 time slots. 1/8th note is 12, 1/16th note is 6. 
    # This implies that I could pick up every 6th note and get everything I need. Or compress the result by 6x. 
    q16 = q  // quantizer # 24 / 4 = 6 which equates to catching every 1/16th note. In some cases this is too little, or too much. I'll have to figure out how to determine this more systematically. I just created a dictionary that has the right quantizer value for each chorale. This will cause trouble later. 
    logging.debug(f'time signatures: {numerator}/{denominator}')
    time_steps = int(np.ceil(piano_roll.shape[0] / q16)) # the higher of the number of voices or q16
    logging.debug(f'music.resolution: {q = }. {q16 = }, {time_steps = } 1/16th notes. {piano_roll.shape = }') # q = 24
    # piano_roll.shape = (1537, 128) # 1537 time steps, midi notes from 0 - 127
    pit_cl_ent = muspy.pitch_class_entropy(music) # determine the pitch class entropy of the chorale
    pcu = muspy.n_pitch_classes_used(music)    # how many pitches were used out of the 12 possible
    # This loop is able to load an array of shape N,4 with the notes that are being played in each time step
    sample = np.zeros(shape=(time_steps, 4), dtype = int) # typical chorale has 257 time_steps. Lasso has more.   
    notes_in_chord = 0
    for click in np.arange(0, piano_roll.shape[0], q16): # send every 6th note in the piano roll to be processed
        time_interval = click // q16
        voice = 3 # assign the first to the low voices and decrement voice for the higher voices
        for inx in np.arange(piano_roll.shape[1]): #  check if any notes are non-zero, that will be the one-hot item
            note_in_chord = 0
            if (piano_roll[click][inx]): # if velocity anything but zero - unless you set encode_velocity = False
                  sample[time_interval][voice] = inx 
                  notes_in_chord += 1
                  voice -= 1 # next instrument will get the higher note. 
            if notes_in_chord < 4: logging.debug(f'{click = }, {inx = }, {notes_in_chord = }')
    logging.debug(f'{sample.shape = }') # (257, 4)
    while np.sum(sample[-1:] == 0): # if the last note is all zeros, remove it.
          sample = sample[0:-1,:]
          logging.debug(f'{sample.shape = }') # (256, 4)
    if np.sum(sample[-1:] == 0): # this should never execute
          sample = sample[0:-1,:]
          logging.debug(f'{sample.shape = }') # (256, 4)
    
    return (sample, root, mode, pit_cl_ent, pcu)     

def read_from_corpus(work, quantizer = 4):
    """
    Read a chorale from the music21 corpus and convert it to a chorale array.
    
    Parameters
    ----------
    work : str
        Corpus work identifier (e.g., 'bwv244.3' for Herzliebster).
    quantizer : int, optional
        Quantization level (default: 4). Controls time resolution.
    
    Returns
    -------
    tuple
        (chorale, root, mode, music21_stream)
        - chorale: np.ndarray, shape (voices, time_steps), MIDI note numbers
        - root: int, pitch class (0-11) of the root note
        - mode: str, 'major' or 'minor'
        - music21_stream: music21.stream.Stream object
    """
    s = m21.corpus.parse(work) # use music21 to pull a chorale from the corpus. For example Herzliebster is 'bwv244.3'
    # then immediately convert it to a muspy object. 
    
    muspy_object = muspy.from_music21(s)
    logging.debug(f'{muspy_object = }')
    sample, root, mode, pit_cl_ent, pcu = muspy_to_sample_root_mode(muspy_object, quantizer = quantizer)
    logging.debug(f'{sample.shape = }, {root = }, {mode = }, {round(pit_cl_ent,2) = }, {pcu = }')
    chorale = sample.T
    logging.debug(f'{chorale.shape = }')
    return chorale, root, mode, s


def read_from_numpy(chorale_number):
    """
    Load a chorale from a numpy file using a MIDI file for metadata.
    
    Parameters
    ----------
    chorale_number : int
        Number used to construct filenames:
        - MIDI: 'sample{chorale_number}.mid'
        - NumPy: 'chorale{chorale_number}.npy'
    
    Returns
    -------
    tuple
        (chorale, root, mode, music21_stream)
        - chorale: np.ndarray, shape (voices, time_steps), MIDI note numbers
        - root: int, pitch class (0-11) of the root note
        - mode: str, 'major' or 'minor'
        - music21_stream: music21.stream.Stream object
    """
    file_name = 'sample' + str(chorale_number) + '.mid' # pull from the set of synthetic chorales
    chorale, root, mode, s = midi_to_music21(file_name, chorale_number)
    return chorale, root, mode, s

# This function goes through the array of cents, octaves and builds a list of slides to deal with cent values that have the same midi note but different cent values.
# In other words, if the composer did not intend to have a new note at the point where the cent value changes, I will alter the chorale_in_cents array as follows:
# 1.    If two notes in a voice have the same 12 TET value, this indicates the composer intend them to be played as one note.
# 2.    If my tuning algorithm made them two different cent values, then this function will make them one note, but with a slide from the first cent value to the next.
# 3.    Downstream functions treat notes with any change in cent value, octave, or glide as a single note. 
#     All with the same values will sound as a single note
# this function should be called once for each chorale processed. 
def build_glides_array(chorale_in_cents_slides, keys, max_cents_slide=45):
    """
    Build an array of glides/slides for notes with same MIDI value but different cent values.
    
    When two consecutive notes in a voice have the same 12-TET value but different cent
    values, this function creates a glide between them rather than treating them as separate
    notes. The chorale_in_cents_slides array is modified in place to set all cent values
    in a glide region to the initial value, and a glide function table number is assigned.
    
    Parameters
    ----------
    chorale_in_cents_slides : np.ndarray
        Shape (voices, chords, 2). First dimension is cents, second is octaves.
        Modified in place.
    keys : np.ndarray
        Array of 12 note names for pitch class identification.
    max_cents_slide : int, optional
        Maximum cent difference allowed for a slide (default: 45).
        Slides are only created if 1 < abs(delta_cents) < max_cents_slide.
    
    Returns
    -------
    tuple
        (chorale_in_cents_slides, glides, stored_gliss, t_num)
        - chorale_in_cents_slides: np.ndarray, modified input array
        - glides: np.ndarray, shape (voices, chords), glide function table numbers (0 if no glide)
        - stored_gliss: np.ndarray, shape (N, 9), stored glide function table definitions
        - t_num: int, next available function table number
    """                       
    logging.debug(f'In build_glides_array. {chorale_in_cents_slides.shape = }, {chorale_in_cents_slides.shape[0:2] = }') # , {chorale_in_cents[:,:].shape = }
    t_num = 1500 # this is the number of the first ftable dedicated to slides
    glides = np.zeros(chorale_in_cents_slides.shape[0:2], dtype = int)
    logging.debug(f'{glides.shape = }')
    stored_fn = np.zeros(9, dtype = float)
    stored_gliss = dmu.init_stored_gliss(starting_location = t_num, values_in_ftable = stored_fn.shape[0]) # initialize the stored_gliss array 
    logging.info(f'{stored_gliss.shape = }')
    
    prev_chord_12 = np.zeros((4,), dtype = int)
    prev_chord_cents = np.zeros((4,), dtype = int)
    max_delta_cents = 0
    min_delta_cents = 0 
    # 12/10/23 changed logging.debug to logging.debug to surface the glides/slides

    for chord_num in np.arange(chorale_in_cents_slides.shape[1]): # some number of chords in every chorale.
        modified_chord = False
        chord_cents = chorale_in_cents_slides[:,chord_num,0] # this is the cent value
        octave = chorale_in_cents_slides[:,chord_num,1] # this is the octave value
        chord_12 = np.array([int(round(note / 100, 0) % 12) for note in chord_cents]) # original midi number
        note_names = np.array([keys[note] for note in chord_12])
        logging.debug(f'chord# {chord_num}, {chord_cents = }, {chord_12 = }, {note_names = }, {octave = }')
        for note_num, note_cents, note_12, prev_note_cents, prev_12 in zip(count(0), chord_cents, chord_12, prev_chord_cents, prev_chord_12):
            if note_12 == prev_12: # if the two notes have the same 12TET note value, then inspect their cent values for differences between adjacent time steps
                if note_cents > 1150: note_cents = note_cents - 1200
                if prev_note_cents > 1150: 
                     temp_prev_note_cents = prev_note_cents - 1200 # how does this affect downstream processing?
                else: temp_prev_note_cents = prev_note_cents
                delta_cents = note_cents - temp_prev_note_cents # calculate the cent value difference # 
            #     if abs(delta_cents) > 1: 
                logging.debug(f'checking slide size. {note_cents = }, {temp_prev_note_cents = }, {abs(delta_cents) = }')
                if 1 < abs(delta_cents) < max_cents_slide: # if it's more than 1 (should this be a larger slop value?) and less than max_cents_slide make the slide
                    modified_chord = True
                    logging.debug(f'starting the slide. voice_num = {note_num}, {note_cents = }, {prev_note_cents = }, {temp_prev_note_cents = }, {delta_cents = }')
                    max_delta_cents = np.max([max_delta_cents, delta_cents])
                    min_delta_cents = np.min([min_delta_cents, delta_cents])
                    logging.debug(f'{min_delta_cents = }, {max_delta_cents = }, {delta_cents = }')
                    logging.debug(f'same 12 TET note, {delta_cents = }, chord# {chord_num}, voice# {note_num}, {keys[prev_12]}, {temp_prev_note_cents = }, {note_cents = }')
                    
                    prev_chord_num = chord_num - 1 # set the lookback index to one prior to the current chord number 
                    while prev_note_cents == chorale_in_cents_slides[note_num, prev_chord_num,0] and prev_chord_num >= 0: # if the cent value is the same, keep going back
                        logging.debug(f'{prev_chord_num = }, chorale_in_cents_slides[{note_num}, {prev_chord_num}, 0]: {chorale_in_cents_slides[note_num,prev_chord_num, 0]}')
                        prev_chord_num -= 1
                    first_chord_num = prev_chord_num + 1 # store the first cent value equal to the one at the change
                    logging.debug(f'found first instance of {prev_note_cents = } at voice {note_num} in chord# {first_chord_num}')
                    next_chord_num = chord_num # start searching for all the time slots that have the second cent value 
                    # while note_cents == chorale_in_cents_slides[note_num, next_chord_num, 0] and next_chord_num < chorale_in_cents_slides.shape[1] - 1: 
                    while next_chord_num < chorale_in_cents_slides.shape[1] and note_cents == chorale_in_cents_slides[note_num, next_chord_num, 0]:
                        logging.debug(f'{next_chord_num = }, chorale_in_cents_slides[{note_num}, {next_chord_num}, 0]{chorale_in_cents_slides[note_num,next_chord_num, 0]}')
                        next_chord_num += 1
                    if next_chord_num == chorale_in_cents_slides.shape[1]: # if you are at the end of the array
                        next_chord_num += 1
                    last_chord_num = next_chord_num # store last one in the set equal to the one after the change
                    logging.debug(f'found last instance of {note_cents = } at voice# {note_num} in chord# {last_chord_num - 1}')
                    slide_array = chorale_in_cents_slides[note_num, first_chord_num:last_chord_num, 0] # a list of cents, some at the initial value, others at the target value
                    u, ind = np.unique(slide_array, return_index=True)
                    slide_unique_order_preserved = u[np.argsort(ind)]
                    logging.debug(f'need a slide from chord: {first_chord_num} to chord {last_chord_num} {slide_array = }, {slide_array.shape = }, {slide_unique_order_preserved = }')
                    ratio = round(np.power(2, delta_cents/1200), 6) # how large to make the slide, convert the cents to a decimal ratio. 6 decimal places is probably too many
                    logging.debug(f'{delta_cents = }, {ratio = }')
                    chorale_in_cents_slides[note_num, first_chord_num:last_chord_num, 0] = prev_note_cents # set the cents in all the identified time slots to the initial cent value 
                    logging.debug(f'about to fix the octaves across the slide. {chorale_in_cents_slides[note_num, first_chord_num:last_chord_num, 1] = }, {prev_note_cents = }')
                    if prev_note_cents > 1150: 
                        chorale_in_cents_slides[note_num, first_chord_num:last_chord_num, 1] = chorale_in_cents_slides[note_num, first_chord_num, 1]
                        logging.debug(f'after the fix octaves across the slide. {chorale_in_cents_slides[note_num, first_chord_num:last_chord_num, 1] = }')
                    logging.debug(f'chorale_in_cents_slides[{note_num}, {first_chord_num}:{last_chord_num}: {chorale_in_cents_slides[note_num, first_chord_num:last_chord_num, 0]}')
                    # smoothest array is this: f1504.0 0 256.0 -6 1 128 0.9860465 128 0.972093  
                    fn_array = np.array([t_num, 0, 256, -6, 1, 128, np.average((1, ratio)), 128, ratio]) # 'cubic64_64_128' segments of cubic polynomials,
                    logging.debug(f'{[round(item,3) for item in fn_array[[0,8]]] = }, {fn_array.shape = }')
                    # look in the table of gliss ftables for one that nearly exactly matches the one required here. Strip off the 0th element, that's the table number
                    found = False
                    if stored_gliss.shape[0] > 0:
                        for look_for_fn in stored_gliss:
                            # if this ftable array is in the stored_gliss array, then use it.
                            if np.allclose(fn_array[1:], look_for_fn[1:], rtol = 1e-4): # relative tolerance level is small: 0.0001
                                found = True
                                logging.debug(f'{found = }. Already stored this fn_array: {[round(item,3) for item in fn_array[[0,8]]] = } as ftable {look_for_fn[0] = }') 
                                logging.debug(f'assigning {look_for_fn[0]} ftable to glides[{note_num}, {first_chord_num}:{last_chord_num}]')
                                glides[note_num, first_chord_num:last_chord_num] = look_for_fn[0] # store the existing fn number in all the chords that need it
                    logging.debug(f'{found = }, {stored_gliss.shape = }')
                    if not found: # if you didn't find the array in the stored_gliss array, then store it there 
                        logging.debug(f'did not find the array in {stored_gliss.shape = }. store this array as glide {t_num} at glides[{note_num}, {first_chord_num}:{last_chord_num}]')
                        logging.debug(f'assigning {t_num} ftable to glides[{note_num}, {first_chord_num}:{last_chord_num}]')
                        glides[note_num, first_chord_num:last_chord_num] = t_num
                        stored_gliss = np.vstack((stored_gliss, fn_array))
                        logging.debug(f'In newly found, after vstack. {[round(item,3) for item in fn_array[[0,8]]] = }, {t_num = }, {stored_gliss.shape = }')
                        t_num += 1
        prev_chord_cents = chord_cents
        prev_chord_12 = chord_12   
        if modified_chord: logging.debug(f'chord# {chord_num}, {chord_cents = }, {chord_12 = }, {note_names = }, {octave = }')
    logging.info(f'{min_delta_cents = }, {max_delta_cents = }')
    logging.info(f'end of build_glides_array. {chorale_in_cents_slides.shape = }, {glides.shape = }, {stored_gliss.shape = }, {t_num = }')
    return chorale_in_cents_slides, glides, stored_gliss, t_num  


def mismatch_check(chorale_in_cents, chorale):
    """
    Check if pitch classes derived from cent values match original MIDI pitch classes.
    
    Parameters
    ----------
    chorale_in_cents : np.ndarray
        Shape (voices, chords), cent values for each note.
    chorale : np.ndarray
        Shape (voices, chords), original MIDI note numbers.
    
    Returns
    -------
    bool
        True if any mismatch is found between original MIDI pitch classes and
        pitch classes derived from cent values, False otherwise.
    """
    logging.debug(f'In mismatch_check. {chorale_in_cents.shape = }, {chorale.shape = }')
    mismatch = False
    prev_chord = np.zeros(4, dtype=int)
    for chord_num, chord_in_cents, chord_in_midi in zip(count(0,1), chorale_in_cents.T, chorale.T):
        if not np.array_equal(prev_chord, chord_in_midi):
                final_12 = np.array([int(round(note / 100,0) % 12) for note in chord_in_cents])
                original_12 = np.array([note % 12 for note in chord_in_midi])
                best_voicing = np.array([np.array_equal(original_12, voicing) for voicing in np.array(list(permutations(final_12)))])
                final_result = np.array(list(permutations(chord_in_cents)))[np.argmax(best_voicing)]
                final_12 = np.array([int(round(note / 100,0) % 12) for note in final_result])
                logging.debug(f'in mismatch_check in adaptive_tuing_util {chord_num= }, {final_12 = }, {original_12 = }')
                if not np.array_equal(final_12, original_12):
                    logging.debug(f'mismatch between the original MIDI notes {chord_num = }, {original_12 = }, {final_12 =  }')
                    logging.info(f'mismatch between the original MIDI notes {chord_num = }, {original_12  = }, {final_12 =  }')
                    logging.info(f'Original scale degrees: {original_12 % 12 = }\nScale degrees derived from the cent values: {final_12 = }')
                    logging.info(f'{original_12 % 12 = }')
                    mismatch = True
        prev_chord = np.copy(chord_in_midi)
    return mismatch

def _find_limit(ratio_string, penalize_7_11=False, multiply=False):
    """
    Calculate a limit value for a ratio string (e.g., "3/2" or "1").
    
    Parameters
    ----------
    ratio_string : str
        Ratio as string (e.g., "3/2" or "1" for 1/1).
    penalize_7_11 : bool, optional
        If True, multiply result by 3 if ratio contains primes 11, 13, 17, 19, 23, or 29
        (default: False).
    multiply : bool, optional
        If True, return numerator * denominator; if False, return numerator + denominator
        (default: False).
    
    Returns
    -------
    int
        Limit value: num*den if multiply=True, num+den otherwise.
        If penalize_7_11=True and ratio contains penalized primes, result is multiplied by 3.
    """
    if len(ratio_string) == 1: # Fraction returns a '1' for the ratio 1/1. All other Fraction ops return a ratio
        den_str = ratio_string
        num_str = '1'
    else:
        num_str, den_str = ratio_string.split('/')
    
    num = int(num_str)
    den = int(den_str)
    
    if multiply:
        max_num_den = num * den
    else:
        max_num_den = num + den

    if penalize_7_11: # penalize these prime numbers greater than 7 and less than 31: 11, 13, 17, 19, 23, 29
        primes_to_penalize = {'11', '13', '17', '19', '23', '29'}
        if any(p in ratio_string for p in primes_to_penalize):
                max_num_den *= 3
    return max_num_den  

# this builds an array of ratio, cents, num_dem for each ratio in the tonality diamond. If penalize_7_11, then double the value of num_dem
def build_tonal_diamond(limit_value, limit_denominator=50, penalize_7_11=False, multiply=False):
    """
    Build a tonal diamond array with ratios, cent values, and limit scores.
    
    Creates an array of all ratios in the tonality diamond up to the specified limit,
    converts them to cents, and calculates limit scores (sum or product of numerator
    and denominator).
    
    Parameters
    ----------
    limit_value : int
        Prime limit for the tonality diamond (e.g., 31 for 31-limit).
    limit_denominator : int, optional
        Maximum denominator when converting ratios to fractions (default: 50).
    penalize_7_11 : bool, optional
        If True, penalize ratios containing primes > 7 (default: False).
    multiply : bool, optional
        If True, limit score is num*den; if False, num+den (default: False).
    
    Returns
    -------
    np.ndarray
        Shape (N, 3) where N is the number of unique ratios. Each row contains:
        [ratio, cents, limit_score]
        - ratio: float, just intonation ratio
        - cents: int, cent value (rounded)
        - limit_score: int, complexity score based on numerator/denominator
    """
    tonal_diamond_ratios = np.array(dmu.build_all_ratios(limit_value = limit_value)) # assemble an array floating point ratios to the 31 limit # limit_value = limit_value
    tonal_diamond_ratios = np.append(tonal_diamond_ratios, [2.0], axis=0) # add 2:1 to the end of the array to make 257.
    tonal_diamond_ratios = np.unique(tonal_diamond_ratios, axis = 0) # reduce from 256 to a sorted list of 214 values
    # ratio, cents, num_dem
    # you now have a list of all the ratios in the tonality diamond to the 31 limit 
    # convert the ratios to cents. 
    tonal_diamond_cents = np.array([int(round(dmu.ratio_to_cents(just_ratio),0)) for just_ratio in tonal_diamond_ratios])
    # You now have a list of cent values that are within the tonality diamond to the 31 limit
    # assemble a list of numerators and denominators for all of the values in the ratio and cent arrays
    tonal_diamond_num_den = np.array([_find_limit(str(Fraction(just_ratio).limit_denominator(limit_denominator)), penalize_7_11=penalize_7_11, multiply=multiply) for just_ratio in tonal_diamond_ratios])

                
    # this array will enable you to score based on the numerators and denominators of the ratios to the 31 limit
    # Each array has 214 values, assuming limit_value = 31. 66 for limit_max=17
    tonal_diamond_values = np.array([(ratio, cents, num_dem) for ratio, cents, num_dem in zip(tonal_diamond_ratios, tonal_diamond_cents, tonal_diamond_num_den)])
    logging.debug(f'{[var.shape for var in [tonal_diamond_ratios, tonal_diamond_cents, tonal_diamond_num_den, tonal_diamond_values]]}') 
    # for limit_value = 31: this results in [(214,), (214,), (214, 3)]
    # from now on, the arrays are sorted, so you can use np.searchsorted to find where the desired value would go if it existed. 
    logging.info(f'{limit_value = }, {limit_denominator = }, {tonal_diamond_values.shape = }')
    return tonal_diamond_values

stringify = lambda x: '1/1' if x == 1 else str(Fraction(x).limit_denominator(50))

# when provided with a 4 note chord in midi_numbers (0-127) this function returns the steps in cents (1200 EDO)
# I assign values based on the 12TET cent values. 
def note_to_1200_edo(midi_numbers, original_12 = np.arange(0, 1200, 100)):
    """
    Convert MIDI note numbers to 1200-EDO cent values.
    
    Parameters
    ----------
    midi_numbers : np.ndarray
        Array of MIDI note numbers (0-127). Zero indicates silence.
    original_12 : np.ndarray, optional
        Array of 12 cent values for pitch classes (default: [0, 100, 200, ..., 1100]).
    
    Returns
    -------
    np.ndarray
        Array of cent values. Zero MIDI numbers are converted to -1.
        Returns zeros if all input values are zero.
    """
    # Convert a midi_number value of zero to -1. 0 indicates no number in this midi time_step format.
    if np.sum(midi_numbers) == 0: # watch out for a chord of all zeros. That's not right.
        logging.debug(f'{midi_numbers = }')
        return np.zeros(4, dtype = int)
    # convert all the midi_numbers to steps in cents unless 0
    ifzero = lambda num: -1 if num == 0 else original_12[num % 12] # do I still need this? Yes because otherwise you end up with zeros in notes.
    step_in_1200_edo = np.array([ifzero(note) for note in midi_numbers]) # execute the lambda function in a list comprehension
    # at this point you have converted the notes with zero values to another note value in the chord, so it won't influence the interval calculations.
    return step_in_1200_edo

def limit_format(values):
    """
    Format tonal diamond values as (ratio_string, cents, limit_score).
    
    Parameters
    ----------
    values : array-like
        Array of [ratio, cents, num_dem] from tonal diamond.
    
    Returns
    -------
    tuple
        (ratio_string, cents, num_dem)
        - ratio_string: str, formatted ratio (e.g., "3/2" or "1/1")
        - cents: int, rounded cent value
        - num_dem: int, limit score
    """
    # this function expects three values, and can't handle fewer. 
    ratio = values[0]
    cents = values[1]
    num_dem = values[2]
    return stringify(ratio), int(round(cents)), int(num_dem)

# generate a sequence of 0, -1, 1, -2, 2, -3, 3 up to the max_value
def sequence_generator(max_value):
    """
    Generate a sequence of integers: 0, -1, 1, -2, 2, ..., -max_value, max_value.
    
    Parameters
    ----------
    max_value : int
        Maximum absolute value in the sequence.
    
    Yields
    ------
    int
        Sequence: 0, then alternating negative and positive values up to max_value.
    """
    paired_values = max_value 
    yield 0
    for n in range(1, paired_values + 1):
          yield -n
          yield n

# The goal of this function is to find the optimal index into the tonal diamond based on these criteria:
# If you find an interval distance that matches a cent value in the tonal_diamond (ratio, cents, sum(num + den)) or 
# the one that is just below the value of the distance if the distance value were to be inserted. 
# Then, starting at that position search up and down alternatively through the tonal_diamond based on the value of tolerance
# for ratios whose cents value is closest to the distance value. The one that matches distance is considered qualified. 
# It stores the cost of the ratio (sum(num,den)) as min_score and continues to search within the tolerance looking
# for one that has a lower score. The one with the lowest score is returned as min_loc. It's the starting point for 
# the collection of intervals to consider for the target distance. 
# If none exactly match the distance, the ratio slightly smaller than distance is returned. 
def best_ratio_index(distance, tolerance, tonal_diamond):
    """
    Find the optimal index into the tonal diamond for a given interval distance.
    
    Searches within tolerance range for ratios matching the distance, preferring
    those with lower limit scores (more consonant intervals).
    
    Parameters
    ----------
    distance : float
        Interval distance in cents (absolute value is used).
    tolerance : int
        Search range: checks distance ± tolerance.
    tonal_diamond : np.ndarray
        Shape (N, 3) tonal diamond array [ratio, cents, limit_score].
    
    Returns
    -------
    int
        Index into tonal_diamond of the best matching ratio (lowest limit_score
        within tolerance). If no exact match found, returns index of closest
        ratio below the distance.
    """
    logging.debug(f'{distance = }, {tolerance = }, {tonal_diamond.shape = }')
    min_score = 9999
    min_loc = 9999
    distance = np.abs(distance)
    for gap in sequence_generator(tolerance):
        index_to_limits = np.min([np.searchsorted(tonal_diamond[:, 1], distance + gap), tonal_diamond.shape[0] - 1])
        logging.debug(f'in best_ratio_index. {index_to_limits = }, {distance + gap = }, {tonal_diamond[index_to_limits, 1] = }')
        if tonal_diamond[index_to_limits, 1] == distance + gap:  
                if tonal_diamond[index_to_limits, 2] < min_score:
                    min_score = tonal_diamond[index_to_limits, 2]
                    min_loc = index_to_limits
    if min_loc == 9999: min_loc = index_to_limits # if the tolerance is not sufficient to find a ratio at all
    
    logging.debug(f'{min_loc = }, {min_score = }, {distance = }, {tolerance = }, {tonal_diamond.shape = }')
    return min_loc


# the hotter the temperature (closer to 1.0) the more likely it will choose values that are less optimal. As it cools, it is more likely to choose the optimum. 
def annealing(temperature, range = 7):
    """
    Calculate annealing range based on temperature.
    
    Higher temperature (closer to 1.0) allows exploration of less optimal values.
    Lower temperature favors optimal choices.
    
    Parameters
    ----------
    temperature : float
        Temperature value (typically 0.0 to 1.0).
    range : int, optional
        Maximum range value (default: 7).
    
    Returns
    -------
    int
        Rounded integer: range * temperature
    """ 
    return int(np.round(range * temperature,0))



# # This routine rearranges the notes in the chord so that they match the original midi note order. It can accept either pitch class or midi value.
def rearrange_notes(chord_in_cents, midi_notes):
    """
    Rearrange chord notes to match the original MIDI note order.

    For each target pitch class from midi_notes, finds the tuned cent value
    in chord_in_cents with the matching pitch class. Uses direct matching
    instead of permutation enumeration, so it scales to any chord size.

    Parameters
    ----------
    chord_in_cents : np.ndarray
        Array of cent values (may be in wrong order).
    midi_notes : np.ndarray
        Array of MIDI note numbers or pitch classes (target order).

    Returns
    -------
    tuple
        (final_result, final_12)
        - final_result: np.ndarray, rearranged cent values matching MIDI order
        - final_12: np.ndarray, pitch classes (0-11) of final_result
    """
    original_midi_12 = midi_notes % 12
    tuned_12 = np.array([int(round(note / 100, 0) % 12) for note in chord_in_cents])
    final_result = np.zeros_like(chord_in_cents)
    matched = np.zeros(len(chord_in_cents), dtype=bool)
    used = np.zeros(len(chord_in_cents), dtype=bool)
    for i, target_pc in enumerate(original_midi_12):
        for j, tuned_pc in enumerate(tuned_12):
            if not used[j] and tuned_pc == target_pc:
                final_result[i] = chord_in_cents[j]
                used[j] = True
                matched[i] = True
                break
    # Fill any unmatched positions with remaining unused tuned values
    if not matched.all():
        unused_indices = np.where(~used)[0]
        unmatched_indices = np.where(~matched)[0]
        for k, idx in enumerate(unmatched_indices):
            if k < len(unused_indices):
                final_result[idx] = chord_in_cents[unused_indices[k]]
    final_12 = np.array([int(round(note / 100, 0) % 12) for note in final_result])
    return final_result, final_12

def find_best_top_note(final_result, final_12, top_notes):
    """
    Find gaps between chord notes and top_notes target values.
    
    Calculates the cent differences needed to align chord notes with prioritized
    top_notes values.
    
    Parameters
    ----------
    final_result : np.ndarray
        Array of 4 cent values for the chord.
    final_12 : np.ndarray
        Array of 4 pitch classes (0-11) for the chord.
    top_notes : np.ndarray
        Shape (2, 12). Row 0: MIDI pitch classes, Row 1: target cent values.
        Columns ordered by priority.
    
    Returns
    -------
    tuple
        (top_note_gap, final_result_gap)
        - top_note_gap: np.ndarray, shape (12), gaps for each top_note (0 if no match)
        - final_result_gap: np.ndarray, shape (4), gaps for each chord note (0 if no match)
    """
    # This function is used help transpose the chord based on the chord_in_cents and the top_notes.
    # It returns the gaps between the top_notes and the final result in one array, and the final_result to the top_notes in the second array.
    # for each of the cent values in the chord and each of the cent value in top_notes
    # In other words how far should you move the chord so that at least one of the notes in the final_result is on the top_note cent value.
    # I also need to check to see if we are dealing with two C♮ notes, one less than 50 cents and the other more that 1150 cents. 
    logging.debug(f'in find_best_top_note. {top_notes.shape = }') #  (2, 12)
    top_note_gap = np.zeros(12, dtype=int)
    final_result_gap = np.zeros(4, dtype=int)
    for inx1, (top_note_midi, top_cent) in zip(count(0,1), top_notes.T): # for each of the cent values in top_notes
        for inx2, cent_value, final_midi in zip(count(0,1), final_result, final_12): # step through all four cent values in final_result
                if top_note_midi == final_midi:
                    delta = cent_value - top_cent
                    logging.debug(f'{delta = }, {cent_value = }, {top_cent = }')
                    if abs(delta) > 1150:
                            delta = 1200 - delta
                            logging.debug(f'after swapping {top_cent} for {cent_value} new value for {delta = }')
                    top_note_gap[inx1] = delta # the gap for the top_note 
                    final_result_gap[inx2] = delta # the gap for the final_result
    logging.debug(f'{top_note_gap = }, {final_result_gap = }')
    return top_note_gap, final_result_gap
                        
def transpose_top_notes(final_result, top_notes, chord_number, midi_notes):
    """
    Transpose a chord to align with top_notes priorities without changing MIDI values.
    
    Attempts to transpose the chord so at least one note matches a top_notes value,
    prioritizing higher-priority top_notes. Checks that transposition doesn't change
    any MIDI pitch classes.
    
    Parameters
    ----------
    final_result : np.ndarray
        Array of 4 cent values for the chord.
    top_notes : np.ndarray
        Shape (2, 12). Row 0: MIDI pitch classes, Row 1: target cent values.
        Columns ordered by priority.
    chord_number : int
        Chord index (for logging).
    midi_notes : np.ndarray
        Array of 4 MIDI note numbers (target order).
    
    Returns
    -------
    tuple
        (final_result, gap, gap_too_big)
        - final_result: np.ndarray, transposed cent values (or original if no valid transposition)
        - gap: int, cent shift applied (0 if none)
        - gap_too_big: bool, True if transposition would change MIDI values
    """
    # This function is presented with a tuned chord, and an array of top_notes with (12TET value, cent value)
    # First it rearranges the notes so that are back in the right order based on how they were written.
    # This function tranposes the chord so that the cent values will have the same cent value as one of the top_notes cent values. 
    # It starts with the highest priority top_notes and moves down to the least important note in the chord.
    # It finds notes in the chord that are also in the top_notes. The first one found becomes the target for the transposition.
    # If it would change the midi value of any note, we proceed to a lower priority note in the top_notes. 
    # It also now (8/26/25) checks if the transposition would create a large cent gap between a note and the same midi value in the prior note.
    # For example, if C♮ midi value in the previous chord has a cent value of 16, and the C♮ in the current chord has a cent value of 1168,
    # that is a gap of 48 cents, which sounds terrible. 
    # If we can catch it early, there is still a chance to find a tuning that doesn't have this problem
    keys = np.array(['C♮', 'C♯', 'D♮', 'D♯', 'E♮', 'F♮', 'F♯', 'G♮', 'G♯', 'A♮', 'A♯', 'B♮'])
    logging.debug(f'in transpose_top_notes: begin: {midi_notes % 12 = }, {chord_number = }, {final_result = }')
    final_result, final_12 = rearrange_notes(final_result, midi_notes) 
    logging.info(f'in transpose_top_notes: after rearranging notes: {final_result = }, {final_12 = }')
    # generate a list of the gaps for each of the top notes for this particular chord
    top_note_gaps, final_result_gaps = find_best_top_note(final_result, final_12, top_notes)
    logging.info(f'in transpose_top_notes: {top_note_gaps = }, {final_result_gaps = }, {chord_number = }')
    gap_too_big = True
    # Go through these in the order of the top_note_gap array. Highest priority cent values are first in the top_notes array.
    
    for inx, top_note_gap in zip(count(0,1), top_note_gaps): 
        logging.info(f'in transpose_top_notes: looping through the top_note_gaps: {inx}: {top_note_gap = }, {top_notes.shape = }')
        top_note_midi = top_notes[0][inx] # pull the midi value from the top_notes # this fails if we go too far into top_notes array. 
        top_note_cent = top_notes[1][inx] # the ideal cent value from top_notes
        for inx2, gap in zip(count(0,1), final_result_gaps): # step through the gaps between the final_result cent values and those required by top_cent
                if final_12[inx2] == top_note_midi:
                    logging.info(f'in transpose_top_notes: current and ideal values for --> {final_12[inx2] = }, {final_result[inx2] = }, {top_note_midi = }, {top_note_cent = }')
                    logging.info(f'in transpose_top_notes: These two should match --> {top_note_gap = }, {gap = }')
                    proposed_final_cent = (final_result - gap) % 1200 # see if this gap value will change the midi notes in any way
                    proposed_final_12 = np.array([int(round(note / 100, 0)) % 12 for note in proposed_final_cent])
                    logging.info(f'in transpose_top_notes: {proposed_final_cent = }, {proposed_final_12 = }')
                    if np.array_equal(proposed_final_12, final_12 % 12): # if the proposed midi values are all the same as the original values
                            gap_too_big = False
                            logging.info(f'in transpose_top_notes: made a transposition to the chord. {gap = } {proposed_final_cent = } ')
                            logging.info(f'in transpose_top_notes: end: {gap_too_big = }, {chord_number = }')
                    else:
                            gap_too_big = True
                    # you now have one valid proposed_final_cent chord. But it might not be the best one. A lower priority one may be better for some notes. 
    
    logging.debug(f'in transpose_top_notes: end: {proposed_final_cent, gap_too_big }')
    return final_result, gap, gap_too_big

# these are helper functions for transpose_top_notes_v2
# originally written by Edge Copilot, modified by me
def cent_distance_mod_1200(a, b):
    """
    Minimal absolute distance in cents between two pitches a and b,
    measured on a 1200-cent circle (one octave).
    
    Parameters
    ----------
    a : float
        First cent value.
    b : float
        Second cent value.
    
    Returns
    -------
    float
        Minimal wrapped distance in cents (0-600).
    """
    diff = abs(a - b) % 1200
    return min(diff, 1200 - diff)

def signed_delta_mod_1200(current, target):
    """
    Minimal signed shift (in cents) to move `current` to `target` on the 1200-cent circle.
    Range: (-600, 600].
    
    Parameters
    ----------
    current : float
        Current cent value.
    target : float
        Target cent value.
    
    Returns
    -------
    float
        Signed shift in cents, range (-600, 600].
    """
    d = (target - current) % 1200
    if d > 600:
        d -= 1200
    return d

def circular_span(values, octave=1200):
    """Minimum arc on a circle of circumference `octave` that covers all values.

    Handles the octave-boundary artifact (e.g. C♮ values near 0 and 1200
    that are musically close but numerically distant).

    Parameters
    ----------
    values : sequence of float
        Cent values for one pitch class (already in [0, octave) range).
    octave : float
        Circle circumference in cents (default 1200).

    Returns
    -------
    (span, lo, hi) : (float, float, float)
        span  — minimum arc in cents covering all values (0 if len < 2)
        lo    — lowest value on the arc (start after the largest gap)
        hi    — highest value on the arc (end of the arc)
    """
    if len(values) < 2:
        v = values[0] if values else 0.0
        return 0.0, v, v
    sv = sorted(values)
    n = len(sv)
    # Gaps between consecutive sorted values, plus the wrap-around gap
    gaps = [sv[i + 1] - sv[i] for i in range(n - 1)]
    gaps.append(octave - sv[-1] + sv[0])
    max_gap_idx = max(range(n), key=lambda i: gaps[i])
    span = octave - gaps[max_gap_idx]
    lo = sv[(max_gap_idx + 1) % n]
    hi = sv[max_gap_idx]
    return span, lo, hi


def circular_mad(values, octave=1200):
    """Mean absolute deviation from the circular mean (lower = more tightly clustered).

    Unlike circular_span (which is a range measure), this rewards having most values
    clustered near the mean even when a few outliers are present.  A single outlier
    at the far end of the circle contributes one large distance to the average, but
    the remaining tightly-clustered values keep the mean low.

    Handles the octave-boundary wrap: values near 0 and near `octave` are treated
    as close, matching the behaviour of circular_span.

    Parameters
    ----------
    values : sequence of float
        Cent values for one pitch class (already in [0, octave) range).
    octave : float
        Circle circumference in cents (default 1200).

    Returns
    -------
    float
        Mean absolute deviation in cents (0 if len < 2).
    """
    if len(values) < 2:
        return 0.0
    theta = np.array([2.0 * np.pi * v / octave for v in values])
    mean_sin = np.mean(np.sin(theta))
    mean_cos = np.mean(np.cos(theta))
    mean_angle = np.arctan2(mean_sin, mean_cos) % (2.0 * np.pi)
    mean_cents = mean_angle * octave / (2.0 * np.pi)
    diffs = np.abs(np.array(values, dtype=float) - mean_cents) % octave
    diffs = np.minimum(diffs, octave - diffs)
    return float(np.mean(diffs))


def wrap1200(x):
    """
    Wrap values to [0, 1200) range.
    
    Parameters
    ----------
    x : array-like or scalar
        Values to wrap.
    
    Returns
    -------
    np.ndarray or scalar
        Values wrapped modulo 1200.
    """
    return np.mod(x, 1200.0)

def wrap600(x):
    """
    Wrap values to [-600, 600) range.
    
    Parameters
    ----------
    x : array-like or scalar
        Values to wrap.
    
    Returns
    -------
    np.ndarray or scalar
        Values wrapped to [-600, 600) range.
    """
    w = np.mod(x, 1200.0)
    return np.where(w >= 600.0, w - 1200.0, w)

def wrap6(x):
    """
    Wrap values to [-6, 6) range (for pitch classes).
    
    Parameters
    ----------
    x : array-like or scalar
        Values to wrap.
    
    Returns
    -------
    np.ndarray or scalar
        Values wrapped to [-6, 6) range.
    """
    w = np.mod(x, 12)
    return w - 12 if w >= 6 else w

def wrap12(x):
    """
    Wrap values to [0, 12) range (for pitch classes).
    
    Parameters
    ----------
    x : array-like or scalar
        Values to wrap.
    
    Returns
    -------
    np.ndarray or scalar
        Values wrapped modulo 12.
    """
    return np.mod(x, 12)

def pitch_class_from_cents(cents, eps=1e-6):
    """
    Convert cent values to pitch classes (0-11) using half-up rounding.
    
    Parameters
    ----------
    cents : array-like or scalar
        Cent values to convert.
    eps : float, optional
        Small epsilon to handle values near 1200 (default: 1e-6).
    
    Returns
    -------
    np.ndarray or int
        Pitch classes (0-11) corresponding to the cent values.
    """
    cents = np.asarray(cents, dtype=float)
    wrapped = np.mod(cents + eps, 1200.0)
    pcs = np.floor((wrapped + 50.0) / 100.0).astype(int) % 12
    return pcs


def force_pitch_class_match(chord_in_cents, midi_notes):
    """
    Adjust cent values minimally so their rounded pitch classes match midi_notes % 12.
    
    Parameters
    ----------
    chord_in_cents : np.ndarray
        Array of cent values to adjust.
    midi_notes : np.ndarray
        Array of MIDI note numbers (target pitch classes).
    
    Returns
    -------
    np.ndarray
        Adjusted cent values with pitch classes matching midi_notes % 12.
    """
    adjusted = np.array(chord_in_cents, dtype=float, copy=True)
    targets = np.array(midi_notes % 12, dtype=int)
    current_pcs = pitch_class_from_cents(adjusted)
    raw_deltas = (current_pcs - targets) % 12
    signed_deltas = np.where(raw_deltas > 6, raw_deltas - 12, raw_deltas)

    if signed_deltas.size > 0 and np.all(signed_deltas == signed_deltas[0]) and signed_deltas[0] != 0:
        shift_cents = -signed_deltas[0] * 100.0
        adjusted = (adjusted + shift_cents + 1200.0) % 1200.0
        current_pcs = pitch_class_from_cents(adjusted)

    current_octaves = np.floor_divide(adjusted, 1200.0)
    for idx, target_pc in enumerate(targets):
        current_pc = current_pcs[idx]
        if current_pc == target_pc:
                continue
        desired_cent = target_pc * 100.0
        current_mod = np.mod(adjusted[idx], 1200.0)
        shift = signed_delta_mod_1200(current_mod, desired_cent)
        adjusted[idx] += shift
        current_pcs[idx] = pitch_class_from_cents(adjusted[idx])
        if current_pcs[idx] != target_pc:
                adjusted[idx] = desired_cent + current_octaves[idx] * 1200.0
                current_pcs[idx] = target_pc
    return adjusted

# def cent_value_interval(interval, max_value=1200):
#       delta = int(wrap600(interval[0] - interval[1])) # wrap the difference, not the difference between wrapped values
#       moves = 1 if delta < 0 else -1
#       delta = np.abs(delta)
#       target = (interval[0] + (delta * moves)) % max_value
#       return delta, moves, target
def cent_value_interval(interval, max_value=1200):
    """
    Calculate interval between two cent values with wrapping.
    
    Parameters
    ----------
    interval : array-like
        Array of [cent1, cent2] values.
    max_value : int, optional
        Maximum value for wrapping (default: 1200).
    
    Returns
    -------
    tuple
        (delta, moves, target)
        - delta: int, absolute interval size in cents
        - moves: int, direction (-1 or 1)
        - target: int, target cent value after applying interval
    """
    wrapped = wrap600(interval[0] - interval[1])
    delta = np.asarray(wrapped, dtype=int)  # Convert to int array, not scalar
    moves = np.where(delta < 0, 1, -1)  # Element-wise comparison
    delta = np.abs(delta)
    target = (interval[0] + (delta * moves)) % max_value
    return delta, int(moves), target

def pitch_class_interval(interval, max_value=12):
    """
    Calculate interval between two pitch classes with wrapping.
    
    Parameters
    ----------
    interval : array-like
        Array of [pc1, pc2] pitch classes (0-11).
    max_value : int, optional
        Maximum value for wrapping (default: 12).
    
    Returns
    -------
    tuple
        (delta, moves, target)
        - delta: int, absolute interval size in semitones
        - moves: int, direction (1 or -1)
        - target: int, target pitch class after applying interval
    """
    delta = wrap6(interval[1] - interval[0])  # wrap the difference, not the difference between wrapped values
    moves = 1 if delta >= 0 else -1
    delta = abs(delta)
    target = (interval[0] + moves * delta) % max_value
    return delta, moves, target

def cent_interval_to_pitch_class(c1, c2):
    """
    Calculate pitch class difference between two cent values.
    
    Parameters
    ----------
    c1 : float
        First cent value.
    c2 : float
        Second cent value.
    
    Returns
    -------
    int
        Pitch class difference (0-11).
    """
    delta, moves, _ = cent_value_interval(np.array([c1, c2]))
    return pitch_class_from_cents(delta * moves)

import numpy as np

def resolve_cent_conflicts_with_pcfunc(cent_values, pitch_class_from_cents):
    """
    Resolve conflicts where multiple cent values map to the same pitch class.
    Keeps the cent value closest to a 100-cent boundary.
    
    Parameters
    ----------
    cent_values : np.ndarray
        Array of cent values (0–1200).
    pitch_class_from_cents : callable
        Function that maps cent values -> pitch classes.
    
    Returns
    -------
    np.ndarray
        Adjusted cent values with conflicts resolved. When multiple values map
        to the same pitch class, all are set to the value closest to a 100-cent
        boundary (e.g., 0, 100, 200, etc.).
    """
    adjusted = cent_values.copy()
    pitch_classes = pitch_class_from_cents(adjusted)
    unique_classes = np.unique(pitch_classes)
    
    for pc in unique_classes:
        idxs = np.where(pitch_classes == pc)[0]
        if len(idxs) > 1:
            # compute distance to nearest 100-cent boundary
            distances = np.abs(adjusted[idxs] - np.round(adjusted[idxs] / 100) * 100)
            # choose the index with the smallest distance
            keep_idx = idxs[np.argmin(distances)]
            keep_value = adjusted[keep_idx]
            # set all others to the chosen value
            adjusted[idxs] = keep_value
    
    return adjusted

def transpose_top_notes_v2(chord, midi_notes, top_notes, prev_chord_cents=None, next_chord_cents=None, max_gap=40):
    """
    Compute and apply a uniform transposition (in cents) so that at least one voice
    aligns to a prioritized list of target cent values (top_notes), WITHOUT changing
    any voice's MIDI pitch-class. Also enforces prev/next chord gap limits using
    minimal wrapped distances (fixes the 1168¢ vs 16¢ = 48¢ issue).

    Args:
        chord_cents: array-like of cents for the current chord (length V).
        midi_notes: array-like of MIDI notes (0–127) for the same voices (length V).
        top_notes: np.array shape (2, N). Row 0 is MIDI pitch-class (0–11),
                   row 1 is target cents for that class. Column order = priority.
        prev_chord_cents, next_chord_cents: optional arrays of cents (length varies).
        max_gap: maximum allowed wrapped distance (in cents) to matching pitch-classes
                 in prev/next chords.

    Returns:
        transposed_cents, chosen_shift, chosen_target
            - transposed_cents: list of cents after applying the chosen shift
            - chosen_shift: the uniform shift in cents applied (signed, (-600, 600])
            - chosen_target: tuple (target_pc, target_cent) that determined the shift

        Returns (None, None, None) if no valid transposition exists
    """
#     chord = np.asarray(chord_cents, dtype=float) % 1200
#     midi_notes = np.asarray(midi_notes, dtype=int)
    gmin = 0
    orig_pc = midi_notes % 12  # use the given MIDI as ground truth for voice classes
    orig_pc = np.array([int(round(note / 100,0)) for note in chord])
    # Prepare prev/next data (if provided)
    prev_arr = None
    prev_pc = None
    if prev_chord_cents is not None:
        prev_arr = np.asarray(prev_chord_cents, dtype=int) % 1200
        prev_pc = pitch_class_from_cents(prev_arr)
    logging.debug(f'{prev_chord_cents = }, {prev_pc = }')
    logging.debug(f'{chord, orig_pc = }')
    next_arr = None
    next_pc = None
    if next_chord_cents is not None:
        next_arr = np.asarray(next_chord_cents, dtype=int) % 1200
        next_pc = pitch_class_from_cents(next_arr)

    # Build candidate uniform shifts from top_notes priorities:
    # For each target (pc, cent), for every matching voice with that pc,
    # propose the minimal signed shift to align that voice’s cent to the target cent.
#     top_notes = np.asarray(top_notes, dtype=float)
    target_pcs = top_notes[0, :].astype(int)
    target_cents = top_notes[1, :].astype(int)
#     logging.debug(f'{target_pcs = }, {target_cents = }')
    candidate_shifts = []
    candidate_targets = []  # (pc, target_cent)

    for k in range(top_notes.shape[1]):
        t_pc = int(target_pcs[k]) % 12
        t_cent = target_cents[k] % 1200
        matches = np.where(orig_pc == t_pc)[0]
      #   logging.debug(f'{matches = }, {t_pc = }, {t_cent = }, {orig_pc = }')
        if matches.size == 0:
            continue
        for v in matches:
            s = signed_delta_mod_1200(chord[v], t_cent)  # shift to move chord[v] to t_cent
            candidate_shifts.append(s)
            candidate_targets.append((t_pc, t_cent))
    logging.debug(f'{candidate_shifts = }, {candidate_targets = }')
    if not candidate_shifts:
        # best.tolist(), float(best_shift), (int(best_target[0]), float(best_target[1])), True  
        logging.info(f'Could not find candidate_shifts for this set of cents. {chord, midi_notes = }')
        return None, None, (None, None), False, gmin

    # Deduplicate near-identical shifts to keep evaluation small
    uniq = {}
    for s, tgt in zip(candidate_shifts, candidate_targets):
        key = round(float(s), 6)
        if key not in uniq:
            uniq[key] = (s, tgt)
    candidate_shifts = [v[0] for v in uniq.values()]
    candidate_targets = [v[1] for v in uniq.values()]
    logging.debug(f'after eliminating duplicates: {candidate_shifts = }, {candidate_targets = }')
    best = None
    best_score = np.inf
    best_shift = None
    best_target = None

    # Scoring weights
    w_shift = 1.0  # prefer smaller absolute shifts
    w_prev = 1.0   # prefer small prev gaps
    w_next = 1.0   # prefer small next gaps # I didn't ask for this, but maybe it's a good idea. 

    for s, tgt in zip(candidate_shifts, candidate_targets):
        proposed = (chord + s) % 1200
        proposed_pc = pitch_class_from_cents(proposed)
        logging.debug(f'first proposed after shift: {proposed = }, midi of proposed {proposed_pc = }, {np.array_equal(proposed_pc, orig_pc) = }')
        # Do not change any voice's MIDI pitch-class
        if not np.array_equal(proposed_pc, orig_pc):
            continue

        # Prev/next constraints using wrapped distances per matching pitch-class
        ok = True
        prev_cost_sum = 0.0
        next_cost_sum = 0.0
        if prev_arr is not None:
            for v in range(len(chord)):
                pm = np.where(prev_pc == orig_pc[v])[0]
                if pm.size:
                    gaps = [cent_distance_mod_1200(proposed[v], prev_arr[j]) for j in pm]
                    gmin = min(gaps)
                    if gmin > max_gap:
                        ok = False
                        break
                    prev_cost_sum += gmin
            logging.debug(f'checking if prev is different from current. {gmin = }')
        if not ok:
            continue

        if next_arr is not None:
            for v in range(len(chord)):
                nm = np.where(next_pc == orig_pc[v])[0]
                if nm.size:
                    gaps = [cent_distance_mod_1200(proposed[v], next_arr[j]) for j in nm]
                    gmin = min(gaps)
                    if gmin > max_gap:
                        ok = False
                        break
                    next_cost_sum += gmin
        if not ok:
            continue
      
    if best is None:
        # best.tolist(), float(best_shift), (int(best_target[0]), float(best_target[1])), True      
        logging.debug(f'best is None. {candidate_shifts, candidate_targets = }')
        return None, None, (None, None), False, gmin

    return best.tolist(), best_shift, (best_target[0], best_target[1]), True, gmin

# handle the case where cent values near 1200 screw up the sorting algorithm, assuming they are far from 0, when in fact they round to 1200, which mod 12 is 0. 
def negate_high_cents(cent_values):
    """
    Convert cent values > 1150 to negative equivalents (e.g., 1168 -> -32).
    
    Helps with sorting algorithms that assume values near 1200 are far from 0,
    when they actually round to the same pitch class as values near 0.
    
    Parameters
    ----------
    cent_values : np.ndarray
        Array of cent values.
    
    Returns
    -------
    np.ndarray
        Array with values > 1150 converted to (value - 1200).
    """
    return np.array([note - 1200 if note > 1150 else cent_values[inx] for inx, note in enumerate(cent_values)])

def format_chord(chord_in_cents, num_spaces):
    """
    Format chord cent values as a space-separated string.
    
    Parameters
    ----------
    chord_in_cents : np.ndarray
        Array of cent values (converted to int if float).
    num_spaces : int
        Field width: 4 for 4-character width, 2 for 2-character width.
    
    Returns
    -------
    str
        Space-separated string of formatted cent values.
    """
    # Format each value in chord_in_cents to 4-character width
    cents_str = 'none'
    if chord_in_cents.dtype == float:
          chord_in_cents = np.round(chord_in_cents,0).astype(int)
    if num_spaces == 4:
          cents_str = ' '.join(f'{val:4d}' for val in chord_in_cents)
    elif num_spaces == 2:
          cents_str = ' '.join(f'{val:2d}' for val in chord_in_cents)
    return cents_str

def perturb(four_note_chord, spread=7):
    """
    Add random perturbations to a 4-note chord's cent values.
    
    Assumes input is tuned to 12-TET (100 cents per semitone). Perturbations are
    clipped to ±49 cents. Compresses to unique values before perturbing to avoid
    different cent values for the same MIDI value.
    
    Parameters
    ----------
    four_note_chord : np.ndarray
        Array of 4 cent values (12-TET tuned).
    spread : int, optional
        Standard deviation for normal distribution (default: 7).
        Most perturbations near zero with spread=6, can reach ±49 with spread=15.
    
    Returns
    -------
    tuple
        (temp_result, inverse)
        - temp_result: np.ndarray, perturbed cent values (mod 1200)
        - inverse: np.ndarray, mapping to restore original order
    """
    # this function assumes the arrival of a 4-note chord that is tuned to the 12 TET cent values, 100 cents per semi-tone. The adjustment is trimmed to no more than +- 49, 
    # most of the perturbations are near zero with scale=6, but can be close to 49 with scale=15
    # It compresses the chord to the unique values before the perturbations, then decompresses it after, so we don't end up with different cebt values for the same midi value.
      # start by compressing the chord to the unique values, but preserving the index and inverse needed to restore it's order and quantity
    compressed_chord, indices, inverse = np.unique(four_note_chord, axis=0, return_index=True, return_inverse=True)
    order = np.argsort(indices)
    compressed_chord = compressed_chord[order]
    
    remap = np.zeros_like(order)
    remap[order] = np.arange(len(order))
    inverse = remap[inverse]
    
    # do the perturbation
    if spread:
        temp_result = np.array([int(round(np.clip(rng.normal(loc=0, scale=spread), a_min = -49, a_max = 49) + note, 0)) for note in compressed_chord]) 
    else:
        temp_result = compressed_chord
    
    # restore the chord to it's original arrangement. For now we will just send this compressed chord through the tune_chord_sim_anneal
    # temp_result = temp_result[inverse] # restore this if you get in trouble later. 
    return np.array(temp_result % 1200), inverse

def compress_pitch_class(four_note_chord):
    """
    Compress a chord to unique pitch classes, preserving order of first occurrence.
    
    Parameters
    ----------
    four_note_chord : np.ndarray
        Array of pitch classes (may have duplicates).
    
    Returns
    -------
    tuple
        (compressed_chord, inverse)
        - compressed_chord: np.ndarray, unique pitch classes in order of first appearance
        - inverse: np.ndarray, mapping to reconstruct original from compressed
    """
    compressed_chord, indices, inverse = np.unique(four_note_chord, axis=0, return_index=True, return_inverse=True)
    order = np.argsort(indices)
    compressed_chord = compressed_chord[order]
    
    remap = np.zeros_like(order)
    remap[order] = np.arange(len(order))
    inverse = remap[inverse]
    return compressed_chord, inverse

# finds all the potential transpositions based on top_notes that can be applied to cent_values_current that won't change the pitch class of the chord
def find_optimum_top_notes(gap_cents_top_notes, cent_value_current, pitch_class_current):
    """
    Find valid transpositions from top_notes that preserve pitch classes.
    
    Tests each gap from top_notes to see if applying it would change any pitch class.
    Returns only gaps that preserve all pitch classes.
    
    Parameters
    ----------
    gap_cents_top_notes : np.ndarray
        Array of cent gaps from top_notes (priority order).
    cent_value_current : np.ndarray
        Current cent values for the chord.
    pitch_class_current : np.ndarray
        Current pitch classes (0-11) for the chord.
    
    Returns
    -------
    np.ndarray
        Array of valid gaps (999 for invalid gaps). Same shape as gap_cents_top_notes.
    """
    cent_value_valid_gaps = np.full((4,), 999) # potential gaps that can be applied to cent_value_current without changing the pitch class
    for inx, top_note_gap in zip(count(0,1), gap_cents_top_notes): # step through the top_notes in order of priority
        # check to see if applying this gap would change the pitch class 
        # Shouldn't we include the direction cent_moves here?
        cent_value_proposed = (cent_value_current + top_note_gap) % 1200 # 10/24/25 changed from - to +
        logging.info(f'In find_optimum_top_notes. transposition by {top_note_gap = }, creates chord: {format_chord(cent_value_proposed,4)}')
        pitch_class_proposed = pitch_class_from_cents(cent_value_proposed) 
        logging.debug(f'{pitch_class_proposed = }, {pitch_class_current = }')
        if np.array_equal(pitch_class_proposed, pitch_class_current):
                logging.info(f'Valid transposition {top_note_gap = }, new cents: {format_chord(cent_value_proposed,4)}, new pitch class: {format_chord(pitch_class_proposed,2)}')
                cent_value_valid_gaps[inx] = top_note_gap
        else:
                logging.debug(f'Failed transposition by {top_note_gap = } trying another')
    
    logging.info(f'Leaving find_optimum_top_notes. Returning only those gaps that keep same pitch class {cent_value_valid_gaps = }')
    return cent_value_valid_gaps


# finds the best top_note gap to apply from the choices. Some variables not needed any more: # pitch_class_prev,
def find_best_gap(cent_value_valid_gaps, cent_value_current, pitch_class_current, \
            chord_num, top_notes, pitch_class_current_in_top_notes):
    """
    Find the best gap to apply from valid gaps, prioritizing top_notes order.
    
    Applies gaps in priority order based on top_notes. The first valid gap
    (that preserves pitch classes) is returned, reinforcing higher-priority notes.
    
    Parameters
    ----------
    cent_value_valid_gaps : np.ndarray
        Array of valid gaps (999 for invalid).
    cent_value_current : np.ndarray
        Current cent values for the chord.
    pitch_class_current : np.ndarray
        Current pitch classes (0-11) for the chord.
    chord_num : int
        Chord number (for logging).
    top_notes : np.ndarray
        Shape (2, 12), prioritized target cent values.
    pitch_class_current_in_top_notes : np.ndarray
        Boolean array indicating which pitch classes are in top_notes.
    
    Returns
    -------
    int
        Best gap value to apply (0 if none found).
    """
    # apply the gaps based on top_notes in priority order. Try each to see if it would cause a gap between cent values of the same pitch class to exceed max_gap. If it does, try the next. The earlier you pick, that means you will reinforce the higher priority notes staying in one place. 
    logging.debug(f'{chord_num = }: {cent_value_valid_gaps = }, {cent_value_current = }, {pitch_class_current = }, ')
    top_note_gap = 0

    cent_value_gaps = cent_value_valid_gaps[cent_value_valid_gaps != 999] # remove the invalid values caused by missing top_notes, changed pitch class.
    logging.debug(f'In find_best_gap. valid gaps to try in priority order: {cent_value_gaps = }')

    gap_map = defaultdict(list)
    for pc, gap in zip(pitch_class_current[pitch_class_current_in_top_notes], cent_value_valid_gaps):
        gap_map[pc].append(gap)
    logging.debug(f'gap_map constructed: {gap_map = }')

    # Now walk through top_notes in order
    ordered_gaps = []
    for pc in top_notes[0]:
        if pc in gap_map:
                ordered_gaps.extend(gap_map[pc])  # keep all gaps for that pitch class
                
    logging.debug(f'{gap_map = }, {ordered_gaps = }')

    for inx, top_note_gap in zip(count(0,1), ordered_gaps): # try the valid gaps in priority order 
        logging.debug(f'looping on top_note_gap. {inx}: {top_note_gap = }')
        if np.array_equal(pitch_class_current, pitch_class_from_cents((cent_value_current + top_note_gap) % 1200)):
                break

    logging.debug(f'leaving find_best_gap. {top_note_gap = }')
    return top_note_gap # the first value is the gap required by top_notes, the second it the deltas between the previous chord and the current chord, not including the top_note_gap, the third is that none of the changes would alter the pitch class. 
      
# routine to log the current contents of top_notes
def log_top_notes(top_notes, function_name=logging.info, heading = 'Current top_notes:'):
    """
    Log the contents of top_notes in a formatted table.
    
    Parameters
    ----------
    top_notes : np.ndarray
        Shape (2, 12). Row 0: MIDI pitch classes, Row 1: cent values.
    function_name : callable, optional
        Logging function to use (default: logging.info).
    heading : str, optional
        Heading text for the log output (default: 'Current top_notes:').
    
    Returns
    -------
    None
        Logs formatted table with indices, note names, pitch classes, and cent values.
    """
    function_name(heading)
    keys = set_accidentals(False) # get the keys with sharps 
    line = ' '.join(f'{inx:>4}' for inx in np.arange(12))
    function_name(line)
    line = ' '.join(f'{note:>4}' for note in keys[top_notes[0]])
    function_name(line)
    line = ' '.join(f'{note:>4}' for note in top_notes[0])
    function_name(line)
    line = ' '.join(f'{note:>4}' for note in top_notes[1])
    function_name(line)      
      
def chord_from_top_notes(cent_values, top_notes, pitch_class_from_cents=pitch_class_from_cents):
    """
    Map a chord's cent values to canonical cent values from top_notes.
    
    Parameters
    ----------
    cent_values : array-like
        The chord in cents (e.g. [200, 902, 400, 902]).
    top_notes : np.ndarray
        2 x N array: first row = pitch classes, second row = canonical cent values.
    pitch_class_from_cents : callable
        Function that maps cent values -> pitch class (0–11).
    
    Returns
    -------
    np.ndarray
        New chord with cent values pulled from top_notes.
    """
    pcs = [pitch_class_from_cents(c) for c in cent_values]
    chord = []
    for pc in pcs:
        # find the index of this pitch class in top_notes
        idx = np.where(top_notes[0] == pc)[0]
        if len(idx) == 0:
            raise ValueError(f"Pitch class {pc} not found in top_notes")
        chord.append(top_notes[1, idx[0]])
    return np.array(chord)

def transpose_chord_by_top_notes(cent_value_current, pitch_class_current, top_notes, chord_num):
    """
    Transpose a chord to align with top_notes priorities.
    
    Sorts chord, finds gaps to top_notes, and applies the best valid transposition
    that preserves pitch classes.
    
    Parameters
    ----------
    cent_value_current : np.ndarray
        Current cent values for the chord.
    pitch_class_current : np.ndarray
        Current pitch classes (0-11) for the chord.
    top_notes : np.ndarray
        Shape (2, 12), prioritized target cent values.
    chord_num : int
        Chord number (for logging).
    
    Returns
    -------
    tuple
        (proposed_cent_value_chord, gap, success)
        - proposed_cent_value_chord: np.ndarray, transposed cent values (or original if failed)
        - gap: int, cent shift applied
        - success: bool, True if transposition preserved pitch classes
    """
    logging.debug(f'In transpose_chord_by_top_notes. {chord_num = }') # pitch_class_current
    if chord_num // 10 == 0: 
        log_top_notes(top_notes, logging.debug)
        
    pitch_class_current = pitch_class_current[np.argsort(pitch_class_current)] # sort chord pitch class by value
    logging.debug(f'{chord_num = }, {cent_value_current = }, {pitch_class_current = }')
    cent_value_current = negate_high_cents(cent_value_current) # convert cent values > 1150 to negative cent_values - 1200
    cent_value_current = cent_value_current[np.argsort(cent_value_current)] # sort chord cent value by value
    logging.debug(f'{pitch_class_current = }, {cent_value_current = }')
    pitch_class_current_in_top_notes = np.array([i in top_notes[0] for i in pitch_class_current])
    logging.debug(f'{pitch_class_current_in_top_notes.shape = }')
    logging.debug(f'{cent_value_current[pitch_class_current_in_top_notes] = }')
    logging.debug(f'{pitch_class_current[pitch_class_current_in_top_notes] * 100 = }') 
    # build a hypothetical chord made from all top_notes. Use this to compare with the current cent chord and notice the differences. 
    top_notes_cent_value_chord = chord_from_top_notes(cent_value_current, top_notes) 
    logging.debug(f'In transpose_chord_v5. built top_notes_cent_value_chord: {format_chord(top_notes_cent_value_chord,4)}')
    gap_cents_top_notes = top_notes_cent_value_chord - cent_value_current[pitch_class_current_in_top_notes]
    logging.debug(f'In transpose_chord_v5. {format_chord(gap_cents_top_notes,4) = }')
    cent_value_valid_gaps = find_optimum_top_notes(gap_cents_top_notes, cent_value_current, pitch_class_current)
    logging.debug(f'In transpose_chord_v5. back from find_optimum_top_notes {cent_value_valid_gaps = }')
    gap = find_best_gap(cent_value_valid_gaps, cent_value_current, pitch_class_current, chord_num, top_notes, pitch_class_current_in_top_notes)
    logging.debug(f'In transpose_chord_v5. back from find_best_gap {gap = }')
    proposed_cent_value_chord = (cent_value_current + gap) % 1200
    success = np.array_equal(pitch_class_current, pitch_class_from_cents(proposed_cent_value_chord))
    if success:
        return (cent_value_current + gap) % 1200, gap, success
    else:
        return (cent_value_current, gap, success)

# This function clips all the notes in the notes_features_15 array to the min and max octaves and volumes for the voice
def clip_note_features(notes_features_15, voice_time):
    """
    Clip note features (octave, volume) to voice-specific limits.
    
    Adjusts octaves to min/max ranges and applies volume_factor offsets.
    Also handles edge case: if at max octave and cent value > 350, reduce octave by 1.
    
    Parameters
    ----------
    notes_features_15 : np.ndarray
        Shape (N, 15) array of note features. Columns:
        [6]=voice, [4]=note_cents, [5]=octave, [14]=volume
    voice_time : dict
        Dictionary mapping voice short names to configuration including
        min_oct, max_oct, and volume_factor.
    
    Returns
    -------
    np.ndarray
        Modified notes_features_15 array with clipped octaves and adjusted volumes.
    """ 
    for inx in np.arange(notes_features_15.shape[0]): # once for every note with all its features.
        short_name, _ = dmu.show_voice_time_short_name(notes_features_15[inx,[6]], voice_time) # returns short_name only from the voice_time array 'fing1'
        logging.debug(f'{inx = }, {short_name = }\n{[round(feature,0) for feature in notes_features_15[inx,[6,4,5,14]]]}') # [[6, 4, 5, 14]] voice, note, octave, volume  array([[ 0., 86.,  5.,  7.],
        logging.debug(f'{voice_time[short_name]["min_oct"] = }, {voice_time[short_name]["max_oct"] = }, {voice_time[short_name]["volume_factor"] = }') # clipping octave volume information
        note_cents = notes_features_15[inx,4] # at some point I'll clip the octave if it's at the max and the note_cents is greater than 300 cents.
        logging.debug(f'before adjusting the volume by {voice_time[short_name]["volume_factor"] = }, {round(notes_features_15[inx,14],1) = }]')
        if notes_features_15[inx,14] > 0: notes_features_15[inx,14] += voice_time[short_name]["volume_factor"]
        logging.debug(f'after adjusting the volume {round(notes_features_15[inx,14],1) = }, before adjusting octave: {notes_features_15[inx,5] = }]')
        
        notes_features_15[inx,5] = np.max((voice_time[short_name]["min_oct"], notes_features_15[inx,5]))
        notes_features_15[inx,5] = np.min((voice_time[short_name]["max_oct"], notes_features_15[inx,5]))
        logging.debug(f'after adjusting octave: {notes_features_15[inx,5] = }, cent value of note: {notes_features_15[inx,4] = }]')
        if notes_features_15[inx,5] == voice_time[short_name]["max_oct"] and note_cents > 350:
                notes_features_15[inx,5] -= 1 # take it down an octave it's at the max and has a high cent value
        logging.debug(f'{inx = }, {[round(feature,0) for feature in notes_features_15[inx,[6,4,5,14]]]}') #   
    logging.debug(f'in clip_note_features. {np.sum(notes_features_15[5]) = }')
    return notes_features_15

# This function will inspect MIDI chords and replace any 0's with another note that is not zero. 
# This is to prevent polution of the scores for a chord that includes 0, since 0 mean\ns it's silent, not the note C.
# zeros in midi numbers mean the note is silent. 
def remove_zeros_from_midi(initial_chord):
    """
    Replace zero MIDI values (silence) with non-zero notes from the chord.
    
    Prevents scoring issues where 0 indicates silence, not the note C.
    If all zeros, returns array of zeros. Otherwise replaces zeros with
    the first non-zero note (cyclically).
    
    Parameters
    ----------
    initial_chord : np.ndarray
        Array of 4 MIDI note numbers (0 indicates silence).
    
    Returns
    -------
    np.ndarray
        Array with zeros replaced by non-zero notes, or all zeros if input was all zeros.
    """
    saved_values = np.array(np.nonzero(initial_chord)) # save the index to the initial_chord of those values that are not zero
    zeros = 0
    # logging.info(f'{saved_values.shape = }')
    if saved_values.shape == (1,0): # if they are all zeros, return an array of zeros
        return np.zeros(4, dtype = int)
    if saved_values.shape[1] < 4: # not all are zeros, but some are. Replace the zeros with the first non-zero value in the chord
        for inx, note in zip(count(0,1), initial_chord):
                if note == 0:
                    logging.debug(f'in remove_zeros_from_midi. {initial_chord = }, {initial_chord % 12} {zeros = }, {note = }, {saved_values = }')
                    initial_chord[inx] = initial_chord[saved_values[0, zeros % saved_values.shape[1]]]
                    zeros +=1
    return initial_chord

#
# 8/17/24 This function takes a chorale of midi notes and returns a chorale with cent values and octaves
# it currently uses the try_permutation function to check all the possible arrangements of the notes in the chord.
def midi_to_notes_octaves_trimmed(chorale, top_notes, tonal_diamond, ratio_factor = 1, dist_factor = 1, \
            flats = True, range = 6, use_perm_or_roll = True, improvement_attempts = 6, cooling_rate = 0.98, bypass_permutations = False):
    """
    Convert MIDI chorale to cent values and octaves using just intonation tuning.
    
    Processes each chord, finds optimal tuning using permutations and simulated annealing,
    then transposes to align with top_notes priorities. Handles repeated chords by
    reusing previous tuning.
    
    Parameters
    ----------
    chorale : np.ndarray
        Shape (voices, time_steps), MIDI note numbers.
    top_notes : np.ndarray
        Shape (2, 12), prioritized target cent values.
    tonal_diamond : np.ndarray
        Shape (N, 3), tonal diamond [ratio, cents, limit_score].
    ratio_factor : float, optional
        Weighting factor for ratio scores (default: 1).
    dist_factor : float, optional
        Weighting factor for distance scores (default: 1).
    flats : bool, optional
        Use flats in note names if True, sharps if False (default: True).
    range : int, optional
        Search range for annealing (default: 6).
    use_perm_or_roll : bool, optional
        If True, use permutation search; if False, use top_notes directly (default: True).
    improvement_attempts : int, optional
        Number of improvement attempts in annealing (default: 6).
    cooling_rate : float, optional
        Cooling rate for simulated annealing (default: 0.98).
    bypass_permutations : bool, optional
        If True, skip permutation search (default: False).
    
    Returns
    -------
    tuple
        (chorale_in_cents_octaves, scores)
        - chorale_in_cents_octaves: np.ndarray, shape (voices, chords, 2),
          [cent_values, octaves] for each note
        - scores: np.ndarray, chord scores for each unique chord
    """ 
    logging.debug(f'In midi_to_notes_octaves_trimmed. {chorale.shape = }') # In midi_to_notes_octaves. chorale.shape = (4, 256)
    # this function is passed a numpy array of note numbers in midi format, four per time step SATB. input is of the form: voice, midi_note
    # it converts the midi numbers into two features: cents and octaves
    # It returns a numpy array of (voices, notes, features), but only two features (cents and octaves)
    keys = set_accidentals(flats)
    # assigning the octaves is pretty trivial. Except when the cents are 1150 or more. 
    octave = np.array([midi_number // 12 for midi_number in chorale]) # a few of these will need to be reduced if the cents come out just under 1200
    logging.debug(f'octave values & counts by voice:')
    logging.debug([np.unique(voice, return_counts=True) for voice in octave])
    logging.debug(f'{chorale.T.shape = }')

    scores = np.zeros(chorale.shape[1])
    score_inx = 0
    total_score = 0
    chorale_in_cents = np.zeros((chorale.T.shape), dtype = int) # this will be filled with the final tuned and transposed chords
    prev_chord = np.zeros(4, dtype = int)
    max_iterations = 0
    for inx, chord in zip(count(0,1), chorale.T):
        chord = remove_zeros_from_midi(chord) # a midi value of zero indicates that the voice is silent. 
        # Replace the zero with another note in the chord. I don't think I have that problem any more. But who knows for certain any more.
        if np.array_equal(chord, prev_chord):
                logging.debug(f'same midi values in this chord as the previous. Assign the previous retuning to this chord. {chord = },  {prev_chord = }\n')
                chorale_in_cents[inx] = chorale_in_cents[inx - 1]
                # this may need to be removed if I get the multiple scores logic implemented.
        else:
                prev_chord = np.copy(chord) # make a new array that is a copy. Original not affected by changes to the copy unless the original is a python object. 
                # provide an initial tuning using the top_notes values for each note in the chord. 
                logging.debug(f'{chord = }, {top_notes.shape = }, {inx = }')
                chord_in_1200 = np.array([top_notes[1][np.where(top_notes[0] == chord[inx] % 12)] for inx in np.arange(chord.shape[0])]).reshape([4]) # added 10/29/24 to start at a better initial value than 12 TET
                # logging.debug(f'After assigning initial value to {chord % 12 = }, result is; {chord_in_1200 = }')
                final_cost = score_chord_cents(chord_in_1200, tonal_diamond)
                logging.debug(f'score using initial values from top_notes: {final_cost = }')
                if use_perm_or_roll: 
                    logging.debug(f'calling try_permutations. chord_num: {inx}, {chord = }, {chord % 12 = }, {ratio_factor = }, {range = }, {use_perm_or_roll = }, {improvement_attempts = }, {cooling_rate = } ') 
                    
                    chord_in_cents, final_cost, iterations = try_permutations(chord, chord_in_1200, tonal_diamond, ratio_factor = ratio_factor, dist_factor = dist_factor, range = range, improvement_attempts = improvement_attempts, cooling_rate = cooling_rate, bypass_permutations = bypass_permutations)
                    
                    max_iterations = np.max([max_iterations, iterations])
                    logging.debug(f'before transposition. {chord_in_cents = }')
                    trans_chord_in_cents, gap = transpose_top_notes(chord_in_cents, top_notes, inx, chord)
                    logging.debug(f'{trans_chord_in_cents = }, transposed by {gap = }')                        
                    chorale_in_cents[inx] = trans_chord_in_cents
                    logging.debug(f'after transposing and rearranging: chord_num: {inx}, {chorale_in_cents[inx] = }, {[keys[int(round(note / 100, 0) % 12)] for note in chorale_in_cents[inx]]}, score: {final_cost}')
                else:
                    trans_chord_in_cents = chord_in_1200 # this is the tuning using the top_notes unchanged, a tempered 12 note scale. 
                    chorale_in_cents[inx] = trans_chord_in_cents 
                    iterations = 0
                    max_iterations = np.max([max_iterations, iterations])

                total_score += final_cost 
                scores[score_inx] = final_cost
                score_inx += 1
                
        # if any note has cents above 1150, then you need to reduce the octave by one.
        for voice_num, note in zip(count(0,1), trans_chord_in_cents):
                if note > 1150: 
                    logging.debug(f'{octave[voice_num, inx] = }')
                    octave[voice_num, inx] -= 1
                    logging.debug(f'found {note = } greater than 1150, reduce octave for {voice_num = }, chord {inx} octave[{voice_num}, {inx}]')
                    logging.debug(f'{octave[voice_num, inx] = }')
    scores = scores[:score_inx] # clip it to just the chords with valid scores
    logging.info(f'# of scores: {score_inx}, total_score: {total_score}, max_iter: {max_iterations}, average score: {round(total_score / score_inx,1)}')
    # for inx, chord in zip(count(0,1),chord_in_cents):
    #       if inx % 4 == 0:
    #             logging.info(f'# of scores: {chord}')
    logging.info(f'# of scores: {chorale_in_cents.shape = }, {[chord for chord in chorale_in_cents[::4,:]] = }')
    logging.debug(f'{chorale_in_cents.shape = }, {octave.shape = }') 

    return np.stack((chorale_in_cents.T, octave), axis = 2), scores 

 
def build_octave_alteration_mask(repeats, voices, chorale, octave_stretch = 4, octave_reduce = 2, stay = 7):
    """
    Build a mask for octave alterations with random variations.
    
    Creates octave change values using normal distributions, then repeats them
    for specified durations. Each voice gets a rolled version of the mask.
    
    Parameters
    ----------
    repeats : int
        Base repeat count for each octave change.
    voices : int
        Number of voices (mask is rolled for each voice).
    chorale : np.ndarray
        Chorale array (used to determine length).
    octave_stretch : int, optional
        Number of possible octave change values (default: 4).
    octave_reduce : int, optional
        Offset to center changes around zero (default: 2).
    stay : int, optional
        Number of possible repeat durations (default: 7).
    
    Returns
    -------
    np.ndarray
        Shape (voices, chorale_length), octave alteration values.
        Each voice has a rolled version of the same pattern.
    """
      
    octave_alteration_mask = np.empty(0, dtype = int)
    done = False
    mu = 6 # mean of the initial distribution - pick a higher number so you don't end up with negative probabilities
    sd = 2 # standard deviation

    while not done: # build up copies that extend to the end of the chorale, then trim to fit.
        p1 = rng.normal(mu, sd, octave_stretch)
        p1 = np.where(p1 >= 0, p1, np.zeros_like(p1)) # replace negative number with zero
        p1 = p1 / np.sum(p1)
        p2 = rng.normal(mu, sd, stay)
        p2 = np.where(p2 >= 0, p2, np.zeros_like(p2)) 
        p2 = p2 / np.sum(p2)
        # returns a single number 0,1,2,3,4,5 - 2 = -2,-1,0,1,2,3 rarely hitting the largest and smallest values
        some_octave_change = rng.choice(octave_stretch, p = p1) - octave_reduce
        some_repeat_value = (1 + rng.choice(stay, p = p2)) * repeats
        repeated_octave_change = np.repeat(some_octave_change, some_repeat_value, axis = 0)
        octave_alteration_mask = np.concatenate((octave_alteration_mask, repeated_octave_change), axis = 0) 
        done = octave_alteration_mask.shape[0] > chorale.shape[1] 
    octave_alteration_mask = octave_alteration_mask[:chorale.shape[1]] # cut off the excess array elements
    final_result = np.array([np.roll(octave_alteration_mask, iteration * repeats, axis = 0) for iteration in np.arange(voices)])
    logging.debug(f'End of build_octave_alteration_mask. {final_result.shape = }')
    return final_result

# the following is designed to build a mask that sets long strings of zeros and ones.
# the result is an octave mask that has long held notes followed by long rests, at least as long as the repeats value
# This is used in the woodwind_part to create the long held notes. It does not spread the octaves out
def build_long_mask(repeats, voices, chorale, p1 = [.5, .5], stay = 7, p2 =  [.1, .1, .2, .2, .2, .1, .1]):
    """
    Build a binary mask with long strings of 0s and 1s.
    
    Creates patterns of long held notes (1) followed by long rests (0),
    used for woodwind parts. Each voice gets a rolled version.
    
    Parameters
    ----------
    repeats : int
        Base repeat count for each pattern segment.
    voices : int
        Number of voices.
    chorale : np.ndarray
        Chorale array (used to determine length).
    p1 : list, optional
        Probabilities for [0, 1] choices (default: [.5, .5]).
    stay : int, optional
        Number of possible repeat durations (default: 7).
    p2 : list, optional
        Probabilities for repeat duration choices (default: [.1, .1, .2, .2, .2, .1, .1]).
    
    Returns
    -------
    np.ndarray
        Shape (voices, chorale_length), binary mask (0 or 1).
    """
    octave_alteration_mask = np.empty(0, dtype = int)
    done = False
    while not done:
        some_octave_change = rng.choice(2, p = p1)  # returns a zero or one, mostly zero
        #                                   
        some_repeat_value = (1 + rng.choice(stay, p = p2)) * repeats # pick a number 1-6 times the repeat value
        repeated_octave_mask = np.repeat(some_octave_change, some_repeat_value, axis = 0)
        octave_alteration_mask = np.concatenate((octave_alteration_mask, repeated_octave_mask), axis = 0) # build up the mask unti it is larger than needed
        done = octave_alteration_mask.shape[0] > chorale.shape[1] 
    octave_alteration_mask = octave_alteration_mask[:chorale.shape[1]] # cut off the excess array elements
    octave_alteration_mask = np.array([np.roll(octave_alteration_mask, iteration * repeats, axis = 0) for iteration in np.arange(voices)])
    return octave_alteration_mask

def build_long_mask_v2(repeats, voices, chorale, p1 = [.5, .5], stay = 7, p2 =  [.1, .1, .2, .2, .2, .1, .1], variability=.5):
    """
    Build a binary mask with variable probabilities over time.
    
    Similar to build_long_mask but adds variability to p1 probabilities,
    creating more varied patterns across the chorale length.
    
    Parameters
    ----------
    repeats : int
        Base repeat count for each pattern segment.
    voices : int
        Number of voices.
    chorale : np.ndarray
        Chorale array (used to determine length).
    p1 : list, optional
        Base probabilities for [0, 1] choices (default: [.5, .5]).
    stay : int, optional
        Number of possible repeat durations (default: 7).
    p2 : list, optional
        Probabilities for repeat duration choices (default: [.1, .1, .2, .2, .2, .1, .1]).
    variability : float, optional
        Amount of variation added to p1[0] (default: 0.5).
    
    Returns
    -------
    np.ndarray
        Shape (voices, chorale_length), binary mask (0 or 1).
    """
    octave_alteration_mask = np.empty(0, dtype = int)
    done = False
    sigma = p1[1] # p1 is close to [0.9, 0.1]. This adds variety to the probabilities for each section
    while not done:
        p1_val = p1[0] + sigma * (np.random.rand() - 0.5) * 2  # generate a new p1 value close to the original one. It adds a random value, positive or negative to the p1[0] value
        if p1_val < 0: p1_val = -p1_val # can't handle negative probabilities
        p1_new = np.array([p1_val, 1 - p1_val])
        some_octave_change = rng.choice(2, p = p1_new)  # returns a zero or one, mostly zero. probability varies over the length of the piece
        some_repeat_value = (1 + rng.choice(stay, p = p2)) * repeats # pick a number 1-6 times the repeat value
        repeated_octave_mask = np.repeat(some_octave_change, some_repeat_value, axis = 0)
        octave_alteration_mask = np.concatenate((octave_alteration_mask, repeated_octave_mask), axis = 0)
        done = octave_alteration_mask.shape[0] > chorale.shape[1] 
    octave_alteration_mask = octave_alteration_mask[:chorale.shape[1]] # cut off the excess array elements
    octave_alteration_mask = np.array([np.roll(octave_alteration_mask, iteration * repeats, axis = 0) for iteration in np.arange(voices)])
    return octave_alteration_mask



# This functions fills out the gliss, upsamples, envelopes, and velocities for each note in as interesting a way as possible. It's no longer used, after modifying it to include glides 9/23
def add_features(voices_notes_features, guev_array):
    """
    Add glissando, upsample, envelope, and velocity features to notes.
    
    NOTE: This function is deprecated, replaced by add_features_glides.
    Assigns features based on note changes and break points, varying
    features over time.
    
    Parameters
    ----------
    voices_notes_features : np.ndarray
        Shape (voices, notes, 2), [note, octave] features.
    guev_array : np.ndarray
        Array containing gliss, upsample, envelope, velocity arrays and probabilities.
    
    Returns
    -------
    np.ndarray
        Shape (6, voices, notes), stacked features:
        [notes, octaves, gliss, upsample, envelope, velocity]
    """
    gls, gls_p, ups, ups_p, env, env_p, vel, vel_p = np.moveaxis(guev_array, 0, 0)
    # logging.debug(f'gls, gls_p, ups, ups_p, env, env_p, vel, vel_p: {[value for value in (gls, gls_p, ups, ups_p, env, env_p, vel, vel_p)]}')
    # voices_notes_features shape = (4, 256, 2) (voices, notes, features (note, octave))
    break_point = voices_notes_features.shape[1] // env.shape[0] # # of notes divided by the shape of env
    notes = voices_notes_features[:,:,0] # the 0th feature is the note # (4, 256)
    octaves = voices_notes_features[:,:,1] # the 1th feature is the octave # (4, 256)
    # set the features for each note in the chorale, all voices
    gliss = np.zeros(notes.shape, dtype = int)
    upsample = np.zeros(notes.shape, dtype = int)   
    envelope = np.zeros(notes.shape, dtype = int)
    velocity = np.zeros(notes.shape, dtype = int)  
    
    # move from one set of features to the next. gls, ups, env, vel
    for voice in np.arange(notes.shape[0]):
        # for every note in the voice
        # logging.debug(f'first note in voice: {voice = } {notes[voice, 0] = }')
        gls_i = 0
        ups_i = 0
        env_i = 0
        vel_i = 0   
        prev_note = notes[voice, 0]
        prev_gls = rng.choice(gls[gls_i], p = gls_p[gls_i])
        prev_ups = rng.choice(ups[ups_i], p = ups_p[ups_i])
        prev_env = rng.choice(env[env_i], p = env_p[env_i])
        prev_vel = rng.choice(vel[vel_i], p = vel_p[vel_i])
        for note in np.arange(notes.shape[1]):
                if notes[voice, note] != prev_note:
                    # logging.debug(f'new note: {voice = }, {note = }, {notes[voice, note] = }, {gls_i = }')
                    gliss[voice, note] = rng.choice(gls[gls_i], p = gls_p[gls_i])
                    upsample[voice, note] = rng.choice(ups[ups_i], p = ups_p[ups_i])
                    envelope[voice, note] = rng.choice(env[env_i], p = env_p[env_i])
                    velocity[voice, note] = rng.choice(vel[vel_i], p = vel_p[vel_i])
                    prev_note = notes[voice, note]
                    prev_gls = gliss[voice, note]
                    prev_ups = upsample[voice, note]
                    prev_env = envelope[voice, note]
                    prev_vel = velocity[voice, note]
                else:
                    # logging.debug(f'{notes[voice, note] = }')
                    gliss[voice, note] = prev_gls
                    upsample[voice, note] = prev_ups
                    envelope[voice, note] = prev_env
                    velocity[voice, note] = prev_vel

                if note % break_point == 0 and note > 0:
                    # logging.debug(f'{note = }, {note % break_point = }, {env_i = } {env[env_i]}')
                    gls_i = np.min((gls.shape[0] - 1, gls_i + 1))
                    ups_i = np.min((ups.shape[0] - 1, ups_i + 1))
                    env_i = np.min((env.shape[0] - 1, env_i + 1))
                    vel_i = np.min((vel.shape[0] - 1, vel_i + 1))
                    # logging.debug(f'increased indices: {env_i = } {env[env_i]}')
    return np.stack((notes, octaves, gliss, upsample, envelope, velocity), axis = 0) 

# added 9/1/23 to include the glides for the woodwinds_part.
def add_features_glides(notes_octaves, glides, guev_array):
    """
    Add upsample, envelope, and velocity features to notes with glides.
    
    Similar to add_features but uses pre-computed glides array instead of
    generating glissando. Features change at note boundaries and break points.
    
    Parameters
    ----------
    notes_octaves : np.ndarray
        Shape (voices, notes, 2), [note, octave] features.
    glides : np.ndarray
        Shape (voices, notes), glide function table numbers (0 if no glide).
    guev_array : np.ndarray
        Array containing upsample, envelope, velocity arrays and probabilities.
    
    Returns
    -------
    np.ndarray
        Shape (6, voices, notes), stacked features:
        [notes, octaves, glides, upsample, envelope, velocity]
    """
    gls, gls_p, ups, ups_p, env, env_p, vel, vel_p = np.moveaxis(guev_array, 0, 0)
    logging.debug(f'in add_features_glides. {notes_octaves.shape = }, {glides.shape = }, {guev_array.shape = }')
    # notes_octaves shape = (voices, notes, features (note, octave))
    break_point = notes_octaves.shape[1] // env.shape[0] # # of notes divided by the shape of env
    # split the octaves and notes into different array.
    notes = notes_octaves[:,:,0] # the 0th feature is the note # (4, 256)
    octaves = notes_octaves[:,:,1] # the 1th feature is the octave # (4, 256)
    # logging.info(f'consider simplifying this tuple unpacking here.')
    # notes_x, octaves_x = notes_octaves[:,:]
    # logging.info(f'{notes.shape = }, {octaves.shape = }, {notes_x.shape = }, {octaves_x.shape = }')
    # set the features for each note in the chorale, all voices
    upsample = np.zeros(notes.shape, dtype = int)   
    envelope = np.zeros(notes.shape, dtype = int)
    velocity = np.zeros(notes.shape, dtype = int)  
    
    # move a set of features to the notes based on break points: ups, env, vel
    for voice in np.arange(notes.shape[0]):
        # for every voice in the array
        # logging.debug(f'first note in voice: {voice = } {notes[voice, 0] = }')
        ups_i = 0
        env_i = 0
        vel_i = 0   
        prev_note = notes[voice, 0]
        prev_ups = rng.choice(ups[ups_i], p = ups_p[ups_i])
        prev_env = rng.choice(env[env_i], p = env_p[env_i])
        prev_vel = rng.choice(vel[vel_i], p = vel_p[vel_i])
        for note in np.arange(notes.shape[1]):
                # for every note in the voice
                if notes[voice, note] != prev_note:
                    upsample[voice, note] = rng.choice(ups[ups_i], p = ups_p[ups_i])
                    envelope[voice, note] = rng.choice(env[env_i], p = env_p[env_i])
                    velocity[voice, note] = rng.choice(vel[vel_i], p = vel_p[vel_i])
                    prev_note = notes[voice, note]
                    prev_ups = upsample[voice, note]
                    prev_env = envelope[voice, note]
                    prev_vel = velocity[voice, note]
                else:
                    upsample[voice, note] = prev_ups
                    envelope[voice, note] = prev_env
                    velocity[voice, note] = prev_vel

                if note % break_point == 0 and note > 0:
                    ups_i = np.min((ups.shape[0] - 1, ups_i + 1))
                    env_i = np.min((env.shape[0] - 1, env_i + 1))
                    vel_i = np.min((vel.shape[0] - 1, vel_i + 1))
    return np.stack((notes, octaves, glides, upsample, envelope, velocity), axis = 0) 

def build_glides_report(chorale_in_cents_slides, glides,  stored_gliss): # chorale_in_cents_slides.shape = (4, 258, 2), glides.shape = (4, 258), stored_gliss.shape = (5, 9)
    """
    Generate a detailed report of all glides/slides in the chorale.
    
    Logs glide function tables, chord positions, cent values, ratios, and statistics.
    
    Parameters
    ----------
    chorale_in_cents_slides : np.ndarray
        Shape (voices, chords, 2), [cent_values, octaves].
    glides : np.ndarray
        Shape (voices, chords), glide function table numbers (0 if no glide).
    stored_gliss : np.ndarray
        Shape (N, 9), stored glide function table definitions.
    
    Returns
    -------
    None
        Logs detailed report including:
        - List of all glide function tables with ratios and cent values
        - For each glide: chord#, voice#, start cents, glide#, ratio, slide cents, end cents
        - Statistics: total slides, min/max glide sizes
    """
    logging.debug(f'glides report') 
    logging.debug(f'{chorale_in_cents_slides.shape = }, {glides.shape = }, {stored_gliss.shape = }')
    max_glide = 0
    min_glide = 0
    logging.debug(f'List of the slides generated')
    logging.debug(f'glide#\tdecimal\tcents\tratio')
    for gl in stored_gliss:
        # glide num is 1500 and up, glide value is the ratio of the glide
        logging.debug(f'{int(gl[0])}\t{round(gl[8],4)}\t{int(dmu.ratio_to_cents(gl[8]))}\t{stringify(gl[8])}')
    logging.debug(f' # \tinst\tstart\tgls    \tdec  \tslide\tend\tslide')
    logging.debug(f'chrd\tvoice\tcents\t #\tratio\tcents\tcents\tratio')
    total_slides = 0
    for inx, glide_chord in zip(count(0,1), glides.T):
        if glide_chord.any():
                for inx2, glide in zip(count(0,1),glide_chord):
                    if glide != 0: 
                            gliss_index = np.where(stored_gliss == glide)[0]
                            # logging.info(f'{gliss_index = }, {glide = }')
                            gliss_ratio = stored_gliss[gliss_index, 8][0]
                            # logging.info(f'{gliss_factor = }')
                            gliss_cents = int(dmu.ratio_to_cents(gliss_ratio))
                            logging.info(f'{inx}\t{inx2}\t{chorale_in_cents_slides[inx2,inx,0]}\t{glide}\t{round(gliss_ratio,4)}\t{gliss_cents}\t{gliss_cents + chorale_in_cents_slides[inx2,inx,0]}\t{stringify(gliss_ratio)}')
                            max_glide = np.max([max_glide, gliss_cents])
                            min_glide = np.min([min_glide, gliss_cents])
                            total_slides += 1
    logging.info(f'{total_slides = }, {max_glide = }, {min_glide = }') 

# This function converts a corpus into a numpy array of start, midi, duration, then into a chorale of 4-part notes
# this replaces the previous version that required a conversion to the mido library. This one only uses music21
def stream_to_midi_array(corpus, save_midi_file = False):
    """
    Convert a music21 corpus work to a NumPy array of MIDI information.
    
    Extracts notes, timing, and key information, then converts to a 4-voice
    chorale format by distributing notes across voices based on arrival time.
    
    Parameters
    ----------
    corpus : str
        Corpus work identifier (e.g., 'bwv244.3').
    save_midi_file : bool, optional
        If True, save MIDI file to disk (default: False).
    
    Returns
    -------
    tuple
        (trimmed_chorale, root, mode, time_sig, stream)
        - trimmed_chorale: np.ndarray, shape (voices, time_steps), MIDI notes
        - root: int, pitch class (0-11) of the root note
        - mode: str, 'major' or 'minor'
        - time_sig: str, time signature (e.g., '4/4')
        - stream: music21.stream.Stream object
    """
    stream = m21.corpus.parse(corpus) # Create the strem from the corpus
    key = stream.analyze('key')
    root = key.tonic.midi % 12
    mode = key.mode
    my_part = stream.parts[0]
    ts_str = str(my_part[m21.meter.TimeSignature][0])
    time_sig = ts_str[ts_str.find(' '):-1]
    time_sig = time_sig[1:]

    logging.debug(f'{time_sig =}')
    notes = stream.flatten().notes # Extract the notes from the Stream
    midi_notes = []  # Create an empty list to store the MIDI note numbers
    for n in notes: # Loop through each note in the Stream
        midi_note = n.pitch.midi # Get the MIDI note number
        start_time = n.offset * 4 # get the note starting time
        duration = n.quarterLength * 4 # Get the duration (in quarter notes) of the note
        note_tuple = (start_time, midi_note, duration) # Create a tuple of the MIDI number, start time, duration
        midi_notes.append(note_tuple) # Add the current note information list    
    midi_array = np.array(midi_notes).astype(int) # Convert the list of MIDI notes to a NumPy array

    # now convert this midi_array of 3 features into a four part chorale with chords for each time step.
    prev_start = -1
    current_voice = 0
    chr_inx = np.zeros([4],dtype = int)
    trimmed_chorale = np.zeros([4,512],dtype = int) # we will trim this to the right shape at the end of the function
    for note_num, note in zip(count(0,1),midi_array): # for every row of note information in the array
        start, midi, dur = note # assign them to local variables
        current_voice = np.argmin(chr_inx) # put the next arriving note in the voice that has the fewest notes.
        if start > prev_start: # you have a note you need to save in a new row on trimmed_chorale
                trimmed_chorale[current_voice,chr_inx[current_voice]:chr_inx[current_voice] + dur] = midi 
                prev_start = start
                chr_inx[current_voice] += dur
        elif start == prev_start:
                trimmed_chorale[current_voice,chr_inx[current_voice]:chr_inx[current_voice] + dur] = midi 
                chr_inx[current_voice] += dur
        if current_voice > 3: current_voice = 0
    logging.info(f'{save_midi_file = }, ')
    if save_midi_file: 
        result = stream.write('midi', fp = corpus + '.mid')
        logging.info(f'Wrote out a midi file named {result = }')
    # s.write('midi', fp='fileout.mid')
    return trimmed_chorale[:,:np.max(chr_inx)], root, mode, time_sig, stream

# this is obsolete and should be removed. 
def print_interval_cent_report(chorale_in_cents, chorale, top_notes, tonal_diamond, keys,\
      ratio_factor, limit_denominator = 42, print_intervals = True, end_chord = 999, tolerance=1):
    """
    Print a detailed report of chord intervals and scores.
    
    NOTE: This function is obsolete and should be removed.
    Prints chord information including note names, cent values, intervals,
    ratios, and chord scores.
    
    Parameters
    ----------
    chorale_in_cents : np.ndarray
        Shape (voices, chords, 2), [cent_values, octaves].
    chorale : np.ndarray
        Shape (voices, chords), original MIDI notes.
    top_notes : np.ndarray
        Shape (2, 12), prioritized target cent values.
    tonal_diamond : np.ndarray
        Shape (N, 3), tonal diamond [ratio, cents, limit_score].
    keys : np.ndarray
        Array of 12 note names.
    ratio_factor : float
        Weighting factor for ratio scores.
    limit_denominator : int, optional
        Maximum denominator for ratio formatting (default: 42).
    print_intervals : bool, optional
        If True, print interval details (default: True).
    end_chord : int, optional
        Last chord to process (default: 999).
    tolerance : int, optional
        Tolerance for interval matching (default: 1).
    
    Returns
    -------
    tuple
        (max_score_reported, sum_scores, count_scores, len(value), current_score, counts, value)
        Various statistics about the chorale.
    """
    chord_scorer = ChordScorer(tonal_diamond) 
    max_score_reported = 0
    max_score_chord_num = 0
    sum_scores = 0
    count_scores = 0
    current_score = np.zeros(chorale_in_cents.shape[1], dtype = int)
    print(f'report the chords used, with chord scores')
    if print_intervals: print(f'#\t\tnames of the notes\tcents of notes\t\tintervals between notes, the cents and ratios of the intervals\t\tchord score')
    else: print(f'#\tnames of the notes\tcents of notes\t\toctaves\t\tchord score')
    previous_chord = np.zeros((4,), dtype = int)
    previous_chord_12 = np.zeros((4,), dtype = int)  
#       +-- current chord number 
#       |          +-- cents of current chord
#       |          |           +-- octave of current chord
#       |          |           |       +-- original midi value
    for chord_num, chord_1200, octave, midi_12 in \
        zip(count(0,1), chorale_in_cents[:,:end_chord,0].T, chorale_in_cents[:,:end_chord,1].T, chorale.T):
        # convert the cent value back into the original MIDI scale degree 0-12
        chord_12 = np.array([note % 12 for note in midi_12])
        if not np.array_equal(chord_12, previous_chord_12):
                current_score[chord_num] = chord_scorer.score_chord(chord_1200, tolerance) 
                if current_score[chord_num] > max_score_reported:
                    max_score_reported = current_score[chord_num]
                    max_score_chord_num = chord_num
                sum_scores += current_score[chord_num]
                count_scores += 1
                print(chord_num, end = '\t') # chord_12_rounded % 12, 
                print([keys[int(round(note, 0) % 12)] for note in chord_12], end = '\t') # print the note midi 
                # print the cent values in the array right aligned. 
                print(np.array2string(chord_1200, formatter={'int': lambda x: '%+4s' % x}),end='\t')
                # print each of the six intervals in a 4-note chord. Group consists of relative note #1, note #2, delta cents, delta ratio for each of the six intervals.
                if print_intervals:
                    print([(inx1, inx2, \
                    np.array2string(abs(chord_1200[inx1] - chord_1200[inx2]), formatter={'int': lambda x: '%+4s' % x}), \
                            dmu.cents_to_ratio(abs(chord_1200[inx1] - chord_1200[inx2]),limit_denominator = limit_denominator).center(5)) \
                            for inx1, inx2 in combinations(np.arange(4),2)], end = '\t\t')
                # show with the score of the chord
                print(f'{octave}',end='\t')
                print(f'{current_score[chord_num]}')   
        
        previous_chord_12 = np.copy(chord_12) # save the 12TET midi value 0-12

    if count_scores > 0: 
        print(f'{ratio_factor = }')
        print(f'Max score: {max_score_reported}, at chord # {max_score_chord_num}')  
        # Total score: 3390, Average score: 53.0, count_scores = 64 
    print(f'{tonal_diamond.shape = }')
    logging.debug(f'Maximum score was: {max_score_reported}, @ chord # {max_score_chord_num}')  
    logging.debug(f'Total score was {sum_scores}, {count_scores = }') 
    if count_scores > 0: logging.debug(f'Average score was: {round(sum_scores / count_scores,1)}')
    print('top notes:')
    print(*[note for note in top_notes[0]], sep = '\t')
    print(*[keys[note] for note in top_notes[0]], sep = '\t')
    print(*[cent_value for cent_value in top_notes[1]], sep = '\t')
    value, counts = np.unique(chorale_in_cents[:,:,0].T, return_counts = True)
    print(f'Most common cent values, midi note, counts of this particular cent value, with the most common at the top:')
    count_and_values = np.array([(v, int(round(v / 100,0)), c) for v,c in zip(value[np.argsort(counts)[::-1]], counts[np.argsort(counts)[::-1]])])
    print(f'Top 15\ncents, midi#, counts:\n{count_and_values[:15,:]}')
    value = np.unique(chorale_in_cents[:,:,0].T)
    # print the top scoring chords.
    print(f'{current_score.shape = }')
    return max_score_reported, sum_scores, count_scores, len(value), current_score, counts, value

def _get_scale(root, mode):
    """
    Get a boolean array indicating which pitch classes are in the scale.
    
    Parameters
    ----------
    root : int
        Root pitch class (0-11).
    mode : str
        'major' or 'minor'.
    
    Returns
    -------
    np.ndarray
        Boolean array of length 12, True for scale degrees.
    """
    if mode == "major":
          c_scale = np.array([1, 0, 1, 0, 1, 1, 0, 1, 0, 1, 0, 1], bool)
    elif mode == "minor":
          c_scale = np.array([1, 0, 1, 1, 0, 1, 0, 1, 1, 0, 1, 0], bool)
    else:
          raise ValueError("`mode` must be either 'major' or 'minor'.")
    return np.roll(c_scale, root)

def pitch_in_scale(chord, root, mode):
    """
    Calculate the fraction of chord notes that are in the scale.
    
    Parameters
    ----------
    chord : np.ndarray
        Array of MIDI note numbers or pitch classes.
    root : int
        Root pitch class (0-11).
    mode : str
        'major' or 'minor'.
    
    Returns
    -------
    float
        Fraction of notes in scale (0.0 to 1.0), or NaN if chord is empty.
    """
    scale = _get_scale(root, mode.lower())
    note_count = 0
    in_scale_count = 0
    for note in chord:
          note_count += 1
          if scale[note % 12]:
                in_scale_count += 1
    if note_count < 1:
          return math.nan
    return in_scale_count / note_count

def get_keysig(root, mode):
    """
    Get the key signature (number of sharps or flats) for a root and mode.
    
    Parameters
    ----------
    root : int
        Root pitch class (0-11).
    mode : str
        'major' or 'minor'.
    
    Returns
    -------
    tuple
        (num_accidentals, use_flats)
        - num_accidentals: int, number of sharps or flats
        - use_flats: int, 0 for sharps, 1 for flats
    """
    #         ['C♮','C♯','D♮','D♯','E♮','F♮','F♯','G♮','G♯','A♮','A♯','B♮']
    major_keys = np.array([ [0,   0,   2,   0,   4,   0,   6,   1,   0,   3,   0,   5 ],  # sharps
                            [0,   5,   0,   3,   0,   1,   6,   0,   4,   0,   2,   0 ]])  # flats
    minor_keys = np.array([ [0,   4,   0,   6,   1,   0,   3,   0,   5,   0,   0,   2 ],  # sharps
                            [3,   0,   1,   6,   0,   4,   0,   2,   0,   0,   5,   0 ]])  # flats
    if mode == 'major':
          accidentals = np.array([major_keys[0][root],major_keys[1][root]])
    elif mode == 'minor':
          accidentals = np.array([minor_keys[0][root],minor_keys[1][root]])
    return np.max(accidentals), np.argmax(accidentals) # how many sharps or flats, flats set to true if it should be flats instead of sharps

def assign_chorale(version, save_midi_file = False):        #, quantization = 4):
    """
    Load a chorale from corpus and extract key information.
    
    Uses music21 (not mido) to parse corpus work and extract chorale,
    root, mode, time signature, and key information.
    
    Parameters
    ----------
    version : str
        Corpus work identifier (e.g., 'bwv244.3'). Truncated to 6 chars if longer.
    save_midi_file : bool, optional
        If True, save MIDI file to disk (default: False).
    
    Returns
    -------
    tuple
        (chorale, root, mode, time_sig, stream, keys)
        - chorale: np.ndarray, shape (voices, time_steps), MIDI notes
        - root: int, pitch class (0-11) of the root note
        - mode: str, 'major' or 'minor'
        - time_sig: str, time signature (e.g., '4/4')
        - stream: music21.stream.Stream object
        - keys: np.ndarray, array of 12 note names (with appropriate accidentals)
    """
# this is the new version that doesn't require mido, only music21. 
    if len(version) > 8:
        version = version[:6]
    chorale, root, mode, time_sig, s = stream_to_midi_array(version, save_midi_file = save_midi_file)
    scale = _get_scale(root, mode.lower())
    accidentals, flats = get_keysig(root, mode)
    keys = set_accidentals(flats)
    logging.info(f'{version = }, {chorale.shape = }, {root = }, {keys[root] = }, {mode = }, {time_sig = }')
    return chorale, root, mode, time_sig, s, keys
# this function is designed to load a chorale, convert it to cents by loading a numpy array of top_notes values, returning the chorale_in_cents and top_notes array.
# this cell also proves that we have previously saved valid top_notes numpy arrays for all these wedding chorales by Bach, that all the chorales have valid notes in midi format, and that they can be converted to cent values by assigning the available top noted in the loaded array. There are no midi notes in each chorale that don't have corresponding values in the top_notes array for that chorale
def load_chorale_in_cents(version, numpy_dir, save_midi_file=False, save_top_notes=True,\
            werck_top_notes=False, twelve_tet=False):
    """
    Load a chorale and convert it to cent values using top_notes.
    
    Loads top_notes from numpy file, or initializes if not found. Converts
    MIDI chorale to cent values using top_notes (or 12-TET if twelve_tet=True).
    Expands top_notes to 12 entries if needed.
    
    Parameters
    ----------
    version : str
        Corpus work identifier (e.g., 'bwv244.3'). Truncated to 6 chars if longer.
    numpy_dir : str
        Directory containing top_notes numpy files.
    save_midi_file : bool, optional
        If True, save MIDI file to disk (default: False).
    save_top_notes : bool, optional
        If True, save expanded top_notes to file (default: True).
    werck_top_notes : bool, optional
        If True, use Werckmeister top_notes filename format (default: False).
    twelve_tet : bool, optional
        If True, use 12-TET tuning (100 cents per semitone) instead of top_notes
        (default: False).
    
    Returns
    -------
    tuple
        (chorale_in_cents, top_notes, chorale, root, mode, keys)
        - chorale_in_cents: np.ndarray, shape (voices, chords), cent values
        - top_notes: np.ndarray, shape (2, 12), [pitch_classes, cent_values]
        - chorale: np.ndarray, shape (voices, chords), MIDI notes
        - root: int, pitch class (0-11) of the root note
        - mode: str, 'major' or 'minor'
        - keys: np.ndarray, array of 12 note names
    """
    chorale, root, mode, time_sig, s, keys = assign_chorale(version, save_midi_file = save_midi_file)
    if len(version) > 8:
        version = version[:6]
    file_name = os.path.join(numpy_dir, f'{version}top-notes.npy')
    if werck_top_notes: 
        file_name = os.path.join(numpy_dir, f'{version}-w-top_notes.npy') # bwv260-w-top_notes
    # Sort all 12 pitch classes by descending frequency in the chorale.
    # Pitch classes absent from the chorale are placed at the end (freq=0), then by pc number.
    pc_counts = Counter(int(p) for p in (chorale % 12).flatten())
    sorted_pcs = sorted(range(12), key=lambda p: (-pc_counts.get(p, 0), p))

    logging.info(f'In load_chorale_in_cents. About to load top_notes from {file_name = }')
    try:
        loaded = np.load(file_name, allow_pickle=True)
        # Re-order existing cent values by current chorale frequency; fall back to 12-TET for any gap.
        existing_cents = {int(loaded[0, i]): int(loaded[1, i]) for i in range(loaded.shape[1])}
        ordered_cents = [existing_cents.get(p, p * 100) for p in sorted_pcs]
        top_notes = np.array([sorted_pcs, ordered_cents])
        logging.info(f'Loaded top_notes from {file_name}, re-ordered by chorale frequency')
    except OSError:
        logging.info(f'top_notes file not found — building from chorale frequencies with 12-TET cent values')
        top_notes = np.array([sorted_pcs, [p * 100 for p in sorted_pcs]])
        if save_top_notes:
            os.makedirs(os.path.dirname(file_name), exist_ok=True)
            np.save(file_name, top_notes)
    logging.debug(f'In load_chorale_in_cents. {top_notes.shape = }')
    logging.debug(f'{[(keys[top_note[0]], top_note[1]) for top_note in top_notes.T]}')
    logging.debug(f'{chorale.T.shape = }')
    # load chorale_in_cents to the top_notes cent values for each note. I wrote a function to do this. What was it called?
    # chord_from_top_notes(cent_values, top_notes, pitch_class_from_cents=pitch_class_from_cents):
    chorale_in_cents = (chorale % 12) * 100
    if not twelve_tet: chorale_in_cents = np.array([[top_notes[1][np.where(top_notes[0] == (note % 12))[0][0]] for note in chord] for chord in chorale])
    logging.info(f'{chorale_in_cents.shape = }, {chorale.shape = }')
    return chorale_in_cents, top_notes, chorale, root, mode, keys

# if you only want the delta
def cent_delta(a, b, max_value=1200):
    """
    Calculate the absolute interval between two cent values with wrapping.
    
    Parameters
    ----------
    a : float
        First cent value.
    b : float
        Second cent value.
    max_value : int, optional
        Maximum value for wrapping (default: 1200).
    
    Returns
    -------
    int
        Absolute interval size in cents (wrapped).
    """
    delta, _, _ = cent_value_interval((a, b), max_value=max_value)
    return delta
# retrieve a list of valid indices to tonal_diamond from which to choose the best interval. 
class LowNumberRatioIntervals():
    """
    Class for selecting valid ratio intervals from the tonal diamond.
    
    Filters intervals based on pitch class constraints and cent delta limits,
    then sorts by consonance (limit score). Uses caching for performance.
    """
    def __init__(self, tonal_diamond):
        """
        Initialize with a tonal diamond.
        
        Parameters
        ----------
        tonal_diamond : np.ndarray
            Shape (N, 3), tonal diamond [ratio, cents, limit_score].
        """      
        self.tonal_diamond = tonal_diamond
        self.cache = {}  
        self.hits = 0
        self.misses = 0
      
    def _select_ratios(self, interval, cent_value_target_prev, tolerance, max_delta=33, ratio_factor=1.0, stability_factor=0.0):
        """
        Select valid ratio indices from tonal diamond for an interval.

        Applies three filters:
        1. Strict pitch class filter: interval must map to target pitch class
        2. Cent delta filter: target cent must be within max_delta of previous chord
        3. Sort by combined key: limit_score * ratio_factor + abs(ratio_cents - interval_cents) * (1/ratio_factor)
           + delta_from_prev * stability_factor  (when prev chord is available)

        Parameters
        ----------
        interval : array-like
            Array of [cent1, cent2] values.
        cent_value_target_prev : array-like or None
            Previous chord cent values for same pitch class, or None.
        tolerance : int
            Search tolerance for finding initial ratio index.
        max_delta : int, optional
            Maximum cent difference from previous chord (default: 33).
        ratio_factor : float, optional
            Controls the consonance/stability trade-off (default: 1.0).
            Higher values favour consonant (low-limit) ratios over staying near the
            current interval. dist_factor is computed internally as 1/ratio_factor.
        stability_factor : float, optional
            Weight applied to the cent distance from the previous chord in the sort key
            (default: 0.0). Positive values bias selection toward pitch-class cent values
            that are close to the previous chord, reducing cumulative drift.

        Returns
        -------
        tuple
            (sorted_indices, cent_value_moves)
            - sorted_indices: np.ndarray, valid ratio indices sorted by combined key
            - cent_value_moves: int, direction (-1 or 1) for interval application
        """
        # midi_note = np.zeros(2, dtype=int)
        num_ratios = 20 // 2 # changed from 30 to 20 12/11/25 this is to limit the number of ratios returned. This will return 20 ratios - made this increase from 15 to 30 on 12/1/25 to deal with the fact that we are returning fewer intervals because we are checking if the interval cent target is more than max_delta from the previous chord cent for the same pitch class as the target pitch class. 
            
        cent_value_delta, cent_value_moves, cent_value_target = cent_value_interval(interval)
        pitch_class_int = pitch_class_from_cents(interval)
        pitch_class_delta, pitch_class_moves, pitch_class_target = pitch_class_interval(pitch_class_int)
        logging.debug(f'In _select_ratios. {interval = }, {cent_value_delta = }, {cent_value_moves = }, {cent_value_target = }')
        logging.debug(f'{pitch_class_delta = }, {pitch_class_moves = }, {pitch_class_target = }')
        # best_ratio_index returns the index to the lowest number ratio within +/- tolerance range in the tonal diamond. It returns just one index value. This is the starting point to finding the optimum ratio.
        initial_ratio_index = best_ratio_index(cent_value_delta, tolerance, self.tonal_diamond) 
        indices_to_tonal_diamond = np.array(list(sequence_generator(num_ratios))) # returns 2*num_ratios values, up and down. It basically starts at the ideal ratio and provides indexes to ratios that are higher and lower.
        # increment the list of 0,-1, 1, -2, 2 to the target index into tonal_diamond
        indices_to_tonal_diamond += initial_ratio_index 
        logging.debug(f'in _select_ratios. after recentering: {indices_to_tonal_diamond = }')
        # clip indices_to_tonal_diamond to one less than tonal_diamond.shape[0] so you don't use non-existing ratios
        indices_to_tonal_diamond = indices_to_tonal_diamond[(indices_to_tonal_diamond >= 0) & (indices_to_tonal_diamond < self.tonal_diamond.shape[0])]  # was 65 before 12/1/25
        logging.debug(f'in _select_ratios. after clipping: {indices_to_tonal_diamond = }')
        # create a list of booleans indicating valid ratios based on keeping the same midi values.
        # we need to offset this by the cents up or down that all four midi notes dictate based on the top_notes. 
        logging.debug(f'in _select_ratios: before creating list of allowed_intervals: {pitch_class_delta = }, {[limit_format(inx) for inx in self.tonal_diamond[indices_to_tonal_diamond]]}')
        logging.debug(f'intervals: {interval[0] = }, {interval[1] = }, {cent_value_moves = } {pitch_class_moves = }, {pitch_class_delta}, {pitch_class_target = }')
        # changed section on 12/1/25 - 12/3/25
        
        # Step 1: strict pitch-class filter
        allowed_intervals = np.array([pitch_class_from_cents(interval[0] + self.tonal_diamond[inx,1] * cent_value_moves) == pitch_class_target for inx in indices_to_tonal_diamond])
        
        indices_after_pitch_class = indices_to_tonal_diamond[allowed_intervals]
        logging.debug(f'after step 1. strict pitch class filter. {interval[0] = }, {interval[1] = } {pitch_class_delta = }, {indices_after_pitch_class = }')
        if indices_after_pitch_class.size == 0:
                logging.debug(f'in _select_ratios: no allowed intervals after step 1 pitch class filter. returning empty list.')
                return np.array([], dtype=int), cent_value_moves
        logging.debug(f'in _select_ratios: after creating list of allowed_intervals:, {[limit_format(inx) for inx in self.tonal_diamond[indices_after_pitch_class]]}')
        logging.debug(f'about to step 2. compare with previous cent {pitch_class_moves = }, {cent_value_target_prev = }')

        # Step 2: cent-delta filter (only applied to survivors)
        stability_deltas = None  # will be set when prev chord is available
        if cent_value_target_prev is None:
                indices_after_cent_delta = indices_after_pitch_class
        else:
            prev_array = np.atleast_1d(cent_value_target_prev).astype(float)
            if prev_array.size == 0:
                indices_after_cent_delta = indices_after_pitch_class
            else:
                deltas = []
                for inx_candidate in indices_after_pitch_class:
                    candidate_cent = (
                        interval[0]
                        + self.tonal_diamond[inx_candidate, 1] * cent_value_moves
                    ) % 1200
                    min_gap = np.min([
                        cent_delta(candidate_cent, prev_cent)
                        for prev_cent in prev_array
                    ])
                    deltas.append(min_gap)
                deltas = np.asarray(deltas)
                if deltas.shape[0] < 5:
                    logging.debug(f'{deltas.shape = }, {deltas = }')
                mask_cent_delta = deltas <= max_delta
                logging.debug(f'{mask_cent_delta}')
                indices_after_cent_delta = indices_after_pitch_class[mask_cent_delta]
                stability_deltas = deltas[mask_cent_delta]  # reuse in sort key
        if indices_after_cent_delta.size == 0:
            logging.debug(f'in _select_ratios: no allowed intervals after step 2 cent delta filter. returning empty list.')
            return np.array([], dtype=int), cent_value_moves
        # Step 3: sort by combined key: limit_score * ratio_factor + distance_from_interval * (1/ratio_factor)
        #         + stability_deltas * stability_factor (when prev chord is available)
        dist_factor = 1.0 / ratio_factor if ratio_factor > 0 else 0.0
        candidate_cents = self.tonal_diamond[indices_after_cent_delta, 1]
        candidate_limits = self.tonal_diamond[indices_after_cent_delta, 2]
        sort_keys = candidate_limits * ratio_factor + np.abs(candidate_cents - cent_value_delta) * dist_factor
        if stability_factor > 0 and stability_deltas is not None:
            sort_keys = sort_keys + stability_deltas * stability_factor
        sorted_indices = indices_after_cent_delta[np.argsort(sort_keys)]

        # end of changed section on 12/1/25 - 12/3/25
        # sorted_indices = indices_to_tonal_diamond[np.argsort(self.tonal_diamond[indices_after_cent_delta, 2])] # sort based on sum of numerator and denominator
        
        # added 12/2/25 to ensure ratios that are far from the previous chord get allowed    
        logging.debug(f'in _select_ratios: {sorted_indices = }, {cent_value_moves = }')
        logging.debug(f'in _select_ratios: allowed intervals: {[limit_format(inx) for inx in self.tonal_diamond[sorted_indices]]}')
        return sorted_indices, cent_value_moves

    def select_ratios(self, interval, cent_value_target_prev, tolerance, max_delta=33, ratio_factor=1.0, stability_factor=0.0): # We already passed tonal_diamond when we constructed the object.
        """
        Select valid ratio indices with caching.

        Wrapper around _select_ratios that caches results based on interval,
        previous chord, tolerance, max_delta, ratio_factor, and stability_factor.

        Parameters
        ----------
        interval : array-like
            Array of [cent1, cent2] values.
        cent_value_target_prev : array-like or None
            Previous chord cent values for same pitch class, or None.
        tolerance : int
            Search tolerance for finding initial ratio index.
        max_delta : int, optional
            Maximum cent difference from previous chord (default: 33).
        ratio_factor : float, optional
            Controls consonance/stability trade-off (default: 1.0).
        stability_factor : float, optional
            Weight applied to the cent distance from the previous chord in the sort
            key (default: 0.0). See _select_ratios for details.

        Returns
        -------
        tuple
            (sorted_indices, cent_value_moves)
            - sorted_indices: np.ndarray, valid ratio indices sorted by combined key
            - cent_value_moves: int, direction (-1 or 1) for interval application
        """
        interval_key = tuple(int(x) for x in np.asarray(interval, dtype=int))
        if cent_value_target_prev is None:
                target_key = None
        else:
                target_array = np.atleast_1d(cent_value_target_prev)
                if target_array.size == 0:
                    target_key = None
                else:
                    target_key = tuple(int(np.round(val)) % 1200 for val in target_array)
        key = (interval_key, target_key, int(tolerance), int(max_delta), float(ratio_factor), float(stability_factor))
        if key in self.cache:
                self.hits += 1
                return self.cache[key]
        else:
                self.misses += 1
                result = self._select_ratios(interval, cent_value_target_prev, tolerance, max_delta=max_delta, ratio_factor=ratio_factor, stability_factor=stability_factor)
                self.cache[key] = result
                return result
      
    def reset_cache(self):
        """
        Clear the cache.
        
        Returns
        -------
        None
        """
        self.cache = {}
            
    def return_cache_results(self):
        """
        Get cache statistics.
        
        Returns
        -------
        tuple
            (hits, misses)
            - hits: int, number of cache hits
            - misses: int, number of cache misses
        """
        return self.hits, self.misses

class ChordScorer():
    """
    Class for scoring chords based on interval consonance.
    
    Scores chords by finding intervals between all note pairs and summing
    their limit scores from the tonal diamond. Uses caching for performance.
    """
    def __init__(self, tonal_diamond):
        """
        Initialize with a tonal diamond.
        
        Parameters
        ----------
        tonal_diamond : np.ndarray
            Shape (N, 3), tonal diamond [ratio, cents, limit_score].
        """
        self.tonal_diamond = tonal_diamond
        self.cache = {}
        self.hits = 0
        self.misses = 0
      
      # this function takes in an interval and tolerance value
      # it tries to find the lowest scoring interval within the provided tolerance, rather than the exact interval provided.
      # It returns that index value and a boolean indicating if it found that interval within the tolerance of a ratio in the tonal diamond
      # If it doesn't find that a legitimate ratio, returns the result of the searchsorted function and the boolean is set to false. 
    def find_best_interval(self, distance, tolerance):
        """
        Find the best matching interval in the tonal diamond.
        
        Searches for the interval closest to the given distance within tolerance.
        
        Parameters
        ----------
        distance : float
            Interval distance in cents (absolute value is used).
        tolerance : int
            Maximum allowed difference from distance.
        
        Returns
        -------
        tuple
            (best_idx, found)
            - best_idx: int, index into tonal_diamond of closest match
            - found: bool, True if match is within tolerance, False otherwise
        """
        distance = abs(distance)

        # Find the absolute difference to every cent value in tonal_diamond
        diffs = np.abs(self.tonal_diamond[:, 1] - distance)

        # Get the index of the closest entry
        best_idx = np.argmin(diffs)
        best_diff = diffs[best_idx]

        if best_diff <= tolerance:
                # Within tolerance → success
                _, _, interval_score = self.tonal_diamond[best_idx]
                logging.debug(f'found an interval within {tolerance = } returning {best_idx = }, with {interval_score = }')
                return best_idx, True
        else:
                # Outside tolerance → fail
                logging.debug(f'closest interval to {distance} was {limit_format(self.tonal_diamond[best_idx])}. but {tolerance = } < {best_diff = }')
                return best_idx, False
            
    def _score_chord(self, cent_values_chord, tolerance=1, method=combinations):
        """
        Score a chord by summing interval limit scores.
        
        Calculates all intervals between note pairs and sums their limit scores.
        Adds penalty (1000) for intervals not found in tonal diamond.
        
        Parameters
        ----------
        cent_values_chord : np.ndarray
            Array of cent values for the chord.
        tolerance : int, optional
            Tolerance for interval matching (default: 1).
        method : callable, optional
            Function to generate note pairs (default: combinations).
            Should be combinations or permutations.
        
        Returns
        -------
        float
            Chord score (sum of interval limit scores, rounded to 1 decimal).
        """
        score = 0
        for notes in method(cent_values_chord, 2):  # this used to be combinations(cent_values_chord, 2):
            cent_value_interval_pair = np.array([notes[0], notes[1]]) 
            cent_value_delta, cent_value_moves, cent_value_target = cent_value_interval(cent_value_interval_pair)
            logging.debug(f'In _score_chord. {cent_value_delta, cent_value_moves, cent_value_target = }')
            found = False
            if cent_value_delta > 0:
                best_index = 0
                best_index, found = self.find_best_interval(cent_value_delta, tolerance)
                logging.debug(f'In _score_chord. {best_index = }, {found = }')
                if found: logging.debug(f'In _score_chord. found cent value for interval: {limit_format(self.tonal_diamond[best_index])}')
                if not found:
                        score += 1000  
                score += self.tonal_diamond[best_index, 2]  
                logging.debug(f'{score = }')
        return round(score, 1)
      
    def score_chord(self, cent_values_chord, tolerance=1, method=combinations):
        """
        Score a chord with caching.
        
        Wrapper around _score_chord that caches results based on chord values,
        tolerance, and method.
        
        Parameters
        ----------
        cent_values_chord : np.ndarray
            Array of cent values for the chord.
        tolerance : int, optional
            Tolerance for interval matching (default: 1).
        method : callable, optional
            Function to generate note pairs (default: combinations).
        
        Returns
        -------
        float
            Chord score (sum of interval limit scores, rounded to 1 decimal).
        """
        key = tuple(cent_values_chord)
        # logging.info(f'In score_chord function. {tolerance = }, {cent_values_chord = }')
        if key in self.cache:
                self.hits += 1
                return self.cache[key]
        
        else:
                self.misses += 1
                result = self._score_chord(cent_values_chord, tolerance=tolerance, method=method)
                self.cache[key] = result
                return result
            
    def reset_cache(self):
        """
        Clear the cache.
        
        Returns
        -------
        None
        """
        self.cache = {}
      
    def return_cache_results(self):
        """
        Get cache statistics.
        
        Returns
        -------
        tuple
            (hits, misses)
            - hits: int, number of cache hits
            - misses: int, number of cache misses
        """
        return self.hits, self.misses
            
      
# this is obsolete and should be removed in favor of the class ChordScorer_v2 above:
def score_chord_cents_v2(chord_1200, tonal_diamond, tolerance = 1):
    """
    Score a chord by summing interval limit scores.
    
    NOTE: This function is obsolete. Use ChordScorer class instead.
    Calculates all intervals between note pairs and sums their limit scores.
    
    Parameters
    ----------
    chord_1200 : np.ndarray
        Array of cent values for the chord.
    tonal_diamond : np.ndarray
        Shape (N, 3), tonal diamond [ratio, cents, limit_score].
    tolerance : int, optional
        Tolerance for interval matching (default: 1).
    
    Returns
    -------
    float
        Chord score (sum of interval limit scores, rounded to 1 decimal).
    """
    score = 0
    logging.debug(f'{tonal_diamond.shape = }')
    for inx, notes in zip(count(0,1), combinations(chord_1200, 2)): # compare every note in the chord to every other note in the chord two at a time, 6 compares for a 4 note chord
    # for notes in permutations(chord_1200,2): # just gives 2x the score from combinations. No new information., 
        distance = abs(notes[0] - notes[1])
        # need to search for this distance in the tonal_diamond_cents array
        logging.debug(f'{inx}: {notes = }, {distance = }')
        found = False
        index_to_limits = 0
        if distance > 0:
            best_choice = 9_999
            best_index = 0
            # for gap in np.array([0, -1 * tolerance, tolerance]): # it checks the distance plus or minus tolerance
            for gap in np.arange(-1 * tolerance, tolerance + 1, 1):
                logging.debug(f'{inx}: checking near distances. {gap = }')
                logging.debug(f'{inx}: {np.searchsorted(tonal_diamond[:,1], distance + gap) = }')
                index_to_limits = np.min([np.searchsorted(tonal_diamond[:,1], distance + gap), tonal_diamond.shape[0] - 1])
                logging.debug(f'{inx}: {index_to_limits = }, {distance + gap = }') # gap = 0, distance = 316, index = 56
                if index_to_limits >= tonal_diamond.shape[0]:
                        logging.debug(f'{inx}: {index_to_limits = }, should not exceed {tonal_diamond.shape = }')
                if tonal_diamond[index_to_limits, 1] == distance + gap: # example: 316 is in the table
                    found = True
                    interval_score = tonal_diamond[index_to_limits][2]
                    if interval_score < best_choice:
                        best_choice = interval_score
                        best_index = index_to_limits
                    logging.debug(f'{inx}: found a cent in the table. {limit_format(tonal_diamond[best_index])}')
                    # break
            if not found:
                score += 1000 # this is a stopgap remedy to prevent moving a note. 
                logging.debug(f'{inx}: {notes} could not find the interval in the ratio table. {distance = }, closest distance found: {tonal_diamond[index_to_limits, 1]}')
            logging.debug(f'{notes[0]}, {notes[1]}, {distance = }, {tonal_diamond[best_index, 2]}')
            score += tonal_diamond[best_index, 2] # 2 is num_den for this discovered interval
            logging.debug(f'{inx}: {best_choice = } num_den: {tonal_diamond[best_index, 2]}, {score = }')
    logging.debug(f'in score_chord_cents_v2. {score = }') # 8/19/23 should I make this division? 8/27/23: no, it's not necessary.
    logging.debug(f'at end of score_chord_cents_v2.')
      
    return round(score,1)



# print just the necessaries                  
def print_simple_report(best_results, best_scores, keys, chord_scorer, tonal_diamond, print_intervals=True,\
      print_to_output=0, worse_count=30, tolerance = 0):
    """
    Print a simplified report of chord scores.
    
    Prints chord information and lists the worst-scoring chords.
    
    Parameters
    ----------
    best_results : np.ndarray
        Shape (chords, 4), cent values for each chord.
    best_scores : np.ndarray
        Array of scores for each chord.
    keys : np.ndarray
        Array of 12 note names.
    chord_scorer : ChordScorer
        ChordScorer instance for scoring.
    tonal_diamond : np.ndarray
        Shape (N, 3), tonal diamond (for reference).
    print_intervals : bool, optional
        If True, print interval details (default: True).
    print_to_output : int, optional
        Number of chords to print in detail (default: 0).
    worse_count : int, optional
        Number of worst chords to list (default: 30).
    tolerance : int, optional
        Tolerance for scoring (default: 0).
    
    Returns
    -------
    tuple
        (score_results, total_score, chord_num, max_measured_score, max_measured_chord)
        - score_results: list of (score, chord_index) tuples
        - total_score: float, sum of all chord scores
        - chord_num: int, number of unique chords
        - max_measured_score: float, highest score found
        - max_measured_chord: int, chord index with highest score
    """
      
    prev_chord = np.zeros(4, dtype=int)
    total_score = 0
    chord_num = 0
    max_measured_score = 0
    max_measured_chord = 0
    # limit_denominator = 50
    score_results = []
    logging.info(f'Chord# Midi Notes       Note Names                    Cent Values       Score')
    for inx, chord, best_score in zip(count(0,1), best_results, best_scores):
        if np.array_equal(prev_chord, chord):
            pass
        else:
            total_score += best_score
            max_measured_score = np.max([best_score, max_measured_score])
            if best_score == max_measured_score: max_measured_chord = inx
            if print_to_output > 0:
                logging.info(f'{inx}:\t{[int(round(note/100)) % 12 for note in chord]}\t{[keys[int(round(note/100)) % 12] for note in chord]}\t{np.array2string(chord)}\t{best_score}')
            print_to_output -= 1
            if print_intervals:
                pass
                
            chord_num += 1 # only count unique chords in the total and average values
            prev_chord = chord.copy()
            score_results.append((best_score, inx))
    # best_score = np.array([score_chord_cents_v2(chord,tonal_diamond) for chord in best_results])
    logging.debug(f'Chord shape: {best_results.T.shape}, Chord scores: {best_scores.shape}')
    # score_num = 15
    start_value = 0
    chord_numbers = np.arange(best_results.T.shape[1])
    sorted_indices = np.argsort(best_scores)[::-1][:worse_count]
    chorale_in_cents_sorted = best_results.T[:, sorted_indices]
    scores_sorted = best_scores[sorted_indices]
    chord_numbers = chord_numbers[sorted_indices]
    logging.info(f'These are top {worse_count} scores sorted by scores, highest at the top')
    logging.info(f'chord\tnote numbers\t\tnote names\t\t\tscores')
    for inx, chord_num, chord, score in zip(count(start_value,1), chord_numbers, chorale_in_cents_sorted.T, scores_sorted):
        if not np.array_equal(chord, prev_chord):
            chord_12 = np.array([int(round(note / 100,0)) for note in chord])
            logging.info(f'{inx}: {np.array2string(chord_num)}\t{[int(round(note, 0) % 12) for note in chord_12]}\t{[keys[int(round(note, 0) % 12)] for note in chord_12]}\t{np.array2string(score)}')
        prev_chord = np.copy(chord)

    prev_chord = np.zeros(4)
    chord_list = []
    for chord_num, score, chord in zip(chord_numbers, scores_sorted, chorale_in_cents_sorted.T):
        if not np.array_equal(chord, prev_chord):
            chord_list.append(chord_num)
        prev_chord = chord.copy()
    logging.info(f'Here are the worst chords in a list: include_list = np.array({chord_list})')
    logging.info(f'End of print_simple_report.')
    return score_results, total_score, chord_num, max_measured_score, max_measured_chord 
      
# this is all the necessaries.
def compress_chorale(chorale, chorale_in_cents):
    """
    Compress chorale and chorale_in_cents to unique rows.
    
    Finds unique chord patterns and creates mapping to restore original order.
    Useful for parallel processing of unique chords only.
    
    Parameters
    ----------
    chorale : np.ndarray
        Shape (N, 4), integer array of chorale rows (MIDI notes).
    chorale_in_cents : np.ndarray
        Shape (N, 4), parallel array aligned with chorale (cent values).
    
    Returns
    -------
    tuple
        (unique_chorale, unique_cents, inverse)
        - unique_chorale: np.ndarray, shape (M, 4), unique rows in order of first appearance
        - unique_cents: np.ndarray, shape (M, 4), corresponding cent values
        - inverse: np.ndarray, shape (N,), mapping to reconstruct original arrays
    """
    """
    Compress chorale and chorale_in_cents to unique rows,
    preserving the order of first occurrence.

    Parameters
    ----------
    chorale : np.ndarray, shape (N, 4)
        Integer array of chorale rows.
    chorale_in_cents : np.ndarray, shape (N, 4)
        Parallel array aligned with chorale.

    Returns
    -------
    unique_chorale : np.ndarray, shape (M, 4)
        Unique rows of chorale, in order of first appearance.
    unique_cents : np.ndarray, shape (M, 4)
        Corresponding rows from chorale_in_cents.
    inverse : np.ndarray, shape (N,)
        Indices to reconstruct the original arrays from the unique ones.
    """
    unique_chorale, indices, inverse = np.unique(chorale, axis=0, return_index=True, return_inverse=True)

    # Preserve order of first occurrence
    order = np.argsort(indices)
    unique_chorale = unique_chorale[order]
    unique_cents = chorale_in_cents[indices[order]]

    # Remap inverse to match the new ordering
    remap = np.zeros_like(order)
    remap[order] = np.arange(len(order))
    inverse = remap[inverse]

    return unique_chorale, unique_cents, inverse

# This is after we have called the parallelizer routine on the compressed list of chords
def decompress_chorale(unique_cents, inverse, tolerance=1):
    """
    Restore chorale_in_cents to its original shape from compressed form.
    
    Reconstructs the full chorale_in_cents array using processed unique chords
    and the inverse mapping.
    
    Parameters
    ----------
    unique_cents : np.ndarray
        Shape (M, 4), processed unique chorale_in_cents rows.
    inverse : np.ndarray
        Shape (N,), mapping back to the original order.
    tolerance : int, optional
        Tolerance parameter (unused, kept for compatibility) (default: 1).
    
    Returns
    -------
    np.ndarray
        Shape (N, 4), restored chorale_in_cents array.
    """
    cents_restored = unique_cents[inverse]
    
    
    return cents_restored
