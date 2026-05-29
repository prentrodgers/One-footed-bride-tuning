#!/usr/bin/env python3
"""
Inspect notes_features arrays to verify tuba octave-0 rescue implementation.
"""
import numpy as np
import sys

def analyze_tuba_notes(filepath):
    """Analyze tuba notes in a features array."""
    print(f"\n{'='*80}")
    print(f"Analyzing: {filepath}")
    print(f"{'='*80}")
    
    # Load the array
    features = np.load(filepath)
    print(f"Array shape: {features.shape}")
    print(f"Columns: note, oct, glis, ups, env, vel, vol, voice, ...")
    
    # Find tuba notes (csound_voice = 27, which is column index 6)
    tuba_mask = features[:, 6] == 27
    tuba_notes = features[tuba_mask]
    
    print(f"\nTotal notes in file: {features.shape[0]}")
    print(f"Tuba notes (voice=27): {tuba_notes.shape[0]}")
    
    if tuba_notes.shape[0] == 0:
        print("NO TUBA NOTES FOUND!")
        return
    
    # Analyze octaves
    octaves = tuba_notes[:, 5]  # Column 5 is octave
    unique_octaves, counts = np.unique(octaves, return_counts=True)
    
    print(f"\nTuba octave distribution:")
    for oct, count in zip(unique_octaves, counts):
        pct = count / len(octaves) * 100
        print(f"  Octave {int(oct)}: {count} notes ({pct:.1f}%)")
    
    # Check for octave-0 notes
    oct0_mask = octaves == 0
    oct0_count = np.sum(oct0_mask)
    print(f"\nOctave-0 tuba notes: {oct0_count} ({oct0_count/len(octaves)*100:.1f}%)")
    
    # Check for octave-1 notes (potential rescues)
    oct1_mask = octaves == 1
    oct1_count = np.sum(oct1_mask)
    print(f"Octave-1 tuba notes: {oct1_count} ({oct1_count/len(octaves)*100:.1f}%)")
    
    # Check for rescue indicators (f307/f308 in glissando column)
    # Column 12 should be glissando ftable
    if features.shape[1] > 12:
        gliss_ftables = tuba_notes[:, 12]
        f307_mask = gliss_ftables == 307
        f308_mask = gliss_ftables == 308
        f307_count = np.sum(f307_mask)
        f308_count = np.sum(f308_mask)
        
        print(f"\nRescue indicators (glissando ftables):")
        print(f"  f307 (1-oct drop): {f307_count} notes")
        print(f"  f308 (2-oct drop): {f308_count} notes")
        print(f"  Total rescued: {f307_count + f308_count} notes")
        
        if oct1_count > 0:
            print(f"\nRescue verification:")
            print(f"  Octave-1 notes with f307: {np.sum((octaves == 1) & f307_mask)}")
            print(f"  Octave-1 notes with f308: {np.sum((octaves == 1) & f308_mask)}")
    
    # Check upsample column (column 10) for rescue indicators
    if features.shape[1] > 10:
        upsample = tuba_notes[:, 10]
        ups_252_mask = upsample == 252  # f307 indicator
        ups_248_mask = upsample == 248  # f308 indicator
        
        print(f"\nUpsample indicators:")
        print(f"  252 (f307): {np.sum(ups_252_mask)} notes")
        print(f"  248 (f308): {np.sum(ups_248_mask)} notes")

if __name__ == "__main__":
    files = [
        "bwv253_features_array.npy"
    ]
    
    for filepath in files:
        try:
            analyze_tuba_notes(filepath)
        except FileNotFoundError:
            print(f"\nERROR: File not found: {filepath}")
        except Exception as e:
            print(f"\nERROR analyzing {filepath}: {e}")
            import traceback
            traceback.print_exc()

# Made with Bob
