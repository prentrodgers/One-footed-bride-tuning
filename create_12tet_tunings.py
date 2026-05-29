#!/usr/bin/env python3
"""
Create 12-TET (12-tone equal temperament) tuning arrays for all chorales.
Uses MIDI note values from music21 corpus and converts to cent values.
"""
import numpy as np
import os
import sys
from pathlib import Path

# Add the current directory to path to import adaptive_tuning_util
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import adaptive_tuning_util as atu

def create_12tet_from_midi(version, numpy_dir, output_file):
    """
    Create a 12-TET tuning array from MIDI values in the music21 corpus.
    
    Parameters
    ----------
    version : str
        Chorale version (e.g., 'bwv253')
    numpy_dir : str
        Directory containing top-notes files
    output_file : str
        Path to save the 12-TET tuning array
    """
    # Load the chorale with twelve_tet=True to get 12-TET cent values directly
    # Returns: (chorale_in_cents, top_notes, chorale, root, mode, keys)
    chorale_cents, _, _, root, mode, keys = atu.load_chorale_in_cents(
        version, numpy_dir, twelve_tet=True, save_top_notes=False
    )
    
    print(f"Chorale: {version}")
    print(f"  Shape: {chorale_cents.shape}")
    print(f"  12-TET cent values (first chord): {chorale_cents[:, 0]}")
    
    # Save the 12-TET array
    np.save(output_file, chorale_cents)
    print(f"  Saved to: {output_file}")
    print()
    
    return chorale_cents

def main():
    """Generate 12-TET tuning arrays for all chorales."""
    
    # Directories
    output_dir = Path("Archive/12-TET")
    numpy_dir = "Archive/werck"  # Use werck directory for top-notes files
    
    # Create output directory if it doesn't exist
    output_dir.mkdir(parents=True, exist_ok=True)
    print(f"Output directory: {output_dir}")
    print(f"Using top-notes from: {numpy_dir}")
    print()
    
    # Get all chorale names (bwv253-bwv264)
    chorales = [f"bwv{i}" for i in range(253, 265)]
    
    # Process each chorale
    for chorale in chorales:
        # Create output filename
        output_file = output_dir / f"{chorale}-12-TET-cents.npy"
        
        try:
            # Generate 12-TET tuning from MIDI
            create_12tet_from_midi(chorale, numpy_dir, str(output_file))
        except Exception as e:
            print(f"Error processing {chorale}: {e}")
            import traceback
            traceback.print_exc()
            continue
    
    print(f"\nGenerated 12-TET tuning arrays for {len(chorales)} chorales")
    print(f"Files saved in: {output_dir}")

if __name__ == "__main__":
    main()

# Made with Bob
