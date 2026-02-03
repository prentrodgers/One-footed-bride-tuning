import numpy as np
import sys
import matplotlib.pyplot as plt
sys.path.insert(0, '/home/prent/Dropbox/Tutorials/Diamond_Music')
sys.path.insert(0, '/home/prent/Dropbox/Tutorials/TonicNet')
import adaptive_tuning_util as atu
files = ["melody_part_melody_section.npy",
"bass_part_bass_section.npy",
"winds_part_brass_section.npy",
"winds_part_wood_winds.npy",
"winds_part_bowed_strings.npy",
"perc_part_pizz_strings.npy",
"perc_part_perc_guitar.npy",
"perc_part_finger_pianos.npy"]
feature_name = ['instrument #:', 'duration ticks:', 'note length ticks:', 'velocity:', 'cent value:', 'octave:', 'voice time tracker:', 'stereo:', 'left envelope:', 'glide:', 'up sample:', 'right envelope', '2nd glide:', '3rd glide:', 'overall volume:']
    
for filename in files:
    features = np.load(filename)
    print(f'File: {filename} shape: {features.shape}')
    if filename == 'perc_part_finger_pianos.npy':
        for col in np.arange(15):
            print(f'notes_features_15 column {col}: {feature_name[col]}')
            print(f'unique values: {np.unique(features[:,col],return_counts=True)}')
            # if col > 5: break
# melody_part_melody_section.npy
# bass_part_bass_section.npy
# winds_part_brass_section.npy
# winds_part_wood_winds.npy
# winds_part_bowed_strings.npy
# perc_part_pizz_strings.npy
# perc_part_perc_guitar.npy
# perc_part_finger_pianos.npy

# Visualize overall_volume (column 14) for finger pianos
def plot_overall_volume(filename='perc_part_finger_pianos.npy'):
    """Plot column 14 (overall_volume) to visualize volume transitions."""
    features = np.load(filename)
    overall_volume = features[:, 14]
    
    fig, axes = plt.subplots(2, 1, figsize=(14, 8))
    
    # Plot 1: Full view of overall_volume across all notes
    ax1 = axes[0]
    ax1.plot(overall_volume, linewidth=0.5, alpha=0.8)
    ax1.set_xlabel('Note Index')
    ax1.set_ylabel('Overall Volume')
    ax1.set_title(f'{filename}: Overall Volume (column 14) - {len(overall_volume)} notes')
    ax1.grid(True, alpha=0.3)
    
    # Add horizontal lines at common volume levels
    unique_vols = np.unique(overall_volume)
    for vol in unique_vols:
        if vol > 0:  # Skip zero
            ax1.axhline(y=vol, color='red', linestyle='--', alpha=0.2, linewidth=0.5)
    
    # Plot 2: Show volume changes (differences between consecutive notes)
    ax2 = axes[1]
    volume_changes = np.diff(overall_volume)
    change_indices = np.where(volume_changes != 0)[0]
    
    ax2.plot(volume_changes, linewidth=0.5, alpha=0.8, color='orange')
    ax2.scatter(change_indices, volume_changes[change_indices], s=10, c='red', alpha=0.5, label=f'Changes: {len(change_indices)}')
    ax2.set_xlabel('Note Index')
    ax2.set_ylabel('Volume Change (delta)')
    ax2.set_title(f'Volume Transitions: {len(change_indices)} changes out of {len(overall_volume)-1} note pairs ({100*len(change_indices)/(len(overall_volume)-1):.1f}%)')
    ax2.grid(True, alpha=0.3)
    ax2.legend()
    
    plt.tight_layout()
    plt.savefig('overall_volume_analysis.png', dpi=150)
    plt.show()
    
    # Print statistics
    print(f"\n--- Volume Analysis for {filename} ---")
    print(f"Total notes: {len(overall_volume)}")
    print(f"Volume range: {overall_volume.min():.2f} to {overall_volume.max():.2f}")
    print(f"Unique volume levels: {len(unique_vols)}")
    print(f"Volume changes: {len(change_indices)} ({100*len(change_indices)/(len(overall_volume)-1):.1f}% of notes)")
    print(f"Silent notes (vol=0): {np.sum(overall_volume == 0)} ({100*np.sum(overall_volume == 0)/len(overall_volume):.1f}%)")
    print(f"\nUnique volume values: {unique_vols}")


def plot_all_sections_volume():
    """Plot resulting amplitude: ampdb(velocity) * overall_volume / 5 for all instrument sections."""
    fig, axes = plt.subplots(4, 2, figsize=(16, 14))
    axes = axes.flatten()
    
    print("\n" + "="*80)
    print("RESULTING AMPLITUDE ANALYSIS - ALL SECTIONS")
    print("ampdb(velocity) * overall_volume / 5")
    print("="*80)
    
    summary_data = []
    
    for idx, filename in enumerate(files):
        try:
            features = np.load(filename)
            overall_volume = features[:, 14]
            velocity = features[:, 3]
            
            # Calculate resulting amplitude as csound does: ampdb(velocity) * p15 / 5
            # ampdb(x) = 10^(x/20)
            amplitude = (10 ** (velocity / 20)) * overall_volume / 5
            
            ax = axes[idx]
            x = np.arange(len(amplitude))
            
            # Single line/area chart showing resulting amplitude
            ax.fill_between(x, 0, amplitude, alpha=0.7, color='green', label='Amplitude')
            ax.plot(amplitude, linewidth=0.3, alpha=0.8, color='darkgreen')
            
            # Calculate stats
            amp_changes = np.diff(amplitude)
            amp_change_indices = np.where(amp_changes != 0)[0]
            num_amp_changes = len(amp_change_indices)
            pct_amp_changes = 100 * num_amp_changes / (len(amplitude) - 1) if len(amplitude) > 1 else 0
            silent_count = np.sum(amplitude == 0)
            silent_pct = 100 * silent_count / len(amplitude)
            
            # Extract section name from filename, with custom label overrides
            section_name = filename.replace('.npy', '').replace('_part_', ': ').replace('_', ' ')
            # Rename perc_guitar to marimbas (orchestra changed but filename not updated)
            section_name = section_name.replace('perc guitar', 'marimbas')
            
            ax.set_title(f'{section_name}\n{len(amplitude)} notes, Amp chg: {num_amp_changes} ({pct_amp_changes:.1f}%)', fontsize=9)
            ax.set_xlabel('Note Index', fontsize=8)
            ax.set_ylabel('Amplitude', fontsize=8)
            ax.grid(True, alpha=0.3)
            ax.tick_params(axis='both', labelsize=7)
            
            # Store summary
            summary_data.append({
                'section': section_name,
                'notes': len(amplitude),
                'amp_changes': num_amp_changes,
                'pct_amp_changes': pct_amp_changes,
                'silent': silent_count,
                'silent_pct': silent_pct,
                'amp_min': amplitude.min(),
                'amp_max': amplitude.max(),
                'amp_mean': amplitude.mean()
            })
            
        except FileNotFoundError:
            axes[idx].text(0.5, 0.5, f'{filename}\nNot Found', ha='center', va='center', transform=axes[idx].transAxes)
            axes[idx].set_title(filename, fontsize=9)
    
    plt.tight_layout()
    plt.savefig('overall_volume_all_sections.png', dpi=150)
    plt.show()
    
    # Print summary table
    print(f"\n{'Section':<35} {'Notes':>7} {'AmpChg':>7} {'Chg%':>5} {'Silent':>7} {'Sil%':>5} {'Amp Min':>8} {'Amp Max':>8} {'Amp Mean':>8}")
    print("-" * 105)
    for s in summary_data:
        print(f"{s['section']:<35} {s['notes']:>7} {s['amp_changes']:>7} {s['pct_amp_changes']:>4.1f}% {s['silent']:>7} {s['silent_pct']:>4.1f}% {s['amp_min']:>8.1f} {s['amp_max']:>8.1f} {s['amp_mean']:>8.1f}")
    
    # Totals
    total_notes = sum(s['notes'] for s in summary_data)
    total_amp_changes = sum(s['amp_changes'] for s in summary_data)
    total_silent = sum(s['silent'] for s in summary_data)
    print("-" * 105)
    print(f"{'TOTAL':<35} {total_notes:>7} {total_amp_changes:>7} {100*total_amp_changes/total_notes:>4.1f}% {total_silent:>7} {100*total_silent/total_notes:>4.1f}%")


# Run the visualization for all sections
plot_all_sections_volume()