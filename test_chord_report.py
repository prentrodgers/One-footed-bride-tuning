#!/usr/bin/env python3
"""params_for: filename wins, then directory name, then the CLI fallback."""
import chord_report as cr

# Archived collection: parameters in the filename, directory says nothing.
assert cr.params_for('Archive/straw-man/viterbi-tunings-8-24c/'
                     'bwv262_t3_r1.500_lm19-opt.npy', 1, 17) == (3, 19)
# Grid cell: parameters in the directory name.
assert cr.params_for('Archive/straw-man/t2_r1.50_lm19/bwv262-opt.npy', 1, 17) == (2, 19)
# Filename wins over a directory that also encodes them.
assert cr.params_for('Archive/straw-man/t1_r1.25_lm17/'
                     'bwv262_t3_r1.500_lm19-opt.npy', 1, 17) == (3, 19)
# Neither: the CLI values are used unchanged.
assert cr.params_for('/tmp/bwv262-opt.npy', 2, 23) == (2, 23)
print('ok')

assert cr.chorale_for('bwv262-opt.npy') == 'bwv262'
assert cr.chorale_for('Archive/straw-man/x/bwv262_t3_r1.500_lm19-opt.npy') == 'bwv262'
assert cr.chorale_for('bwv264_t3_r1.500_lm17-trans-sa-opt.npy') == 'bwv264'
assert cr.chorale_for('top-notes.npy') is None
print('ok chorale_for')

# The prime histogram: factors of the ratios the listing prints, 2 ignored.
assert cr.odd_prime_factors(24) == [3]          # 24 = 2^3 * 3
assert cr.odd_prime_factors(1) == []
assert cr.odd_prime_factors(19) == [19]
assert cr.odd_prime_factors(45) == [3, 3, 5]
assert cr.split_ratio('13/11') == (13, 11)
assert cr.split_ratio('2') == (2, 1)
assert cr.split_ratio('n/a') is None
assert cr.ratio_primes('13/11') == ([13], [11])
assert cr.ratio_primes('16/15') == ([], [3, 5])
assert cr.is_high('13/11') and cr.is_high('11/8') and cr.is_high('24/17')
assert not cr.is_high('16/15') and not cr.is_high('7/4') and not cr.is_high('1/1')
print('ok prime histogram helpers')
