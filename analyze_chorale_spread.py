#!/usr/bin/env python3
"""
Analyze spread (MAD - Mean Absolute Deviation) for tuned chorales.

This script calculates the spread using circular_mad() which computes the 
Mean Absolute Deviation from the circular mean for each pitch class.
This is the same calculation used in select_best_and_render.py.

The spread metric uses the MAXIMUM MAD across all pitch classes (worst offender),
as one unstable pitch class is enough to make a chorale sound wrong.

Usage in Chorale-info.ipynb:
    import analyze_chorale_spread as acs
    acs.analyze_all_chorales(local_numpy_dir, suffix='-trans-sa-opt.npy')
"""

import os
import numpy as np
from collections import Counter, defaultdict
import adaptive_tuning_util as atu


def compute_spread_score(cent_value_chorale, chorale):
    """
    Compute spread score using circular MAD (Mean Absolute Deviation).

    Returns the MAXIMUM circular MAD across all pitch classes — the single most
    inconsistently-tuned note name in the piece. One unstable pitch class is
    enough to make a chorale sound wrong, so the worst offender drives the score
    rather than an average that lets bad notes hide in the crowd.

    This is the same calculation used in select_best_and_render.py.
    """
    pitch_class_counts = Counter((chorale % 12).flatten().tolist())
    pc_cents = defaultdict(list)
    
    for chord_cents in cent_value_chorale.T:  # iterate over N chords
        pcs = atu.pitch_class_from_cents(chord_cents)
        for pc, cv in zip(pcs, chord_cents):
            pc_cents[int(pc)].append(float(cv))
    
    max_mad = 0.0
    for pc in pitch_class_counts:
        cvs = pc_cents.get(pc, [])
        if len(cvs) < 2:
            continue
        max_mad = max(max_mad, atu.circular_mad(cvs))
    
    return max_mad


def analyze_chorale_spread(numpy_dir, version, suffix, show_details=True,
                          *, tolerance, ratio_factor=1.5, limit_max=19):
    """Analyze the spread (MAD) for each pitch class in a tuned chorale."""
    input_file = os.path.join(numpy_dir, f'{version}{suffix}')
    try:
        cent_value_chorale = np.load(input_file)
    except Exception as e:
        print(f'Could not load {input_file}: {e}')
        return None
    
    try:
        # twelve_tet=True bypasses top_notes lookup; we only need chorale/root/mode/keys
        _, _, chorale, root, mode, keys = atu.load_chorale_in_cents(
            version, numpy_dir, twelve_tet=True, save_top_notes=False)
    except Exception as e:
        print(f'Could not load chorale {version}: {e}')
        return None
    
    # Build tonal diamond and chord scorer for scoring
    tonal_diamond = atu.build_tonal_diamond(limit_max)
    chord_scorer = atu.ChordScorer(tonal_diamond)
    
    # Calculate scores for all chords
    scores = np.array([
        chord_scorer.score_chord(cent_value_chorale[:, i], tolerance=tolerance)
        for i in range(cent_value_chorale.shape[1])
    ])
    
    avg_score = float(np.mean(scores))
    max_score = float(np.max(scores))
    max_chord = int(np.argmax(scores))
    
    # Get pitch class counts (needed for MAD calculation)
    pitch_class_counts = Counter((chorale % 12).flatten())
    
    if show_details:
        print(f'\n{input_file}')
        print(f'Original chorale key: {keys[root]} {mode}')
        print('Pitch classes sorted by frequency in original chorale:')
        for note, freq in pitch_class_counts.most_common(5):
            print(f'{keys[note]}: {freq}', end='\t')
        print()
    
    # Compute per-pitch-class MAD values
    pc_cents = defaultdict(list)
    for chord_cents in cent_value_chorale.T:
        pcs = atu.pitch_class_from_cents(chord_cents)
        for pc, cv in zip(pcs, chord_cents):
            pc_cents[int(pc)].append(float(cv))
    
    if show_details:
        print(f'\n{"Note":<5} {"Occurs":>7}  {"MAD":>8}  {"Mean":>8}  Unique cent values (rounded)')
        print('-' * 90)
    
    max_mad = 0.0
    mad_values = []
    
    for note, occurrences in pitch_class_counts.most_common():
        cvs_raw = pc_cents.get(note, [])
        if not cvs_raw:
            continue
        
        mad = atu.circular_mad(cvs_raw)
        mad_values.append(mad)
        max_mad = max(max_mad, mad)
        
        if show_details:
            cvs = sorted(set(round(v) for v in cvs_raw))
            mean_cv = np.mean(cvs_raw)
            flag = ' <-- MAX' if mad == max_mad and mad > 0 else ''
            print(f'{keys[note]:<5} {occurrences:>7}  {mad:>8.2f}  {mean_cv:>8.1f}  {cvs}{flag}')
    
    mean_mad = np.mean(mad_values) if mad_values else 0.0
    
    if show_details:
        print(f'\nSpread (max MAD): {max_mad:.2f} cents')
        print(f'Mean MAD across all pitch classes: {mean_mad:.2f} cents')
        print(f'Average score: {avg_score:.1f}')
        print(f'Max score: {max_score:.1f} at chord {max_chord}')
    
    return {
        'version': version,
        'tolerance': tolerance,
        'ratio_factor': ratio_factor,
        'avg_score': avg_score,
        'max_score': max_score,
        'max_chord': max_chord,
        'max_mad': max_mad,
        'mean_mad': mean_mad
    }


def analyze_all_chorales(numpy_dir, suffix='-trans-sa-opt.npy', show_details=False,
                         *, tolerance, ratio_factor=1.5, limit_max=19):
    """Analyze spread (MAD) for all chorales (bwv253-264) and display formatted report."""
    print("\n" + "="*100)
    print("CHORALE ANALYSIS - MAD Spread and Scores")
    print("="*100)
    
    results = []
    for version in ['bwv253', 'bwv254', 'bwv255', 'bwv256', 'bwv257', 'bwv258',
                    'bwv259', 'bwv260', 'bwv261', 'bwv262', 'bwv263', 'bwv264']:
        result = analyze_chorale_spread(numpy_dir, version, suffix=suffix,
                                       show_details=show_details,
                                       tolerance=tolerance,
                                       ratio_factor=ratio_factor,
                                       limit_max=limit_max)
        if result is not None:
            results.append(result)
    
    if results:
        # Print formatted table
        print("\n" + "="*100)
        print("                                                MAD Spread")
        print(f"{'version':<12} {'Tol':>5} {'Ratio-factor':>12} {'Average':>8} {'Max score':>10} "
              f"{'Max chord':>10} {'max':>8} {'mean':>8}")
        print("-" * 100)
        
        for r in results:
            print(f"{r['version']:<12} {r['tolerance']:>5} {r['ratio_factor']:>12.1f} "
                  f"{r['avg_score']:>8.1f} {r['max_score']:>10.1f} {r['max_chord']:>10} "
                  f"{r['max_mad']:>8.2f} {r['mean_mad']:>8.2f}")
        
        # Calculate and print summary statistics
        avg_scores = [r['avg_score'] for r in results]
        max_mads = [r['max_mad'] for r in results]
        mean_mads = [r['mean_mad'] for r in results]
        
        print("-" * 100)
        print(f"{'MEAN':<12} {'':<5} {'':<12} "
              f"{np.mean(avg_scores):>8.1f} {'':<10} {'':<10} "
              f"{np.mean(max_mads):>8.2f} {np.mean(mean_mads):>8.2f}")
        print("="*100)
    
    return results


if __name__ == '__main__':
    import argparse
    
    parser = argparse.ArgumentParser(
        description='Analyze spread (MAD) per pitch class in tuned chorales')
    parser.add_argument('--numpy_dir', type=str, required=True,
                        help='Directory containing the tuned numpy files')
    parser.add_argument('--chorale_list', type=str, nargs='+',
                        default=['bwv253', 'bwv254', 'bwv255', 'bwv256', 'bwv257', 'bwv258',
                                'bwv259', 'bwv260', 'bwv261', 'bwv262', 'bwv263', 'bwv264'],
                        help='Chorale versions to analyze')
    parser.add_argument('--suffix', type=str, default='-trans-sa-opt.npy',
                        help='File suffix to analyze (default: -trans-sa-opt.npy)')
    parser.add_argument('--show_details', action='store_true',
                        help='Show per-pitch-class MAD values for each chorale')
    parser.add_argument('--tolerance', type=int, default=None,
                        help='Tolerance value used for tuning. Required (e.g. --tolerance 3).')
    parser.add_argument('--ratio_factor', type=float, default=1.5,
                        help='Ratio factor used for tuning (default: 1.5)')
    parser.add_argument('--limit_max', type=int, default=19,
                        help='Maximum limit for tonal diamond (default: 19)')
    args = parser.parse_args()
    if args.tolerance is None:
        parser.error('--tolerance is required (e.g. --tolerance 3)')

    base_dir = os.path.dirname(os.path.abspath(__file__))
    numpy_dir = args.numpy_dir if os.path.isabs(args.numpy_dir) else os.path.join(base_dir, args.numpy_dir)
    
    all_results = []
    for version in args.chorale_list:
        result = analyze_chorale_spread(numpy_dir, version, args.suffix, args.show_details,
                                       tolerance=args.tolerance,
                                       ratio_factor=args.ratio_factor,
                                       limit_max=args.limit_max)
        if result is not None:
            all_results.append(result)
    
    if all_results:
        # Print formatted table
        print("\n" + "="*100)
        print("                                                MAD Spread")
        print(f"{'version':<12} {'Tol':>5} {'Ratio-factor':>12} {'Average':>8} {'Max score':>10} "
              f"{'Max chord':>10} {'max':>8} {'mean':>8}")
        print("-" * 100)
        
        for r in all_results:
            print(f"{r['version']:<12} {r['tolerance']:>5} {r['ratio_factor']:>12.1f} "
                  f"{r['avg_score']:>8.1f} {r['max_score']:>10.1f} {r['max_chord']:>10} "
                  f"{r['max_mad']:>8.2f} {r['mean_mad']:>8.2f}")
        
        # Calculate and print summary statistics
        avg_scores = [r['avg_score'] for r in all_results]
        max_mads = [r['max_mad'] for r in all_results]
        mean_mads = [r['mean_mad'] for r in all_results]
        
        print("-" * 100)
        print(f"{'MEAN':<12} {'':<5} {'':<12} "
              f"{np.mean(avg_scores):>8.1f} {'':<10} {'':<10} "
              f"{np.mean(max_mads):>8.2f} {np.mean(mean_mads):>8.2f}")
        print("="*100)

# Made with Bob
