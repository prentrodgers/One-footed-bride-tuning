# Tuba Octave-0 Rescue Implementation

## Summary
Added octave-0 rescue logic to the `woodwinds_part()` function for tuba (csound_voice 27), similar to the bass finger piano rescue but with simpler probability logic.

## Changes Made to WreckingCrew.py

### 1. Updated woodwinds_part() Function Signature (Lines 1248-1250)
Added two new parameters:
```python
def woodwinds_part(chorale_in_cents_slides, glides, repeats, voice_names, voice_time, tpq,
    volume_function, mask=True, prob_silence=None, octave_reduce=0, woodwinds_volume=5, 
    density_profile: np.ndarray | None = None,
    rescue_probability=0.5, ftable_308_prob=0.25):
```

### 2. Added Tuba Octave-0 Rescue Logic (Lines 1347-1385)
Inserted before the return statement:

```python
# Tuba (csound_voice 27) octave-0 rescue with simple 50% probability
# Similar to bass_part rescue but without density-awareness
tuba_oct0 = (notes_features_15[:, 6] == 27) & (notes_features_15[:, 5] == 0)

if np.any(tuba_oct0):
    oct0_indices = np.where(tuba_oct0)[0]
    num_oct0_notes = len(oct0_indices)
    
    # Apply simple 50% rescue probability (not density-aware)
    rescue_mask = rng.random(num_oct0_notes) < rescue_probability
    rescue_indices = oct0_indices[rescue_mask]
    num_rescued = len(rescue_indices)
    
    if num_rescued > 0:
        # Set octave to 1 for all rescued notes
        notes_features_15[rescue_indices, 5] = 1
        
        # Randomly choose between f307 (75%) and f308 (25%)
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
        
        logging.info(f'woodwinds_part (tuba): octave-0 rescue applied to {num_rescued}/{num_oct0_notes} notes ({num_rescued/num_oct0_notes*100:.1f}%)')
        logging.info(f'  - f307 (1-oct): {num_f307} notes ({num_f307/num_rescued*100:.1f}%)')
        logging.info(f'  - f308 (2-oct): {num_f308} notes ({num_f308/num_rescued*100:.1f}%)')
```

## Key Differences from Bass Rescue

| Feature | Bass (bass_part) | Tuba (woodwinds_part) |
|---------|------------------|----------------------|
| **Instrument** | Bass finger piano (csound_voice 24) | Tuba (csound_voice 27) |
| **Rescue Strategy** | Density-aware (75%/50%/25%) | Simple 50% probability |
| **Density Detection** | ±50 note window | Not used |
| **Sparse sections** | 75% rescue | 50% rescue |
| **Medium sections** | 50% rescue | 50% rescue |
| **Dense sections** | 25% rescue | 50% rescue |
| **f307/f308 split** | 75%/25% | 75%/25% |

## Rationale for Simple Probability

Tuba uses **simple 50% probability** instead of density-aware logic because:
1. Tuba is part of the brass section, which already has long-note phrasing
2. The woodwinds_part function already applies density scaling via `prob_silence`
3. Simpler logic is easier to tune and understand
4. 50% provides good balance without over-complicating the code

## Expected Results

### Before (100% octave-0 = silence)
- All tuba octave-0 notes were silent
- Tuba presence determined entirely by octave assignment

### After (50% rescue)
- 50% of octave-0 tuba notes become sounding notes
- 75% dropped 1 octave (f307)
- 25% dropped 2 octaves (f308)
- More consistent tuba presence
- Deeper bass variety from f308

## Testing Checklist

- [ ] Run chorale generation with tuba in brass_section
- [ ] Check logs for tuba rescue statistics
- [ ] Verify ~50% rescue rate
- [ ] Verify ~75%/25% f307/f308 distribution
- [ ] Listen for:
  - Appropriate tuba density
  - Clear low brass presence
  - No muddiness
  - Tonal variety from f308

## Tuning Parameters

If results need adjustment, modify these in function call:

```python
woodwinds_part(..., 
    rescue_probability=0.5,    # Adjust 0.0-1.0 for more/less tuba
    ftable_308_prob=0.25)      # Adjust 0.0-1.0 for more/less deep bass
```

## Related Files
- `ball9.csd` - Contains f307 and f308 ftable definitions
- `BASS_RESCUE_IMPLEMENTATION_PLAN.md` - Bass rescue details
- `BASS_OCTAVE_RESCUE_ALTERNATIVES.md` - Alternative approaches

## Date
2026-05-22

## Status
✅ **IMPLEMENTED** - Ready for testing