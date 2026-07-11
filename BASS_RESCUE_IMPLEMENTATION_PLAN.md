# Bass Octave Rescue Implementation Plan

## Objective
Reduce bass density by implementing density-aware probabilistic rescue of octave-0 notes, and add variation by using f308 (2-octave drop) 25% of the time.

## Current State (Lines 935-943 in WreckingCrew.py)
```python
# Rescues 100% of octave-0 notes, always uses f307 (1-octave drop)
bfin_oct0 = (notes_features_15[:, 6] == 24) & (notes_features_15[:, 5] == 0)
if np.any(bfin_oct0):
    notes_features_15[bfin_oct0, 5]  = 1    # octave 1
    notes_features_15[bfin_oct0, 10] = 252  # upsample: 4 slots lower
    notes_features_15[bfin_oct0, 12] = 307  # glissando: f307 (0.5x = -1 octave)
```

## Target State

### Rescue Probabilities by Density
- **Sparse sections** (density < 0.3): 75% rescue
- **Medium sections** (0.3 ≤ density ≤ 0.6): 50% rescue  
- **Dense sections** (density > 0.6): 25% rescue

### Ftable Selection
- **f307** (1-octave drop): 75% of rescued notes
- **f308** (2-octave drop): 25% of rescued notes

### Upsample Adjustment for f308
When using f308 (2-octave drop), we need to adjust upsample more:
- f307: upsample = 252 (256 - 4 = 4 slots lower)
- f308: upsample = 248 (256 - 8 = 8 slots lower) — compensate for 2-octave drop

## Implementation Code

```python
def bass_part(chorale, glides, repeats, voice_names, voice_time, tpq, volume_function, 
              probs=None, fp_volume=1, bass_sustain=15,
              bass_hold_scale=1.0, bass_hold_swing=0.75, bass_hold_cycles=4, 
              density_profile: np.ndarray | None = None,
              rescue_probability=0.5,      # NEW: overall rescue probability
              ftable_308_prob=0.25):       # NEW: probability of using f308 vs f307
    
    # ... existing code up to line 934 ...
    
    # Bass finger piano octave-0 rescue with density-aware probability
    bfin_oct0 = (notes_features_15[:, 6] == 24) & (notes_features_15[:, 5] == 0)
    
    if np.any(bfin_oct0):
        oct0_indices = np.where(bfin_oct0)[0]
        num_oct0_notes = len(oct0_indices)
        
        # Calculate density-aware rescue probabilities
        rescue_probs = np.zeros(num_oct0_notes)
        density_window = 50  # Look at ±50 notes for local density
        
        for i, idx in enumerate(oct0_indices):
            # Calculate local density (fraction of sounding notes in window)
            window_start = max(0, idx - density_window)
            window_end = min(len(notes_features_15), idx + density_window)
            local_notes = notes_features_15[window_start:window_end]
            local_density = np.mean(local_notes[:, 5] > 0)
            
            # Density-based rescue probability
            if local_density < 0.3:      # Sparse
                rescue_probs[i] = 0.75
            elif local_density > 0.6:    # Dense
                rescue_probs[i] = 0.25
            else:                        # Medium
                rescue_probs[i] = 0.50
        
        # Apply rescue based on probabilities
        rescue_mask = rng.random(num_oct0_notes) < rescue_probs
        rescue_indices = oct0_indices[rescue_mask]
        num_rescued = len(rescue_indices)
        
        if num_rescued > 0:
            # Set octave to 1 for all rescued notes
            notes_features_15[rescue_indices, 5] = 1
            
            # Randomly choose between f307 (75%) and f308 (25%) for each rescued note
            ftable_choices = rng.random(num_rescued) < ftable_308_prob
            
            # Apply f307 (1-octave drop) to 75% of rescued notes
            f307_indices = rescue_indices[~ftable_choices]
            notes_features_15[f307_indices, 10] = 252  # upsample: 4 slots lower
            notes_features_15[f307_indices, 12] = 307  # glissando: f307 (0.5x)
            
            # Apply f308 (2-octave drop) to 25% of rescued notes
            f308_indices = rescue_indices[ftable_choices]
            notes_features_15[f308_indices, 10] = 248  # upsample: 8 slots lower
            notes_features_15[f308_indices, 12] = 308  # glissando: f308 (0.25x)
            
            # Logging
            num_f307 = len(f307_indices)
            num_f308 = len(f308_indices)
            avg_rescue_prob = rescue_probs[rescue_mask].mean()
            
            logging.info(f'bass_part: octave-0 rescue applied to {num_rescued}/{num_oct0_notes} notes ({num_rescued/num_oct0_notes*100:.1f}%)')
            logging.info(f'  - f307 (1-oct): {num_f307} notes ({num_f307/num_rescued*100:.1f}%)')
            logging.info(f'  - f308 (2-oct): {num_f308} notes ({num_f308/num_rescued*100:.1f}%)')
            logging.info(f'  - avg rescue probability: {avg_rescue_prob:.2f}')
    
    return notes_features_15
```

## Changes to expand_chorale()

No changes needed! The `bass_part()` function already receives `density_profile` parameter (line 1735), so the density-aware logic will work automatically.

## Testing Strategy

1. **Generate test output** with new code
2. **Check logs** for:
   - Total octave-0 notes found
   - Number rescued (should be ~50% overall)
   - Distribution of f307 vs f308 (should be ~75%/25%)
   - Average rescue probability by section
3. **Listen** for:
   - Reduced bass muddiness
   - Appropriate bass presence in sparse sections
   - Tonal variety from f308 (deeper bass notes)

## Expected Results

### Before (100% rescue, all f307)
- All octave-0 notes become sounding notes
- Uniform 1-octave drop
- Potentially muddy bass

### After (density-aware rescue, mixed f307/f308)
- ~75% rescue in sparse sections
- ~50% rescue in medium sections  
- ~25% rescue in dense sections
- 75% use f307 (1-octave drop)
- 25% use f308 (2-octave drop)
- Clearer, more varied bass

## Tuning Parameters

If results need adjustment:

| Parameter | Current | Adjust If... |
|-----------|---------|--------------|
| Sparse threshold (0.3) | 0.3 | Too many/few notes in sparse sections |
| Dense threshold (0.6) | 0.6 | Too many/few notes in dense sections |
| Sparse rescue (0.75) | 0.75 | Sparse sections too empty/full |
| Medium rescue (0.50) | 0.50 | Medium sections too empty/full |
| Dense rescue (0.25) | 0.25 | Dense sections too empty/full |
| ftable_308_prob (0.25) | 0.25 | Want more/less deep bass |
| density_window (50) | 50 | Density detection too local/global |

## Date
2026-05-22