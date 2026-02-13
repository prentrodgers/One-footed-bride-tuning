#!/usr/bin/env python3
"""
Generate presentation-ready charts for One-Footed Bride Tuning
Optimized for 16:9 aspect ratio (1920x1080)
"""

import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch
import numpy as np

# Set consistent style
plt.rcParams['figure.figsize'] = (19.2, 10.8)  # 16:9 at 100 DPI = 1920x1080
plt.rcParams['figure.dpi'] = 100
plt.rcParams['font.size'] = 12
plt.rcParams['font.family'] = 'sans-serif'

def create_chart_1_tuning_systems():
    """Chart 1: Technology of Tuning - Comparison"""
    fig, ax = plt.subplots(figsize=(19.2, 10.8))
    ax.set_xlim(0, 10)
    ax.set_ylim(0, 10)
    ax.axis('off')
    
    # Title
    ax.text(5, 9.5, 'Technology of Tuning: 12-TET vs Just Intonation', 
            ha='center', va='top', fontsize=24, weight='bold')
    
    # Left side: 12-TET
    et_box = FancyBboxPatch((0.5, 5), 4, 3.5, boxstyle="round,pad=0.1", 
                            edgecolor='black', facecolor='white', linewidth=2)
    ax.add_patch(et_box)
    ax.text(2.5, 8, '12-Tone Equal Temperament', ha='center', fontsize=16, weight='bold')
    ax.text(2.5, 7.3, '(12-TET)', ha='center', fontsize=12, style='italic')
    
    et_text = [
        '• All semitones = 100 cents',
        '• Octave = 1200 cents',
        '• Intervals slightly impure',
        '• Can modulate freely',
        '• Universal in modern music',
        '• Mathematically equal'
    ]
    for i, line in enumerate(et_text):
        ax.text(2.5, 6.5 - i*0.35, line, ha='center', fontsize=11)
    
    # Right side: Just Intonation
    ji_box = FancyBboxPatch((5.5, 5), 4, 3.5, boxstyle="round,pad=0.1", 
                            edgecolor='black', facecolor='white', linewidth=2)
    ax.add_patch(ji_box)
    ax.text(7.5, 8, 'Just Intonation', ha='center', fontsize=16, weight='bold')
    ax.text(7.5, 7.3, '(Rational Intervals)', ha='center', fontsize=12, style='italic')
    
    ji_text = [
        '• Intervals from small ratios',
        '• 3:2 = Perfect Fifth (702¢)',
        '• 5:4 = Major Third (386¢)',
        '• Pure harmonics',
        '• Varies by key',
        '• Natural acoustics'
    ]
    for i, line in enumerate(ji_text):
        ax.text(7.5, 6.5 - i*0.35, line, ha='center', fontsize=11)
    
    # Bottom: Tonality Diamond
    diamond_box = FancyBboxPatch((1.5, 1.5), 7, 2.5, boxstyle="round,pad=0.1", 
                                 edgecolor='black', facecolor='lightgray', linewidth=3)
    ax.add_patch(diamond_box)
    ax.text(5, 3.5, "Harry Partch's Tonality Diamond", ha='center', fontsize=18, weight='bold')
    
    diamond_text = [
        'Limit determines ratios:  19-limit (66 intervals)  •  31-limit (214 intervals)  •  47-limit (506 intervals)',
        'Score = numerator + denominator  •  Lower score = more consonant  •  Example: 3:2 scores 5'
    ]
    for i, line in enumerate(diamond_text):
        ax.text(5, 2.8 - i*0.4, line, ha='center', fontsize=11)
    
    # Project approach
    approach_text = 'Project Approach: MIDI (12-TET) → Build Diamond → Optimize with SA → Find Low Ratios → Csound'
    ax.text(5, 0.8, approach_text, ha='center', fontsize=13, 
            bbox=dict(boxstyle='round', facecolor='white', edgecolor='black', linewidth=2))
    
    plt.tight_layout()
    return fig

def create_chart_2_partch_diamond():
    """Chart 2: Harry Partch's Tonality Diamond Structure"""
    fig, ax = plt.subplots(figsize=(19.2, 10.8))
    ax.set_xlim(0, 10)
    ax.set_ylim(0, 10)
    ax.axis('off')
    
    # Title
    ax.text(5, 9.5, "Harry Partch's Tonality Diamond Structure", 
            ha='center', va='top', fontsize=24, weight='bold')
    
    # Top: Construction Process
    steps = ['Define Prime\nLimit', 'Generate All\nRatios', 'Remove\nDuplicates', 
             'Convert to\nCents', 'Calculate\nScores']
    x_positions = np.linspace(1, 9, len(steps))
    
    for i, (x, step) in enumerate(zip(x_positions, steps)):
        circle = plt.Circle((x, 8), 0.4, color='white', ec='black', linewidth=2)
        ax.add_patch(circle)
        ax.text(x, 8, step, ha='center', va='center', fontsize=10)
        
        if i < len(steps) - 1:
            arrow = FancyArrowPatch((x + 0.4, 8), (x_positions[i+1] - 0.4, 8),
                                   arrowstyle='->', lw=2, color='black')
            ax.add_patch(arrow)
    
    # Middle: Otonality and Utonality
    ot_box = FancyBboxPatch((0.5, 4.5), 4, 2.5, boxstyle="round,pad=0.1",
                            edgecolor='black', facecolor='white', linewidth=2)
    ax.add_patch(ot_box)
    ax.text(2.5, 6.5, 'Otonality (Overtone)', ha='center', fontsize=14, weight='bold')
    ax.text(2.5, 6, '1/1, 3/1, 5/1, 7/1, 9/1...', ha='center', fontsize=11)
    ax.text(2.5, 5.5, 'Natural harmonic series', ha='center', fontsize=10, style='italic')
    ax.text(2.5, 5, 'Multiply: 1×n', ha='center', fontsize=10)
    
    ut_box = FancyBboxPatch((5.5, 4.5), 4, 2.5, boxstyle="round,pad=0.1",
                            edgecolor='black', facecolor='white', linewidth=2)
    ax.add_patch(ut_box)
    ax.text(7.5, 6.5, 'Utonality (Undertone)', ha='center', fontsize=14, weight='bold')
    ax.text(7.5, 6, '1/1, 1/3, 1/5, 1/7, 1/9...', ha='center', fontsize=11)
    ax.text(7.5, 5.5, 'Inverted harmonic series', ha='center', fontsize=10, style='italic')
    ax.text(7.5, 5, 'Divide: 1/n', ha='center', fontsize=10)
    
    # Cross product arrow
    ax.annotate('', xy=(7.5, 4.3), xytext=(2.5, 4.3),
                arrowprops=dict(arrowstyle='<->', lw=3, color='black'))
    ax.text(5, 4, 'Cross Product', ha='center', fontsize=11, weight='bold')
    
    # Example ratios
    example_box = FancyBboxPatch((1, 1.5), 8, 2, boxstyle="round,pad=0.1",
                                 edgecolor='black', facecolor='lightgray', linewidth=2)
    ax.add_patch(example_box)
    ax.text(5, 3, 'Example: 11-Limit Diamond Ratios', ha='center', fontsize=16, weight='bold')
    
    ratios = [
        '3/2 (702¢) - Perfect 5th  •  5/4 (386¢) - Major 3rd',
        '7/4 (969¢) - Harmonic 7th  •  11/8 (551¢) - Neutral 4th',
        'Total: ~36 unique ratios'
    ]
    for i, ratio in enumerate(ratios):
        ax.text(5, 2.4 - i*0.3, ratio, ha='center', fontsize=11)
    
    # Implementation note
    ax.text(5, 0.5, 'Implementation: build_tonal_diamond() in adaptive_tuning_util.py',
            ha='center', fontsize=12, style='italic',
            bbox=dict(boxstyle='round', facecolor='white', edgecolor='black'))
    
    plt.tight_layout()
    return fig

def create_chart_3_simulated_annealing():
    """Chart 3: Simulated Annealing Algorithm"""
    fig, ax = plt.subplots(figsize=(19.2, 10.8))
    ax.set_xlim(0, 10)
    ax.set_ylim(0, 10)
    ax.axis('off')
    
    # Title
    ax.text(5, 9.5, 'Simulated Annealing: Chord Optimization', 
            ha='center', va='top', fontsize=24, weight='bold')
    
    # Vertical flow
    y_pos = 8.5
    step_height = 1.0
    
    steps = [
        ('START', 'Input: 4-note chord\n(12-TET cents)', 'black'),
        ('INIT', 'Temperature = 2.5\nCooling = 0.999\nTolerance = 1¢', 'white'),
        ('LOOP', 'While temp > 0.05:', 'white'),
        ('NEW', 'Generate new solution\nfrom tonality diamond', 'white'),
        ('TEMP?', 'Temperature\nhigh or low?', 'white'),
        ('SCORE', 'Score new solution\nSum of interval scores', 'white'),
        ('ACCEPT?', 'Better score OR\nSA probability?', 'white'),
        ('COOL', 'Decrease temperature\ntemp *= 0.999', 'white'),
        ('OUTPUT', 'Output: Optimized\nchord in cents', 'black'),
    ]
    
    x_center = 3
    for i, (label, text, fill) in enumerate(steps):
        if fill == 'black':
            box_color = 'black'
            text_color = 'white'
        else:
            box_color = 'white'
            text_color = 'black'
            
        if 'TEMP?' in label or 'ACCEPT?' in label:
            # Diamond shape for decisions
            diamond = mpatches.FancyBboxPatch((x_center - 0.6, y_pos - 0.4), 1.2, 0.7,
                                             boxstyle="round,pad=0.05",
                                             edgecolor='black', facecolor=box_color, linewidth=2)
            ax.add_patch(diamond)
        else:
            # Rectangle for processes
            box = FancyBboxPatch((x_center - 0.8, y_pos - 0.4), 1.6, 0.7,
                                boxstyle="round,pad=0.05",
                                edgecolor='black', facecolor=box_color, linewidth=2)
            ax.add_patch(box)
        
        ax.text(x_center, y_pos, text, ha='center', va='center', 
                fontsize=9, color=text_color, weight='bold' if fill == 'black' else 'normal')
        
        # Arrow to next step
        if i < len(steps) - 1:
            arrow = FancyArrowPatch((x_center, y_pos - 0.45), (x_center, y_pos - 0.95),
                                   arrowstyle='->', lw=2, color='black')
            ax.add_patch(arrow)
        
        y_pos -= step_height
    
    # Side panel: Key Concepts
    concept_box = FancyBboxPatch((5.5, 4), 4, 4.5, boxstyle="round,pad=0.1",
                                 edgecolor='black', facecolor='lightgray', linewidth=2)
    ax.add_patch(concept_box)
    ax.text(7.5, 8.2, 'Key Concepts', ha='center', fontsize=16, weight='bold')
    
    concepts = [
        'Simulated Annealing:',
        'Probabilistic optimization inspired',
        'by metallurgy (cooling metal)',
        '',
        'Temperature Schedule:',
        'High temp → explore widely',
        'Low temp → refine solution',
        '',
        '4-Note Chord:',
        '6 interval pairs to optimize',
        'Combinations: C(4,2) = 6',
        '',
        'Scoring:',
        'Lower score = more consonant',
        'Sum of all interval limit scores'
    ]
    
    y = 7.5
    for concept in concepts:
        if concept.endswith(':'):
            ax.text(7.5, y, concept, ha='center', fontsize=11, weight='bold')
        elif concept:
            ax.text(7.5, y, concept, ha='center', fontsize=9)
        y -= 0.28
    
    plt.tight_layout()
    return fig

def create_chart_4_bach_pipeline():
    """Chart 4: Bach Chorale Processing Pipeline"""
    fig, ax = plt.subplots(figsize=(19.2, 10.8))
    ax.set_xlim(0, 10)
    ax.set_ylim(0, 10)
    ax.axis('off')
    
    # Title
    ax.text(5, 9.5, 'Bach Chorale Tuning Pipeline', 
            ha='center', va='top', fontsize=24, weight='bold')
    
    # Vertical pipeline
    stages = [
        ('INPUT', 'Bach Chorale MIDI\nBWV 253-264', 'black', 'white'),
        ('ANALYZE', 'music21: Extract root, mode\ntime signature, 4 voices', 'white', 'black'),
        ('CONVERT', 'Convert to array\n(4 voices × n chords)', 'white', 'black'),
        ('DIAMOND', 'Build tonality diamond\nlimit = 19, 31, or 47', 'white', 'black'),
        ('OPTIMIZE', 'Simulated Annealing\nRoll & tune each chord', 'lightgray', 'black'),
        ('CACHE', 'Caching: ~80% hit rate\nMany repeated chords', 'white', 'black'),
        ('CONTINUITY', 'Enforce smooth transitions\nAdd glissandi if needed', 'white', 'black'),
        ('OUTPUT', 'Tuned chorale\nReady for Csound', 'black', 'white'),
    ]
    
    y = 8.5
    for label, text, bg, fg in stages:
        box = FancyBboxPatch((2, y - 0.4), 6, 0.7, boxstyle="round,pad=0.05",
                            edgecolor='black', facecolor=bg, linewidth=2)
        ax.add_patch(box)
        ax.text(5, y, text, ha='center', va='center', fontsize=11, color=fg, weight='bold')
        
        if y > 1.5:
            arrow = FancyArrowPatch((5, y - 0.45), (5, y - 0.95),
                                   arrowstyle='->', lw=2, color='black')
            ax.add_patch(arrow)
        
        y -= 1.0
    
    # Side notes
    note_y = 6.5
    notes = [
        'BWV 253-264:',
        'Wedding chorales',
        'Four-part harmony',
        'Rich harmonic content',
        '',
        'Multi-roll strategy:',
        'Try 5-8 rotations',
        'Escape local minima',
        'Select best result'
    ]
    
    for note in notes:
        if note.endswith(':'):
            ax.text(0.5, note_y, note, ha='left', fontsize=10, weight='bold')
        elif note:
            ax.text(0.7, note_y, '• ' + note, ha='left', fontsize=9)
        note_y -= 0.35
    
    plt.tight_layout()
    return fig

def create_chart_5_csound_synthesis():
    """Chart 5: Csound Synthesis Pipeline"""
    fig, ax = plt.subplots(figsize=(19.2, 10.8))
    ax.set_xlim(0, 10)
    ax.set_ylim(0, 10)
    ax.axis('off')
    
    # Title
    ax.text(5, 9.5, 'Csound Sample-Based Synthesis Pipeline', 
            ha='center', va='top', fontsize=24, weight='bold')
    
    # Main flow (left side)
    x = 2.5
    stages = [
        ('Tuned Chorale\n(Cents Array)', 'black', 'white'),
        ('Build Note Features:\nonset, duration, octave,\ncents, volume, velocity', 'white', 'black'),
        ('Assign to Instruments:\ncelesta, marimba, harp,\nxylophone, vibraphone', 'white', 'black'),
        ('Detect Glissandi:\nSmooth cent transitions', 'lightgray', 'black'),
        ('Generate Csound Score:\ni-statements with\nprecise cent values', 'white', 'black'),
        ('Render Audio:\ncsound output.csd', 'white', 'black'),
        ('Audio File\n(24-bit WAV)', 'black', 'white'),
    ]
    
    y = 8.5
    step_height = 1.1
    for text, bg, fg in stages:
        box = FancyBboxPatch((x - 1.2, y - 0.4), 2.4, 0.7, boxstyle="round,pad=0.05",
                            edgecolor='black', facecolor=bg, linewidth=2)
        ax.add_patch(box)
        ax.text(x, y, text, ha='center', va='center', fontsize=10, color=fg, weight='bold')
        
        if y > 1.8:
            arrow = FancyArrowPatch((x, y - 0.45), (x, y - step_height + 0.35),
                                   arrowstyle='->', lw=2, color='black')
            ax.add_patch(arrow)
        
        y -= step_height
    
    # Right panel: Sample Library
    sample_box = FancyBboxPatch((5.5, 6.5), 4, 2.5, boxstyle="round,pad=0.1",
                                edgecolor='black', facecolor='lightgray', linewidth=2)
    ax.add_patch(sample_box)
    ax.text(7.5, 8.7, 'Sample Library', ha='center', fontsize=14, weight='bold')
    
    sample_notes = [
        'McGill samples or',
        'public placeholders',
        '',
        '• Multiple dynamics',
        '• Multiple octaves',
        '• MIDI note mapping',
        '• Pitch-shifted by cents',
        '• Velocity mapping'
    ]
    
    y = 8.2
    for note in sample_notes:
        if note:
            ax.text(7.5, y, note, ha='center', fontsize=10)
        y -= 0.28
    
    # Right panel: Csound Operations
    csound_box = FancyBboxPatch((5.5, 3.5), 4, 2.5, boxstyle="round,pad=0.1",
                                edgecolor='black', facecolor='white', linewidth=2)
    ax.add_patch(csound_box)
    ax.text(7.5, 5.7, 'Csound Features', ha='center', fontsize=14, weight='bold')
    
    csound_notes = [
        'Opcodes:',
        '• diskin2 (playback)',
        '• ftgen (tables)',
        '• reverb, compress',
        '',
        'Just Intonation:',
        'Precise cent detuning',
        'No 12-TET constraints'
    ]
    
    y = 5.2
    for note in csound_notes:
        if note.endswith(':'):
            ax.text(7.5, y, note, ha='center', fontsize=11, weight='bold')
        elif note:
            ax.text(7.5, y, note, ha='center', fontsize=9)
        y -= 0.28
    
    # Bottom: Glissando note
    ax.text(5, 1.2, 'Glissando Implementation: Smooth transitions when same pitch class has different cent values',
            ha='center', fontsize=11, style='italic',
            bbox=dict(boxstyle='round', facecolor='white', edgecolor='black'))
    
    plt.tight_layout()
    return fig

def create_chart_6_complete_workflow():
    """Chart 6: Complete System Overview"""
    fig, ax = plt.subplots(figsize=(19.2, 10.8))
    ax.set_xlim(0, 10)
    ax.set_ylim(0, 10)
    ax.axis('off')
    
    # Title
    ax.text(5, 9.7, 'One-Footed Bride: Complete Workflow', 
            ha='center', va='top', fontsize=26, weight='bold')
    
    # Horizontal stages
    stages = [
        ('INPUT', 'MIDI\nBWV 253-264', 1.5),
        ('THEORY', 'Tonality\nDiamond', 3),
        ('OPTIMIZE', 'Simulated\nAnnealing', 5),
        ('SYNTHESIS', 'Csound\nRender', 7),
        ('OUTPUT', 'Audio\nWAV', 8.5)
    ]
    
    y = 7
    for label, text, x in stages:
        if label in ['INPUT', 'OUTPUT']:
            color = 'black'
            text_color = 'white'
        else:
            color = 'white'
            text_color = 'black'
        
        box = FancyBboxPatch((x - 0.6, y - 0.5), 1.2, 1, boxstyle="round,pad=0.05",
                            edgecolor='black', facecolor=color, linewidth=3)
        ax.add_patch(box)
        ax.text(x, y, text, ha='center', va='center', fontsize=12, 
                color=text_color, weight='bold')
        
        # Arrows between stages
        if x < 8.5:
            next_x = stages[[s[0] for s in stages].index(label) + 1][2]
            arrow = FancyArrowPatch((x + 0.65, y), (next_x - 0.65, y),
                                   arrowstyle='->', lw=3, color='black')
            ax.add_patch(arrow)
    
    # Key innovations box
    innov_box = FancyBboxPatch((0.5, 3.5), 4.5, 2.5, boxstyle="round,pad=0.1",
                               edgecolor='black', facecolor='lightgray', linewidth=2)
    ax.add_patch(innov_box)
    ax.text(2.75, 5.7, 'KEY INNOVATIONS', ha='center', fontsize=14, weight='bold')
    
    innovations = [
        '✓ Combines Bach harmony with',
        '  Partch tuning theory',
        '✓ Automated optimization via',
        '  simulated annealing',
        '✓ Sample-based synthesis',
        '  preserves natural timbre',
        '✓ Smooth voice leading with',
        '  intelligent glissandi'
    ]
    
    y = 5.2
    for innov in innovations:
        ax.text(2.75, y, innov, ha='center', fontsize=10)
        y -= 0.27
    
    # Project files box
    files_box = FancyBboxPatch((5.5, 3.5), 4, 2.5, boxstyle="round,pad=0.1",
                               edgecolor='black', facecolor='white', linewidth=2)
    ax.add_patch(files_box)
    ax.text(7.5, 5.7, 'PROJECT FILES', ha='center', fontsize=14, weight='bold')
    
    files = [
        'optimize_chords_sa_v2.py',
        'Main optimization script',
        '',
        'adaptive_tuning_util.py',
        'Core algorithms & classes',
        '',
        'diamond_music_utils.py',
        'Diamond utilities',
        '',
        'WreckingCrew.py',
        'Batch processing'
    ]
    
    y = 5.2
    for i, file_line in enumerate(files):
        if file_line.endswith('.py'):
            ax.text(7.5, y, file_line, ha='center', fontsize=10, weight='bold', family='monospace')
        elif file_line:
            ax.text(7.5, y, file_line, ha='center', fontsize=9, style='italic')
        y -= 0.22
    
    # Bottom: Key metrics
    metrics = '214 ratios @ 31-limit  •  ~80% cache hit rate  •  4-voice harmony  •  Pure just intonation'
    ax.text(5, 2.5, metrics, ha='center', fontsize=12, weight='bold',
            bbox=dict(boxstyle='round', facecolor='white', edgecolor='black', linewidth=2))
    
    # Repository
    ax.text(5, 1.5, 'github.com/prentrodgers/One-footed-bride-tuning',
            ha='center', fontsize=14, family='monospace',
            bbox=dict(boxstyle='round', facecolor='lightgray', edgecolor='black'))
    
    # Bottom note
    ax.text(5, 0.5, 'Merging historical tuning theory with modern computational optimization',
            ha='center', fontsize=11, style='italic')
    
    plt.tight_layout()
    return fig

def main():
    """Generate all presentation charts"""
    output_dir = '/home/prent/Repos/One-footed-bride-tuning/presentation_charts'
    import os
    os.makedirs(output_dir, exist_ok=True)
    
    charts = [
        (create_chart_1_tuning_systems, 'chart_1_tuning_systems.png'),
        (create_chart_2_partch_diamond, 'chart_2_partch_diamond.png'),
        (create_chart_3_simulated_annealing, 'chart_3_simulated_annealing.png'),
        (create_chart_4_bach_pipeline, 'chart_4_bach_pipeline.png'),
        (create_chart_5_csound_synthesis, 'chart_5_csound_synthesis.png'),
        (create_chart_6_complete_workflow, 'chart_6_complete_workflow.png'),
    ]
    
    for create_func, filename in charts:
        print(f"Generating {filename}...")
        fig = create_func()
        filepath = os.path.join(output_dir, filename)
        fig.savefig(filepath, dpi=100, bbox_inches='tight', facecolor='white')
        plt.close(fig)
        print(f"  Saved to {filepath}")
    
    print(f"\n✓ All charts generated in {output_dir}/")
    print(f"  Resolution: 1920x1080 (16:9)")
    print(f"  Format: PNG, black & white")

if __name__ == '__main__':
    main()
