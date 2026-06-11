#!/usr/bin/env python3
"""
Test script to demonstrate the enhanced analyze_chorale_spread.py functionality.

This shows how to use the script to generate a well-formatted report with:
- Tolerance
- Ratio-factor
- Average score
- Max score
- Max chord
- MAD Spread (max and mean)
"""

import analyze_chorale_spread as acs

# Example usage with default parameters
print("Example 1: Analyze all chorales with default parameters")
print("=" * 100)

# Assuming you have tuned files in a directory, e.g., 'Archive/straw-man/best-tunings'
# You would call:
# results = acs.analyze_all_chorales(
#     numpy_dir='Archive/straw-man/best-tunings',
#     suffix='-trans-sa-opt.npy',
#     show_details=False,
#     tolerance=1,
#     ratio_factor=1.5,
#     limit_max=19
# )

print("\nExample 2: Analyze with custom parameters")
print("=" * 100)
# results = acs.analyze_all_chorales(
#     numpy_dir='path/to/your/numpy/files',
#     suffix='-trans-sa-opt.npy',
#     show_details=False,
#     tolerance=2,
#     ratio_factor=1.75,
#     limit_max=23
# )

print("\nExample 3: Analyze a single chorale with details")
print("=" * 100)
# result = acs.analyze_chorale_spread(
#     numpy_dir='path/to/your/numpy/files',
#     version='bwv253',
#     suffix='-trans-sa-opt.npy',
#     show_details=True,
#     tolerance=1,
#     ratio_factor=1.5,
#     limit_max=19
# )
# if result:
#     print(f"\nResults for {result['version']}:")
#     print(f"  Tolerance: {result['tolerance']}")
#     print(f"  Ratio factor: {result['ratio_factor']}")
#     print(f"  Average score: {result['avg_score']:.1f}")
#     print(f"  Max score: {result['max_score']:.1f} at chord {result['max_chord']}")
#     print(f"  MAD Spread max: {result['max_mad']:.2f}")
#     print(f"  MAD Spread mean: {result['mean_mad']:.2f}")

print("\nThe enhanced script now displays a formatted table like:")
print("=" * 100)
print("                                                MAD Spread")
print(f"{'version':<12} {'Tol':>5} {'Ratio-factor':>12} {'Average':>8} {'Max score':>10} "
      f"{'Max chord':>10} {'max':>8} {'mean':>8}")
print("-" * 100)
print(f"{'bwv253':<12} {1:>5} {1.5:>12.1f} {49.2:>8.1f} {93.0:>10.1f} {126:>10} {12.50:>8.2f} {8.28:>8.2f}")
print(f"{'bwv254':<12} {1:>5} {1.5:>12.1f} {54.8:>8.1f} {145.0:>10.1f} {158:>10} {15.25:>8.2f} {8.45:>8.2f}")
print(f"{'bwv255':<12} {1:>5} {1.5:>12.1f} {50.8:>8.1f} {82.0:>10.1f} {42:>10} {14.84:>8.2f} {8.69:>8.2f}")
print("..." )
print("=" * 100)

# Made with Bob
