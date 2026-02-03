"""
diamond_music_utils.py — Internal copy
This file is an internal repository copy of the project's diamond music utilities.
Author: Prent Rodgers (project owner).
Date: 2026-02-03
"""

import numpy as np
import numpy.testing as npt
from importlib import reload
import os
import sys
import time
import logging
from fractions import Fraction
from numpy.random import default_rng
from scipy.interpolate import make_interp_spline
rng = np.random.default_rng()
from itertools import count

# (rest of file unchanged)

def build_all_ratios(limit_value = 31):
      all_ratios = []
      for limit in ([limit_value]): # calculate the size of tonality diamond to the n-limit and create the array all_ratios.
            end_denom = limit + 1
            start_denom = (end_denom) // 2
            o_numerator = np.arange(start_denom, end_denom, 1) # create a list of overtones
            u_denominator = np.arange(start_denom, end_denom, 1) # create a list of undertones
            all_ratios = []
            for oton_root in u_denominator:
                  # logging.debug()
                  for overtone in o_numerator:
                        if overtone < oton_root: oton = overtone * 2
                        else: oton = overtone
                        all_ratios.append(oton / oton_root)
      return all_ratios

def build_ratio_strings(all_ratios):
      shape_values = np.sqrt(len(all_ratios)) # s
      ratio_strings = np.array([str(Fraction(ratio).limit_denominator(max_denominator = 100)) for ratio in all_ratios]).reshape(int(shape_values), int(shape_values))
      i = 0
      for ratio in ratio_strings:
            j = 0
            for r in ratio:
                  if ratio_strings[i,j] == '1': 
                        ratio_strings[i,j] = '1/1'
                  j += 1
            i += 1
      return ratio_strings

# stored_gliss = np.empty((0,70), dtype = float)
current_gliss_table = 1500 # raised on 4/28/23 to make more room for samples. Previously, samples occupied 601 - 798 increased it  to 1500
all_ratios = build_all_ratios()
ratio_strings = build_ratio_strings(all_ratios)
all_ratio_strings = ratio_strings.reshape(256,)

keys = {'oton': {ratio_strings[0, 0]: np.arange(0 * 16, 1 * 16, 1),
                  ratio_strings[1 ,0]: np.arange(1 * 16, 2 * 16, 1),
                  ratio_strings[2 ,0]: np.arange(2 * 16, 3 * 16, 1),
                  ratio_strings[3 ,0]: np.arange(3 * 16, 4 * 16, 1),
                  ratio_strings[4 ,0]: np.arange(4 * 16, 5 * 16, 1),
                  ratio_strings[5 ,0]: np.arange(5 * 16, 6 * 16, 1),
                  ratio_strings[6 ,0]: np.arange(6 * 16, 7 * 16, 1),
                  ratio_strings[7 ,0]: np.arange(7 * 16, 8 * 16, 1),
                  ratio_strings[8 ,0]: np.arange(8 * 16, 9 * 16, 1),
                  ratio_strings[9 ,0]: np.arange(9 * 16, 10 * 16, 1),
                  ratio_strings[10, 0]: np.arange(10 * 16, 11 * 16, 1),
                  ratio_strings[11, 0]: np.arange(11 * 16, 12 * 16, 1),
                  ratio_strings[12, 0]: np.arange(12 * 16, 13 * 16, 1),
                  ratio_strings[13, 0]: np.arange(13 * 16, 14 * 16, 1),
                  ratio_strings[14, 0]: np.arange(14 * 16, 15 * 16, 1),
                  ratio_strings[15, 0]: np.arange(15 * 16, 16 * 16, 1)
                  },
            'uton': {ratio_strings[0, 0]: np.arange(0, 256, 16),
                  ratio_strings[0, 1]: np.arange(1, 256, 16),
                  ratio_strings[0, 2]: np.arange(2, 256, 16),
                  ratio_strings[0, 3]: np.arange(3, 256, 16),
                  ratio_strings[0, 4]: np.arange(4, 256, 16),
                  ratio_strings[0, 5]: np.arange(5, 256, 16),
                  ratio_strings[0, 6]: np.arange(6, 256, 16),
                  ratio_strings[0, 7]: np.arange(7, 256, 16),
                  ratio_strings[0, 8]: np.arange(8, 256, 16),
                  ratio_strings[0, 9]: np.arange(9, 256, 16),
                  ratio_strings[0, 10]: np.arange(10, 256, 16),
                  ratio_strings[0, 11]: np.arange(11, 256, 16),
                  ratio_strings[0, 12]: np.arange(12, 256, 16),
                  ratio_strings[0, 13]: np.arange(13, 256, 16),
                  ratio_strings[0, 14]: np.arange(14, 256, 16),
                  ratio_strings[0, 15]: np.arange(15, 256, 16)                 
                  }
                  }
      # build the 8 note scales for each of the rank A, B, C, D otonal and utonal out of the 16 note scales
#                                                        start, end, step size
# make this dictionary nested: rank, mode
scales = {'A': {'oton': np.array([note % 16 for note in np.arange(0, 16, 2)]),
                      'uton': np.array([note % 16 for note in np.arange(8, -8, -2)])}, # utonal goes down, so that the scale will go up.
                'B': {'oton': np.array([note % 16 for note in np.arange(2, 18, 2)]),
                      'uton': np.array([note % 16 for note in np.arange(14, -2, -2)])},
                'C': {'oton': np.array([note % 16 for note in np.arange(1, 17, 2)]),
                      'uton': np.array([note % 16 for note in np.arange(13, -2, -2)])},
                'D': {'oton': np.array([note % 16 for note in np.arange(3, 19, 2)]),
                      'uton': np.array([note % 16 for note in np.arange(15, 0, -2)])},
          # the next 8 are additional 8 note scales that have good 3:2, and interesting thirds
                'E': {'oton': np.array([ 2,  4,  6,  8, 11, 13, 15,  0]), # 3rd: 11:9 neutral
                      'uton': np.array([ 8,  6,  4,  2,  0, 15, 13, 11])}, # 3rd: 6:5 minor
                'F': {'oton': np.array([ 8, 10, 12, 14,  0,  2,  4,  6]), # 3rd: 7:6 subminor
                      'uton': np.array([ 0, 14, 12, 10,  8,  6,  4,  2])}, # 3rd: 8:7 subminor
                'G': {'oton': np.array([ 4,  6,  8, 10, 14, 15,  0,  2]), # 3rd: 6:5 minor
                      'uton': np.array([14, 10,  8,  6,  4,  2,  0, 15])}, # 3rd: 5:4 major
                'H': {'oton': np.array([12, 14,  0,  2,  5,  7,  9, 11]), # 3rd: 8:7 sub-subminor
                      'uton': np.array([5,  3,   1, 15, 12, 10,  8,  6])} # 3rd: 21/17 neutral
               }
      # this dictionary is helpful in doing a lookup of different inversions of a chord
# choose the notes in scale for each rank (A, B, C, D), mode (oton, uton), & inversion (1, 2, 3, 4)
# access the four note chords by specifying inversions[rank][mode][inv]
# where rank is in (A, B, C, D) mode is in (oton, uton), and inv is in (1, 2, 3, 4)
# use the resulting array as the index into a keys[mode][ratio]

inversions = {
    'A': {
        'oton': {
            1: np.array([0, 4, 8, 12]),
            2: np.array([4, 8, 12, 0]),
            3: np.array([8, 12, 0, 4]),
            4: np.array([12, 0, 4, 8])
        },
        'uton': {
            1: np.array([0, 12, 8, 4]),
            2: np.array([12, 8, 4, 0]),
            3: np.array([8, 4, 0, 12]),
            4: np.array([4, 0, 12, 8])
        }
    }
}

# NOTE: The full `inversions` table was truncated in this vendored copy to keep the file compact.
# For full functionality use the upstream Diamond_Music repository or restore the original content.