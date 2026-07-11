# Probabilistic Alternatives for Bass Octave-0 Rescue

## Current Implementation (Lines 935-943)
The current code converts **ALL** octave=0 bass finger piano notes (csound_voice 24) to octave=1 with glissando #2 (f307, constant 0.5) to drop them back one octave:

```python
bfin_oct0 = (notes_features_15[:, 6] == 24) & (notes_features_15[:, 5] == 0)
if np.any(bfin_oct0):
    notes_features_15[bfin_oct0, 5]  = 1    # octave 1 — passes the silence filter
    notes_features_15[bfin_oct0, 10] = 252  # upsample: 4 slots lower (256-4)
    notes_features_15[bfin_oct0, 12] = 307  # 2nd glissando: f307 constant 0.5 (one octave down)
```

**Problem**: This converts every octave=0 note (which were muted/silent) to sounding notes, potentially creating a muddy, overly dense bass part.

---

## Probabilistic Alternatives

### Option 1: Simple Probability Threshold (Recommended)
Apply the rescue only to a percentage of octave=0 notes:

```python
# Bass finger piano octave-0 rescue with probability control
bfin_oct0 = (notes_features_15[:, 6] == 24) & (notes_features_15[:, 5] == 0)
if np.any(bfin_oct0):
    rescue_probability = 0.3  # Rescue only 30% of octave=0 notes
    
    # Create random mask for which notes to rescue
    num_oct0_notes = np.sum(bfin_oct0)
    rescue_mask = rng.random(num_oct0_notes) < rescue_probability
    
    # Apply rescue only to selected notes
    oct0_indices = np.where(bfin_oct0)[0]
    rescue_indices = oct0_indices[rescue_mask]
    
    notes_features_15[rescue_indices, 5]  = 1    # octave 1
    notes_features_15[rescue_indices, 10] = 252  # upsample
    notes_features_15[rescue_indices, 12] = 307  # glissando f307
    
    logging.info(f'bass_part: octave-0 rescue applied to {len(rescue_indices)}/{num_oct0_notes} bfin notes ({rescue_probability*100:.0f}%)')
```

**Pros**: Simple, predictable density control
**Cons**: Uniform probability across all notes

---

### Option 2: Density-Aware Probability
Vary rescue probability based on local note density:

```python
# Bass finger piano octave-0 rescue with density-aware probability
bfin_oct0 = (notes_features_15[:, 6] == 24) & (notes_features_15[:, 5] == 0)
if np.any(bfin_oct0):
    base_rescue_prob = 0.4  # Base probability
    density_window = 50     # Look at ±50 notes for density
    
    oct0_indices = np.where(bfin_oct0)[0]
    rescue_mask = np.zeros(len(oct0_indices), dtype=bool)
    
    for i, idx in enumerate(oct0_indices):
        # Calculate local density (non-zero octaves in window)
        window_start = max(0, idx - density_window)
        window_end = min(len(notes_features_15), idx + density_window)
        local_notes = notes_features_15[window_start:window_end]
        local_density = np.mean(local_notes[:, 5] > 0)  # Fraction of sounding notes
        
        # Lower probability in dense areas, higher in sparse areas
        adjusted_prob = base_rescue_prob * (1.5 - local_density)
        adjusted_prob = np.clip(adjusted_prob, 0.1, 0.8)
        
        rescue_mask[i] = rng.random() < adjusted_prob
    
    rescue_indices = oct0_indices[rescue_mask]
    notes_features_15[rescue_indices, 5]  = 1
    notes_features_15[rescue_indices, 10] = 252
    notes_features_15[rescue_indices, 12] = 307
    
    logging.info(f'bass_part: density-aware rescue applied to {len(rescue_indices)}/{len(oct0_indices)} bfin notes')
```

**Pros**: Prevents muddiness in already-dense sections
**Cons**: More complex, requires tuning

---

### Option 3: Temporal Pattern-Based
Rescue notes based on their position in musical phrases:

```python
# Bass finger piano octave-0 rescue with temporal patterns
bfin_oct0 = (notes_features_15[:, 6] == 24) & (notes_features_15[:, 5] == 0)
if np.any(bfin_oct0):
    oct0_indices = np.where(bfin_oct0)[0]
    rescue_mask = np.zeros(len(oct0_indices), dtype=bool)
    
    # Rescue more notes at phrase boundaries (every N notes)
    phrase_length = 64  # Adjust based on your musical structure
    
    for i, idx in enumerate(oct0_indices):
        position_in_phrase = idx % phrase_length
        
        # Higher probability at phrase start/end, lower in middle
        if position_in_phrase < phrase_length * 0.2:  # First 20%
            prob = 0.6
        elif position_in_phrase > phrase_length * 0.8:  # Last 20%
            prob = 0.5
        else:  # Middle 60%
            prob = 0.2
        
        rescue_mask[i] = rng.random() < prob
    
    rescue_indices = oct0_indices[rescue_mask]
    notes_features_15[rescue_indices, 5]  = 1
    notes_features_15[rescue_indices, 10] = 252
    notes_features_15[rescue_indices, 12] = 307
    
    logging.info(f'bass_part: temporal pattern rescue applied to {len(rescue_indices)}/{len(oct0_indices)} bfin notes')
```

**Pros**: Creates musical phrasing, emphasizes structural boundaries
**Cons**: Requires knowledge of phrase structure

---

### Option 4: Velocity-Weighted Probability
Rescue notes based on their velocity (louder notes more likely):

```python
# Bass finger piano octave-0 rescue weighted by velocity
bfin_oct0 = (notes_features_15[:, 6] == 24) & (notes_features_15[:, 5] == 0)
if np.any(bfin_oct0):
    oct0_indices = np.where(bfin_oct0)[0]
    velocities = notes_features_15[oct0_indices, 11]  # Column 11 is velocity
    
    # Normalize velocities to 0-1 range
    vel_min, vel_max = velocities.min(), velocities.max()
    if vel_max > vel_min:
        norm_velocities = (velocities - vel_min) / (vel_max - vel_min)
    else:
        norm_velocities = np.ones_like(velocities) * 0.5
    
    # Scale to probability range (e.g., 0.1 to 0.7)
    rescue_probs = 0.1 + norm_velocities * 0.6
    rescue_mask = rng.random(len(oct0_indices)) < rescue_probs
    
    rescue_indices = oct0_indices[rescue_mask]
    notes_features_15[rescue_indices, 5]  = 1
    notes_features_15[rescue_indices, 10] = 252
    notes_features_15[rescue_indices, 12] = 307
    
    logging.info(f'bass_part: velocity-weighted rescue applied to {len(rescue_indices)}/{len(oct0_indices)} bfin notes')
```

**Pros**: Emphasizes important notes, natural musical dynamics
**Cons**: May not reduce density if many notes are loud

---

### Option 5: Hybrid Approach (Most Flexible)
Combine multiple factors with configurable weights:

```python
# Bass finger piano octave-0 rescue with hybrid probability
bfin_oct0 = (notes_features_15[:, 6] == 24) & (notes_features_15[:, 5] == 0)
if np.any(bfin_oct0):
    base_prob = 0.35
    density_weight = 0.3
    velocity_weight = 0.2
    temporal_weight = 0.15
    random_weight = 0.35
    
    oct0_indices = np.where(bfin_oct0)[0]
    rescue_probs = np.zeros(len(oct0_indices))
    
    for i, idx in enumerate(oct0_indices):
        # Factor 1: Local density (inverse)
        window = 50
        local_density = np.mean(notes_features_15[max(0,idx-window):min(len(notes_features_15),idx+window), 5] > 0)
        density_factor = (1 - local_density) * density_weight
        
        # Factor 2: Velocity
        velocity = notes_features_15[idx, 11]
        vel_factor = (velocity / 127.0) * velocity_weight  # Assuming velocity 0-127
        
        # Factor 3: Temporal position
        phrase_pos = (idx % 64) / 64.0
        temporal_factor = (0.5 + 0.5 * np.sin(phrase_pos * 2 * np.pi)) * temporal_weight
        
        # Factor 4: Random component
        random_factor = rng.random() * random_weight
        
        # Combine factors
        rescue_probs[i] = base_prob + density_factor + vel_factor + temporal_factor + random_factor
    
    rescue_probs = np.clip(rescue_probs, 0.05, 0.85)
    rescue_mask = rng.random(len(oct0_indices)) < rescue_probs
    
    rescue_indices = oct0_indices[rescue_mask]
    notes_features_15[rescue_indices, 5]  = 1
    notes_features_15[rescue_indices, 10] = 252
    notes_features_15[rescue_indices, 12] = 307
    
    logging.info(f'bass_part: hybrid rescue applied to {len(rescue_indices)}/{len(oct0_indices)} bfin notes (avg prob: {rescue_probs.mean():.2f})')
```

**Pros**: Maximum control, musically intelligent
**Cons**: Most complex, requires parameter tuning

---

## Recommended Starting Point

**Option 1 (Simple Probability)** with `rescue_probability = 0.3` to 0.4 is recommended for initial testing:
- Easy to understand and adjust
- Predictable results
- Can be tuned by ear after listening

Start conservative (0.2-0.3) and increase if bass is too sparse.

---

## Parameter Suggestions by Musical Context

| Context | Rescue Probability | Notes |
|---------|-------------------|-------|
| Sparse arrangement | 0.5 - 0.7 | More bass presence needed |
| Dense arrangement | 0.2 - 0.3 | Avoid muddiness |
| Rhythmic focus | 0.4 - 0.5 | Moderate density |
| Ambient/atmospheric | 0.1 - 0.2 | Minimal bass |

---

## Implementation Notes

1. Add `rescue_probability` parameter to `bass_part()` function signature
2. Pass it through from `expand_chorale()` 
3. Consider making it section-specific (different values for different parts)
4. Log the actual rescue count for tuning feedback

## Testing Strategy

1. Generate with current (100% rescue) - baseline
2. Generate with 30% rescue - compare density
3. Generate with 50% rescue - find sweet spot
4. Listen and adjust based on musical context

---

**Date**: 2026-05-21
**Status**: Awaiting implementation after field testing