#!/usr/bin/env python
# coding: utf-8

# ## Building "Straw Man" Chords
# <p>This notebook is designed to show a quick-and-dirty way to tune chords to the optimal cent values based on the lowest available integer ratios. We go through all 12 permutations of intervals in a 4 note chord, and assign the lowest possible ratio that is near the interval requested. We keep that chord if it helps the score, and ignore it if it increases the score. I used this method as the basis of further work where we applied the technique of simulated annealing to choose the next interval, instead of always accepting the lowest number ratio.</p>
# <p>We show to additional cells to illustrate how we score chords, and a heavily commented version of how we choose intervals in this base case. </p>
# <p>Why choose permutations, which counts intervals twice, up and down? I've found that it works better empirically. If you use combinations, which check 6 intervals, we force the initial note in the chord to never move. If it's allowed to drift like all the other notes in the chord, the results are better</p> 
# <p>The outcome of this process is a chord that can be transposed to improve on horizontal consistency, that is choose a transposition that keeps cent values of pitch classes of adjacent chords in place, if possible. If it's not possible, then I build a glissando in csound to hide the change, to a certain degree. In this way we hear ideal intervals for every chord, at the expense of some effort of some voices to move from one cent value to another for the same pitch class, to optimize the current chord.</p>
# 

import argparse, logging, os, sys, time
import numpy as np
from math import exp
from importlib import reload
from collections import Counter, defaultdict
from importlib import reload
base_dir = os.path.dirname(os.path.abspath(__file__))
numpy_dir = os.path.join(base_dir, 'Archive', 'straw-man')
import diamond_music_utils as dmu
import adaptive_tuning_util as atu
from itertools import count, combinations, permutations
rng = np.random.default_rng()

np.set_printoptions(legacy='1.25')

def start_logger(logfile: str, level=logging.INFO):
    # Reset the root logger
    root = logging.getLogger()
    root.handlers.clear()
    root.setLevel(level)

    # File handler only
    fh = logging.FileHandler(logfile, mode='w')
    fh.setLevel(level)

    formatter = logging.Formatter(
        fmt='%(asctime)s - %(levelname)s - %(message)s',
        datefmt='%d'
    )
    fh.setFormatter(formatter)

    root.addHandler(fh)

    root.info(f"Logger started, writing to {logfile}, level={logging.getLevelName(level)}")
    return root

start_logger(os.path.join(base_dir, 'test.log'), level = logging.INFO)
reload(atu)

def find_cent_value_prev_target(pitch_class_target, pitch_class_chord_prev, cent_value_chord_prev, chord_num):
    if pitch_class_target in pitch_class_chord_prev:
        cent_value_target = np.unique(cent_value_chord_prev[np.where(pitch_class_chord_prev==pitch_class_target)])[0]
        logging.info(f'chord#: {chord_num} found {pitch_class_target in pitch_class_chord_prev = }, {cent_value_target = }, {pitch_class_chord_prev = }')
    else:
        logging.info(f'chord#: {chord_num} not found {pitch_class_target in pitch_class_chord_prev = }, {pitch_class_chord_prev = }')
        cent_value_target = None
    return cent_value_target

# this is a version of build_straw_man_chord based on all 12 intervals (using permutations) choosing their optimum, last change wins algorithm.
# It's pretty good. The test harness has to rearrange the chords back to their original order. 
def build_straw_man_chord(cent_value_chord, cent_value_chord_prev, chord_num, chord_scorer, low_number_ratios, tonal_diamond, tolerance, print_values=False, rolls=4):
    logging.info(f'chord#: {chord_num} In build_straw_man_chord. {tolerance = }')
    initial_midi_chord = atu.pitch_class_from_cents(cent_value_chord)
    best_cent_value_chord_so_far = cent_value_chord.copy()
    best_cent_value_score = 9999
    pitch_class_chord_prev = atu.pitch_class_from_cents(cent_value_chord_prev)
    # proposed_cent_value_chord = cent_value_chord.copy() # initialized by the caller.
    changed_cent_value_count = 0
    unchanged_cent_value_count = 0
    for inx, proposed_cent_value_chord in enumerate(np.array([np.roll(cent_value_chord, roll_amount)\
            for roll_amount in np.arange(rolls)])):
        chord_size = proposed_cent_value_chord.shape[0]
        pitch_class_chord = atu.pitch_class_from_cents(proposed_cent_value_chord)
        proposed_chord_score = chord_scorer.score_chord(proposed_cent_value_chord,tolerance=tolerance)
        logging.info(f'chord#: {chord_num} roll_amount. {inx}: {proposed_cent_value_chord = }')

        for interval_inx in permutations(np.arange(chord_size),2):
            pitch_class_interval = np.array([pitch_class_chord[interval_inx[0]], pitch_class_chord[interval_inx[1]]]) # an integer representing the number of pitch class steps in this interval. 
            cent_value_interval = np.array([proposed_cent_value_chord[interval_inx[0]], proposed_cent_value_chord[interval_inx[1]]]) # the cent value of the interval about to be replaced.
            pitch_class_delta, pitch_class_moves, pitch_class_target = atu.pitch_class_interval(pitch_class_interval)
            cent_value_delta, cent_value_moves, cent_value_target = atu.cent_value_interval(cent_value_interval)

            logging.info(f'chord#: {chord_num} {pitch_class_delta = }, {pitch_class_moves = }, {cent_value_delta = }, {cent_value_moves = }')

            logging.info(f'chord#: {chord_num} {pitch_class_target = }, {cent_value_target = }') # this is the target to be replaced
            # Find the cent value in the previous chord for the pitch class of the target of the interval in the current chord. The goal is to provide a hint to the select_ratios method to ensure that the cent value for that target pitch class will be near the cent value of the same pitch class in the previous chord. 
            cent_value_target = find_cent_value_prev_target(pitch_class_target, pitch_class_chord_prev, cent_value_chord_prev, chord_num)
            indices_to_tonal_diamond, _ = low_number_ratios.select_ratios(cent_value_interval, cent_value_target, tolerance)
            logging.info(f'chord#: {chord_num} {[atu.limit_format(tonal_diamond[interval]) for interval in indices_to_tonal_diamond] = }')
            interval_choice = 0 # choose the one with the lowest num_den value always. Change this if you want to explore more exploit less
            saved_cent_value_chord = proposed_cent_value_chord.copy() # preserve the chord as built so far
            logging.info(f'chord#: {chord_num} {pitch_class_interval = }, {cent_value_interval = }')
            if indices_to_tonal_diamond.size == 0:
                logging.info(f'chord#: {chord_num} no ratios found for this interval. skipping. {pitch_class_interval = }, {cent_value_interval = }')
                continue
            else: logging.info(f'chord#: {chord_num} {cent_value_interval[0] = }, {tonal_diamond[indices_to_tonal_diamond[interval_choice]][1]  = }')
            # now update the proposed score with this new note as a potential alteration to the chord tuning. 
            proposed_cent_value_chord[interval_inx[1]] = (proposed_cent_value_chord[interval_inx[0]] + tonal_diamond[indices_to_tonal_diamond[interval_choice]][1] * cent_value_moves) % 1200
            proposed_chord_score = chord_scorer.score_chord(proposed_cent_value_chord, tolerance=tolerance)
            # what if this is the best so far? Should not I hang on to these results? Prove me wrong here. 
            if proposed_chord_score >= best_cent_value_score:
                proposed_cent_value_chord = saved_cent_value_chord.copy()
                unchanged_cent_value_count += 1
            else:
                # Make the change. keep proposed_cent_value_chord because the score is better. 
                changed_cent_value_count += 1
                best_cent_value_chord_so_far = proposed_cent_value_chord.copy()
                best_cent_value_score = proposed_chord_score
                logging.info(f'new best: {inx}: {best_cent_value_chord_so_far = }, score: {proposed_chord_score}')
            if print_values:
                print(f'{interval_inx} ', end=' | ') # (0, 1)
                print(f'{atu.format_chord(pitch_class_interval,2)} | {atu.format_chord(cent_value_interval,4)}', end=' | ') #  | 4 11 |  416 1102 | 
                print(f'{pitch_class_delta * pitch_class_moves:>7}', end=' | ')  # |      -5 |
                print(f'{cent_value_delta * cent_value_moves:>7}', end=' | ')    # |    -514 |
                # new addition:
                print_ratios = np.array([atu.pitch_class_from_cents(cent_value_interval[0] + tonal_diamond[ratio,1] * cent_value_moves) for ratio in indices_to_tonal_diamond[:4]])[:63]
                # end of new additions
                print(f'{atu.format_chord(print_ratios,2):<12}', end=' | ')
                print_ratios = " ".join([atu.stringify(tonal_diamond[ratio,0]) for ratio in indices_to_tonal_diamond[:4]])
                print(f'{tonal_diamond[indices_to_tonal_diamond[0]][1]:>6}', end=' | ')
                print(f'{proposed_chord_score:>6}', end=' | ')
                print(f'{atu.format_chord(best_cent_value_chord_so_far,4)}', end=' | ')
                print(f'{print_ratios:<23}') 
    proposed_cent_value_chord, _ = atu.rearrange_notes(best_cent_value_chord_so_far, initial_midi_chord)
    return proposed_cent_value_chord, changed_cent_value_count, unchanged_cent_value_count


def parse_args():
    parser = argparse.ArgumentParser(description='Straw Man tuning of Bach chorales using lowest number ratios')
    parser.add_argument('--limit_max', type=int, default=23, help='Maximum limit for tonal diamond (default: 23)')
    parser.add_argument('--max_delta', type=int, default=35, help='Maximum delta (default: 35)')
    parser.add_argument('--tolerance', type=int, default=None, help='Tolerance for chord scoring. Required (e.g. --tolerance 3).')
    parser.add_argument('--rolls', type=int, default=1, help='Number of rolls for chord permutations (default: 1)')
    parser.add_argument('--include_list', type=str, default=None,
                        help='Slice of chords to include, e.g. "8:17" (default: None, use all chords)')
    parser.add_argument('--chorale_list', type=str, nargs='+', default=['bwv253'],
                        help='List of chorale versions to process (default: bwv253)')
    parser.add_argument('--print_values', action=argparse.BooleanOptionalAction, default=True,
                        help='Print interval details (default: True)')
    parser.add_argument('--print_finals', action=argparse.BooleanOptionalAction, default=True,
                        help='Print final chord results (default: True)')
    parser.add_argument('--print_initial', action=argparse.BooleanOptionalAction, default=True,
                        help='Print initial chord info (default: True)')
    args = parser.parse_args()
    if args.tolerance is None:
        parser.error('--tolerance is required (e.g. --tolerance 3)')
    return args

def main():
    args = parse_args()
    print(' '.join(f'--{arg} {value}' for arg, value in vars(args).items()))

    # test harness for build_straw_man_chord just by itself. I'll use this to do a number of things.
    # 1. verify that it works correctly on it's own
    # 2. See if you can combine find_large_cent_value_jumps with the priority of top_notes (not their cent values)
    # it started working on 10/22/25 Still some residual wrong variables for midi_value_chord_current
    reload(atu)
    start_logger(os.path.join(base_dir, 'test.log'), level = logging.INFO)
    print(f'{numpy_dir = }')
    limit_max = args.limit_max
    max_delta = args.max_delta
    tonal_diamond = atu.build_tonal_diamond(limit_max)[:-1] # stop using the 2 at the end.
    print(f'{limit_max = }, {tonal_diamond.shape = }')
    tolerance = args.tolerance
    rolls = args.rolls
    chord_scorer = atu.ChordScorer(tonal_diamond)
    low_number_ratios = atu.LowNumberRatioIntervals(tonal_diamond)
    # parse include_list from string like "8:17" into a slice
    if args.include_list is not None:
        parts = args.include_list.split(':')
        include_list = slice(int(parts[0]), int(parts[1]) if len(parts) > 1 else None)
    else:
        include_list = None
    chorale_list = args.chorale_list
    print_values = args.print_values
    print_finals = args.print_finals
    print_initial = args.print_initial
    for version in chorale_list:
        cent_value_chorale, top_notes, chorale, root, mode, keys = atu.load_chorale_in_cents(version, numpy_dir, werck_top_notes=False)
        logging.info(f'cent value based on top_notes')
        for i in range(min(10, cent_value_chorale.shape[1])):
            logging.info(f'Chord {i}: {cent_value_chorale[:,i]}')
        if include_list is not None:
            cent_value_chorale = cent_value_chorale[:, include_list]
            chorale = chorale[:, include_list]
        cent_value_chorale = np.array([(chord % 12) * 100 for chord in chorale.T]).T.astype(int) # convert to cents
        logging.info(f'{cent_value_chorale.shape = }, {chorale.shape = }, {keys[root]} {mode}')
        # print the first 10 chords of cent_value_chorale to verify that the conversion to cents worked correctly.
        logging.info(f'cent value based on 12 TET')
        for i in range(min(10, cent_value_chorale.shape[1])):
            logging.info(f'Chord {i}: {cent_value_chorale[:,i]}')
        logging.info(f'{cent_value_chorale.shape = }, {chorale.shape = }, {keys[root]} {mode}')
        atu.log_top_notes(top_notes) # , function_name=print
        heading = f'{"inx":^6}  | pc int|  cent int |  Δ  pc  |  Δ cent | target pitch |  1st   | score  |  cent values   | all ratios '
        if print_values:
            print(heading)
        mismatch_count = 0
        drift_count = 0
        prev_midi_chord = np.zeros(4, dtype=int)
        cent_value_chord_prev = np.zeros(4, dtype=int)
        final_cent_value_chorale = np.zeros_like(chorale.T)
        final_score = np.zeros(chorale.T.shape[0])
        for inx, initial_midi_chord, initial_cent_value_chord in zip(count(0,1), chorale.T, cent_value_chorale.T):
            chord_num = inx
            if not np.array_equal(prev_midi_chord, initial_midi_chord):
                initial_pitch_class_chord = initial_midi_chord % 12
                initial_pitch_class_chord_compressed, pitch_class_inverse = atu.perturb(initial_pitch_class_chord, spread=0) # just to compress, not spread.
                initial_cent_value_chord_compressed, cent_value_inverse = atu.perturb(initial_cent_value_chord, spread=0)
                logging.info(f'In test harness. {chord_num = }, {initial_pitch_class_chord = }, {initial_cent_value_chord_compressed = }')
                # score the uncompressed chord
                proposed_chord_score = chord_scorer.score_chord(initial_cent_value_chord, tolerance=tolerance)
                # print the current results
                if print_initial:
                    print(f'{inx:>2}: initial chord. pitch class: {atu.format_chord(initial_pitch_class_chord,2)}, note names: {" ".join(keys[note] for note in initial_pitch_class_chord)}, cent_values: {atu.format_chord(initial_cent_value_chord_compressed,4)}, initial score: {proposed_chord_score}')

                # build the chord using build_straw_man_chord out of optimum ratios
                tuned_cent_value_chord_compressed, changed, unchanged = build_straw_man_chord(initial_cent_value_chord_compressed, cent_value_chord_prev, inx, chord_scorer, low_number_ratios, tonal_diamond, tolerance=tolerance, print_values=print_values, rolls=rolls)
                # decompress it
                tuned_cent_value_chord = tuned_cent_value_chord_compressed[cent_value_inverse]
                # print the results
                tuned_pitch_class_chord = atu.pitch_class_from_cents(tuned_cent_value_chord)
                if print_finals:
                    print(f'{inx:>2}:   final chord. pitch class: {atu.format_chord(tuned_pitch_class_chord,2)}, note names: {" ".join(keys[note] for note in tuned_pitch_class_chord)}, cent values: {atu.format_chord(tuned_cent_value_chord,4)}, final_score: {chord_scorer.score_chord(tuned_cent_value_chord, tolerance=tolerance)}, changed: {changed}, unchanged: {unchanged}')

                # ensure you didn't change the pitch class
                if not np.array_equal(initial_pitch_class_chord, tuned_pitch_class_chord):
                    print(f'{inx}: Mismatch. {initial_pitch_class_chord[pitch_class_inverse], tuned_pitch_class_chord[pitch_class_inverse] = }')
                    mismatch_count += 1
                # end of build_straw_man final cent value is in variable: tuned_cent_value_chord

            final_cent_value_chorale[inx] = tuned_cent_value_chord.copy() # store the adjusted or copy of the original chord
            final_score[inx] = chord_scorer.score_chord(tuned_cent_value_chord, tolerance=tolerance)
            prev_midi_chord = initial_midi_chord.copy()
            cent_value_chord_prev = tuned_cent_value_chord.copy()
        if mismatch_count > 0: print(f'{mismatch_count = }')
        if drift_count > 0: print(f'{drift_count = }')
        print(f'{version = }, chords: {final_cent_value_chorale.shape[0]}, {tolerance = }, {rolls = }, {limit_max = }')

        print(
            f"mean: {np.round(np.mean(final_score),1)}, ",
            f"median: {np.median(final_score)}, ",
            f"min: {np.min(final_score)}, ",
            f"max: {np.max(final_score)}, ",
            f"argmax: {np.argmax(final_score)}, ",
            f"deciles: {np.percentile(final_score, np.arange(0, 100, 10))}"
        )
        np.save(os.path.join(numpy_dir, f'{version}-opt'), final_cent_value_chorale.T)  # need to make sure to save as (4, 160)

if __name__ == '__main__':
    main()
