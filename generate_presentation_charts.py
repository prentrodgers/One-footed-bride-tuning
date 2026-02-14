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
plt.rcParams['font.size'] = 16  # Increased for projection visibility
plt.rcParams['font.family'] = 'sans-serif'
plt.rcParams['font.weight'] = 'bold'  # Bolder text by default

def create_chart_1_tuning_systems():
    """Chart 1: Technology of Tuning - Comparison"""
    fig, ax = plt.subplots(figsize=(19.2, 10.8))
    ax.set_xlim(0, 10)
    ax.set_ylim(0, 10)
    ax.axis('off')
    
    # Title
    ax.text(5, 9.7, 'Technology of Tuning: 12-TET vs Just Intonation', 
            ha='center', va='top', fontsize=32, weight='bold')
    
    # Left side: 12-TET
    et_box = FancyBboxPatch((0.5, 5.2), 4.2, 3.8, boxstyle="round,pad=0.15", 
                            edgecolor='black', facecolor='white', linewidth=3)
    ax.add_patch(et_box)
    ax.text(2.6, 8.5, '12-Tone Equal', ha='center', fontsize=20, weight='bold')
    ax.text(2.6, 8.05, 'Temperament', ha='center', fontsize=20, weight='bold')
    
    et_text = [
        '• All semitones = 100¢',
        '• Octave = 1200¢',
        '• Can modulate freely',
        '• Slightly impure intervals',
        '• Universal modern standard'
    ]
    y = 7.45
    for line in et_text:
        ax.text(2.6, y, line, ha='center', fontsize=15)
        y -= 0.42
    
    # Right side: Just Intonation
    ji_box = FancyBboxPatch((5.3, 5.2), 4.2, 3.8, boxstyle="round,pad=0.15", 
                            edgecolor='black', facecolor='white', linewidth=3)
    ax.add_patch(ji_box)
    ax.text(7.4, 8.5, 'Just Intonation', ha='center', fontsize=20, weight='bold')
    ax.text(7.4, 8.05, '(Rational Intervals)', ha='center', fontsize=18, weight='bold')
    
    ji_text = [
        '• 3:2 = Perfect Fifth (702¢)',
        '• 5:4 = Major Third (386¢)',
        '• Pure harmonics',
        '• Varies by key',
        '• Natural acoustics'
    ]
    y = 7.45
    for line in ji_text:
        ax.text(7.4, y, line, ha='center', fontsize=15)
        y -= 0.42
    
    # Bottom: Tonality Diamond
    diamond_box = FancyBboxPatch((0.8, 1.2), 8.4, 3.5, boxstyle="round,pad=0.15", 
                                 edgecolor='black', facecolor='lightgray', linewidth=4)
    ax.add_patch(diamond_box)
    ax.text(5, 4.4, "Harry Partch's Tonality Diamond", ha='center', fontsize=24, weight='bold')
    
    diamond_text = [
        '19-limit: 66 ratios  |  31-limit: 214 ratios  |  47-limit: 506 ratios',
        'Score = numerator + denominator  •  3:2 scores 5  •  Lower = more consonant'
    ]
    y = 3.75
    for line in diamond_text:
        ax.text(5, y, line, ha='center', fontsize=16)
        y -= 0.48
    
    # Project approach
    ax.text(5, 0.6, 'MIDI (12-TET) → Build Diamond → Optimize → Find Pure Ratios → Csound', 
            ha='center', fontsize=16, weight='bold',
            bbox=dict(boxstyle='round,pad=0.15', facecolor='white', edgecolor='black', linewidth=3))
    
    plt.tight_layout(pad=0.3)
    return fig

def create_chart_2_partch_diamond():
    """Chart 2: Harry Partch's Tonality Diamond Structure"""
    fig, ax = plt.subplots(figsize=(19.2, 10.8))
    ax.set_xlim(0, 10)
    ax.set_ylim(0, 10)
    ax.axis('off')
    
    # Title
    ax.text(5, 9.7, "Harry Partch's Tonality Diamond", 
            ha='center', va='top', fontsize=32, weight='bold')
    
    # Top: Construction Process (compressed with larger text)
    steps = ['Prime Limit', 'Generate\nRatios', 'Remove\nDuplicates', 
             'Convert to\nCents', 'Calculate\nScores']
    x_positions = np.linspace(1, 9, len(steps))
    
    for i, (x, step) in enumerate(zip(x_positions, steps)):
        circle = plt.Circle((x, 8.5), 0.45, color='white', ec='black', linewidth=3)
        ax.add_patch(circle)
        ax.text(x, 8.5, step, ha='center', va='center', fontsize=13, weight='bold')
        
        if i < len(steps) - 1:
            arrow = FancyArrowPatch((x + 0.5, 8.5), (x_positions[i+1] - 0.5, 8.5),
                                   arrowstyle='->', lw=3, color='black')
            ax.add_patch(arrow)
    
    # Middle: Otonality and Utonality
    ot_box = FancyBboxPatch((0.3, 5.2), 4.4, 2.8, boxstyle="round,pad=0.12",
                            edgecolor='black', facecolor='white', linewidth=3)
    ax.add_patch(ot_box)
    ax.text(2.5, 7.6, 'Otonality', ha='center', fontsize=18, weight='bold')
    ax.text(2.5, 7.1, '(Overtone Series)', ha='center', fontsize=15, weight='bold')
    ax.text(2.5, 6.5, '1/1, 3/1, 5/1, 7/1...', ha='center', fontsize=14, family='monospace')
    ax.text(2.5, 6, 'Multiply products', ha='center', fontsize=13)
    ax.text(2.5, 5.5, 'Natural harmonics', ha='center', fontsize=13, style='italic')
    
    ut_box = FancyBboxPatch((5.3, 5.2), 4.4, 2.8, boxstyle="round,pad=0.12",
                            edgecolor='black', facecolor='white', linewidth=3)
    ax.add_patch(ut_box)
    ax.text(7.5, 7.6, 'Utonality', ha='center', fontsize=18, weight='bold')
    ax.text(7.5, 7.1, '(Undertone Series)', ha='center', fontsize=15, weight='bold')
    ax.text(7.5, 6.5, '1/1, 1/3, 1/5, 1/7...', ha='center', fontsize=14, family='monospace')
    ax.text(7.5, 6, 'Divide products', ha='center', fontsize=13)
    ax.text(7.5, 5.5, 'Inverted harmonics', ha='center', fontsize=13, style='italic')
    
    # Cross product arrow
    ax.annotate('', xy=(7.5, 4.95), xytext=(2.5, 4.95),
                arrowprops=dict(arrowstyle='<->', lw=4, color='black'))
    ax.text(5, 4.6, 'DIAMOND MATRIX', ha='center', fontsize=14, weight='bold',
            bbox=dict(boxstyle='round', facecolor='white', edgecolor='black', linewidth=2))
    
    # Example ratios
    example_box = FancyBboxPatch((0.5, 1.3), 9, 3, boxstyle="round,pad=0.15",
                                 edgecolor='black', facecolor='lightgray', linewidth=4)
    ax.add_patch(example_box)
    ax.text(5, 4, 'Example: Key Ratios in Tonality Diamond', ha='center', fontsize=20, weight='bold')
    
    ratios = [
        '3/2 (702¢) - Perfect 5th  •  5/4 (386¢) - Major 3rd  •  7/4 (969¢) - Harmonic 7th',
        '11/8 (551¢) - Neutral 4th  •  9/8 (204¢) - Major 2nd  •  15/8 (1088¢) - Major 7th',
        '31-Limit provides 214 unique ratios scanned by consonance score'
    ]
    y = 3.35
    for ratio in ratios:
        ax.text(5, y, ratio, ha='center', fontsize=14)
        y -= 0.5
    
    plt.tight_layout(pad=0.3)
    return fig

def create_chart_3_simulated_annealing():
    """Chart 3: Simulated Annealing Algorithm"""
    fig, ax = plt.subplots(figsize=(19.2, 10.8))
    ax.set_xlim(0, 10)
    ax.set_ylim(0, 10)
    ax.axis('off')
    
    # Title
    ax.text(5, 9.7, 'Simulated Annealing: Chord Optimization', 
            ha='center', va='top', fontsize=32, weight='bold')
    
    # Vertical flow in center
    y_pos = 8.8
    step_height = 0.88
    x_center = 2.5
    
    steps = [
        ('START', 'Input: 4-note chord (cents)', 'black'),
        ('INIT', 'Initialize: T=2.5, Cool=0.999', 'white'),
        ('LOOP', 'While T > 0.05:', 'white'),
        ('NEW', 'Generate new solution\nfrom diamond', 'white'),
        ('SCORE', 'Score new solution', 'white'),
        ('TEMP', 'High T: Explore  |  Low T: Refine', 'lightgray'),
        ('ACCEPT?', 'Better or\nSA prob?', 'white'),
        ('COOL', 'Cool: T *= 0.999', 'white'),
        ('OUTPUT', 'Optimized chord (cents)', 'black'),
    ]
    
    for i, (label, text, fill) in enumerate(steps):
        if fill == 'black':
            box_color = 'black'
            text_color = 'white'
        else:
            box_color = fill
            text_color = 'black'
            
        box = FancyBboxPatch((x_center - 1.0, y_pos - 0.35), 2.0, 0.65,
                            boxstyle="round,pad=0.07",
                            edgecolor='black', facecolor=box_color, linewidth=3)
        ax.add_patch(box)
        
        ax.text(x_center, y_pos, text, ha='center', va='center', 
                fontsize=14, color=text_color, weight='bold')
        
        # Arrow to next step
        if i < len(steps) - 1:
            arrow = FancyArrowPatch((x_center, y_pos - 0.38), (x_center, y_pos - 0.88 + 0.35),
                                   arrowstyle='->', lw=3, color='black')
            ax.add_patch(arrow)
        
        y_pos -= step_height
    
    # Right panel: Key Concepts
    concept_box = FancyBboxPatch((5.2, 4.5), 4.5, 4.8, boxstyle="round,pad=0.15",
                                 edgecolor='black', facecolor='lightgray', linewidth=4)
    ax.add_patch(concept_box)
    ax.text(7.45, 9, 'Key Concepts', ha='center', fontsize=20, weight='bold')
    
    concepts = [
        'Simulated Annealing:',
        'Probabilistic optimization',
        'inspired by metallurgy',
        '',
        'Temperature Schedule:',
        'High → explore widely',
        'Low → refine solution',
        '',
        '4-Note Chord:',
        '6 interval pairs',
        'C(4,2) = 6 combinations',
        '',
        'Scoring:',
        'Lower = more consonant',
        'Sum interval scores'
    ]
    
    y = 8.4
    for concept in concepts:
        if concept.endswith(':'):
            ax.text(7.45, y, concept, ha='center', fontsize=15, weight='bold')
        elif concept:
            ax.text(7.45, y, concept, ha='center', fontsize=13)
        y -= 0.29
    
    plt.tight_layout(pad=0.3)
    return fig

def create_chart_4_bach_pipeline():
    """Chart 4: Bach Chorale Processing Pipeline"""
    fig, ax = plt.subplots(figsize=(19.2, 10.8))
    ax.set_xlim(0, 10)
    ax.set_ylim(0, 10)
    ax.axis('off')
    
    # Title
    ax.text(5, 9.7, 'Bach Chorale Tuning Pipeline', 
            ha='center', va='top', fontsize=32, weight='bold')
    
    # Vertical pipeline (centered, tighter spacing)
    stages = [
        ('INPUT', 'Bach Chorale MIDI (BWV 253-264)', 'black', 'white'),
        ('ANALYZE', 'Extract: root, mode, time sig, voices', 'white', 'black'),
        ('CONVERT', 'Array: 4 voices × n chords', 'white', 'black'),
        ('DIAMOND', 'Build diamond: limit = 31', 'lightgray', 'black'),
        ('OPTIMIZE', 'Simulated Annealing: Roll & tune', 'white', 'black'),
        ('CACHE', '~80% hit rate: repeated chords', 'white', 'black'),
        ('CONTINUITY', 'Smooth transitions & glissandi', 'white', 'black'),
        ('OUTPUT', 'Tuned chorale for Csound', 'black', 'white'),
    ]
    
    y = 8.9
    y_step = 0.95
    for label, text, bg, fg in stages:
        box = FancyBboxPatch((1.8, y - 0.38), 6.4, 0.65, boxstyle="round,pad=0.08",
                            edgecolor='black', facecolor=bg, linewidth=3)
        ax.add_patch(box)
        ax.text(5, y, text, ha='center', va='center', fontsize=16, color=fg, weight='bold')
        
        if y > 1.5:
            arrow = FancyArrowPatch((5, y - 0.42), (5, y - y_step + 0.36),
                                   arrowstyle='->', lw=3, color='black')
            ax.add_patch(arrow)
        
        y -= y_step
    
    # Side panel: Strategy notes
    strategy_box = FancyBboxPatch((0.3, 2.5), 2, 4.2, boxstyle="round,pad=0.1",
                                  edgecolor='black', facecolor='lightgray', linewidth=3)
    ax.add_patch(strategy_box)
    ax.text(1.3, 6.4, 'Key Strategy', ha='center', fontsize=14, weight='bold')
    
    strategies = [
        'Compression:',
        '~80% cache hits',
        '',
        'Multi-rolling:',
        'Escape local minima',
        '',
        'Roll count: 5-8',
        'Select best score'
    ]
    
    y = 5.95
    for strat in strategies:
        if strat.endswith(':'):
            ax.text(1.3, y, strat, ha='center', fontsize=12, weight='bold')
        elif strat:
            ax.text(1.3, y, strat, ha='center', fontsize=11)
        y -= 0.38
    
    # Right panel: Optimization notes
    optim_box = FancyBboxPatch((7.7, 2.5), 2, 4.2, boxstyle="round,pad=0.1",
                               edgecolor='black', facecolor='lightgray', linewidth=3)
    ax.add_patch(optim_box)
    ax.text(8.7, 6.4, 'Optimization', ha='center', fontsize=14, weight='bold')
    
    optimizations = [
        'Parameters:',
        'T_init = 2.5',
        'Cool = 0.999',
        '',
        'Output:',
        'Cent values',
        'Tuning scores',
        'Cache stats'
    ]
    
    y = 5.95
    for opt in optimizations:
        if opt.endswith(':'):
            ax.text(8.7, y, opt, ha='center', fontsize=12, weight='bold')
        elif opt:
            ax.text(8.7, y, opt, ha='center', fontsize=11)
        y -= 0.38
    
    plt.tight_layout(pad=0.3)
    return fig

def create_chart_5_csound_synthesis():
    """Chart 5: Csound Synthesis Pipeline"""
    fig, ax = plt.subplots(figsize=(19.2, 10.8))
    ax.set_xlim(0, 10)
    ax.set_ylim(0, 10)
    ax.axis('off')
    
    # Title
    ax.text(5, 9.7, 'Csound Sample-Based Synthesis Pipeline', 
            ha='center', va='top', fontsize=32, weight='bold')
    
    # Main flow (left/center side, tighter)
    x = 2.3
    stages = [
        ('TUNED\nCHORALE', 'Cents Array', 'black', 'white', 0.6),
        ('FEATURES', 'Onset, duration, octave,\ncents, volume, velocity', 'white', 'black', 0.8),
        ('ASSIGN', 'Instruments:\ncelesta, marimba, harp', 'white', 'black', 0.8),
        ('GLISSANDI', 'Smooth cent\ntransitions', 'lightgray', 'black', 0.8),
        ('CSOUND\nSCORE', 'i-statements with\nprecise cents', 'white', 'black', 0.8),
        ('RENDER', 'csound output.csd', 'white', 'black', 0.6),
        ('AUDIO', '24-bit WAV', 'black', 'white', 0.6),
    ]
    
    y = 8.9
    y_step = 0.9
    for label, text, bg, fg, box_height in stages:
        box_w = 1.8
        box = FancyBboxPatch((x - box_w/2, y - box_height/2), box_w, box_height, 
                            boxstyle="round,pad=0.07",
                            edgecolor='black', facecolor=bg, linewidth=3)
        ax.add_patch(box)
        
        # Split label and text
        if '\n' in label:
            parts = label.split('\n')
            ax.text(x, y + 0.15, parts[0], ha='center', va='center', 
                   fontsize=13, color=fg, weight='bold')
            ax.text(x, y - 0.15, parts[1], ha='center', va='center', 
                   fontsize=13, color=fg, weight='bold')
        else:
            ax.text(x, y + 0.1, label, ha='center', va='center', 
                   fontsize=13, color=fg, weight='bold')
            ax.text(x, y - 0.15, text, ha='center', va='center', 
                   fontsize=10, color=fg)
        
        if y > 1.8:
            arrow = FancyArrowPatch((x, y - box_height/2 - 0.1), (x, y - y_step + box_height/2 + 0.1),
                                   arrowstyle='->', lw=3, color='black')
            ax.add_patch(arrow)
        
        y -= y_step
    
    # Right panel: Sample Library
    sample_box = FancyBboxPatch((5.2, 5.5), 2.3, 3.8, boxstyle="round,pad=0.12",
                                edgecolor='black', facecolor='lightgray', linewidth=3)
    ax.add_patch(sample_box)
    ax.text(6.35, 9, 'Sample', ha='center', fontsize=14, weight='bold')
    ax.text(6.35, 8.65, 'Library', ha='center', fontsize=14, weight='bold')
    
    sample_notes = [
        'McGill or public',
        'placeholders',
        '',
        '• Dynamics',
        '• Octaves',
        '• MIDI mapping',
        '• Pitch-shift ¢',
        '• Velocity map'
    ]
    
    y = 8.2
    for note in sample_notes:
        if note:
            ax.text(6.35, y, note, ha='center', fontsize=11)
        y -= 0.38
    
    # Right panel: Csound Features
    csound_box = FancyBboxPatch((7.7, 5.5), 2.3, 3.8, boxstyle="round,pad=0.12",
                                edgecolor='black', facecolor='white', linewidth=3)
    ax.add_patch(csound_box)
    ax.text(8.85, 9, 'Csound', ha='center', fontsize=14, weight='bold')
    ax.text(8.85, 8.65, 'Features', ha='center', fontsize=14, weight='bold')
    
    csound_notes = [
        'Opcodes:',
        'diskin2, ftgen',
        'reverb, compress',
        '',
        'Just Intonation:',
        'Precise cent',
        'detuning',
        'No 12-TET limit'
    ]
    
    y = 8.2
    for note in csound_notes:
        if note.endswith(':'):
            ax.text(8.85, y, note, ha='center', fontsize=11, weight='bold')
        elif note:
            ax.text(8.85, y, note, ha='center', fontsize=11)
        y -= 0.38
    
    # Bottom: Key feature
    ax.text(5, 1.5, 'Glissando: Smooth transitions between chords with same pitch class, different cents',
            ha='center', fontsize=13, weight='bold',
            bbox=dict(boxstyle='round,pad=0.12', facecolor='white', edgecolor='black', linewidth=2))
    
    plt.tight_layout(pad=0.3)
    return fig

def create_chart_6_complete_workflow():
    """Chart 6: Complete System Overview"""
    fig, ax = plt.subplots(figsize=(19.2, 10.8))
    ax.set_xlim(0, 10)
    ax.set_ylim(0, 10)
    ax.axis('off')
    
    # Title
    ax.text(5, 9.7, 'One-Footed Bride: Complete Workflow', 
            ha='center', va='top', fontsize=34, weight='bold')
    
    # Horizontal pipeline (tighter, larger)
    stages = [
        ('INPUT', 'MIDI\nBWV 253-264', 1),
        ('THEORY', 'Tonality\nDiamond', 2.8),
        ('OPTIMIZE', 'Simulated\nAnnealing', 5),
        ('SYNTHESIS', 'Csound\nRender', 7.2),
        ('OUTPUT', 'Audio\nWAV', 9)
    ]
    
    y = 7.5
    for label, text, x in stages:
        if label in ['INPUT', 'OUTPUT']:
            color = 'black'
            text_color = 'white'
            box_w, box_h = 0.8, 1.1
        else:
            color = 'white'
            text_color = 'black'
            box_w, box_h = 0.9, 1.1
        
        box = FancyBboxPatch((x - box_w/2, y - box_h/2), box_w, box_h, 
                            boxstyle="round,pad=0.08",
                            edgecolor='black', facecolor=color, linewidth=4)
        ax.add_patch(box)
        ax.text(x, y, text, ha='center', va='center', fontsize=16, 
                color=text_color, weight='bold')
        
        # Arrows between stages
        if x < 9:
            next_x = stages[[s[0] for s in stages].index(label) + 1][2]
            arrow = FancyArrowPatch((x + box_w/2 + 0.1, y), (next_x - box_w/2 - 0.1, y),
                                   arrowstyle='->', lw=4, color='black')
            ax.add_patch(arrow)
    
    # Key innovations box (upper left)
    innov_box = FancyBboxPatch((0.3, 4.8), 4.5, 2.2, boxstyle="round,pad=0.12",
                               edgecolor='black', facecolor='lightgray', linewidth=3)
    ax.add_patch(innov_box)
    ax.text(2.55, 6.7, 'KEY INNOVATIONS', ha='center', fontsize=16, weight='bold')
    
    innovations = [
        '✓ Bach + Partch tuning',
        '✓ Automated SA optimization',
        '✓ Sample-based synthesis',
        '✓ Smart glissandi'
    ]
    
    y = 6.15
    for innov in innovations:
        ax.text(2.55, y, innov, ha='center', fontsize=13)
        y -= 0.38
    
    # Key metrics box (upper right)
    metrics_box = FancyBboxPatch((5.2, 4.8), 4.5, 2.2, boxstyle="round,pad=0.12",
                                 edgecolor='black', facecolor='white', linewidth=3)
    ax.add_patch(metrics_box)
    ax.text(7.45, 6.7, 'KEY METRICS', ha='center', fontsize=16, weight='bold')
    
    metrics_text = [
        '214 ratios @ 31-limit',
        '~80% cache hit rate',
        '4-voice harmony',
        'Pure just intonation'
    ]
    
    y = 6.15
    for metric in metrics_text:
        ax.text(7.45, y, metric, ha='center', fontsize=13)
        y -= 0.38
    
    # Project files box (lower left)
    files_box = FancyBboxPatch((0.3, 1), 4.5, 3.3, boxstyle="round,pad=0.12",
                               edgecolor='black', facecolor='lightgray', linewidth=3)
    ax.add_patch(files_box)
    ax.text(2.55, 4, 'CORE FILES', ha='center', fontsize=16, weight='bold')
    
    files = [
        'optimize_chords_sa_v2.py',
        'Main SA optimization',
        '',
        'adaptive_tuning_util.py',
        'Core algorithms',
        '',
        'diamond_music_utils.py',
        'Ratio utilities',
        '',
        'WreckingCrew.py',
        'Batch processing'
    ]
    
    y = 3.5
    for file_line in files:
        if file_line.endswith('.py'):
            ax.text(2.55, y, file_line, ha='center', fontsize=12, weight='bold', family='monospace')
        elif file_line:
            ax.text(2.55, y, file_line, ha='center', fontsize=11)
        y -= 0.25
    
    # Repository info (lower right)
    repo_box = FancyBboxPatch((5.2, 1), 4.5, 3.3, boxstyle="round,pad=0.12",
                              edgecolor='black', facecolor='white', linewidth=3)
    ax.add_patch(repo_box)
    ax.text(7.45, 4, 'REPOSITORY', ha='center', fontsize=16, weight='bold')
    
    github_url = 'github.com/prentrodgers/'
    repo_name = 'One-footed-bride-tuning'
    
    ax.text(7.45, 3.5, github_url, ha='center', fontsize=12, family='monospace')
    ax.text(7.45, 3.1, repo_name, ha='center', fontsize=12, weight='bold', family='monospace',
            bbox=dict(boxstyle='round,pad=0.08', facecolor='lightyellow', edgecolor='black'))
    
    features = [
        'BWV 253-264 Wedding',
        'Chorales by Bach',
        '',
        'Multi-limit support:',
        '19, 31, 47 limits',
        '',
        'Csound rendering with',
        'glissandi smoothing'
    ]
    
    y = 2.5
    for feature in features:
        if feature.endswith(':'):
            ax.text(7.45, y, feature, ha='center', fontsize=11, weight='bold')
        elif feature:
            ax.text(7.45, y, feature, ha='center', fontsize=11)
        y -= 0.28
    
    plt.tight_layout(pad=0.3)
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
