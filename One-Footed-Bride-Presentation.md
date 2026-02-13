# One-Footed Bride Tuning: Presentation Charts

A comprehensive visual guide to the technology, theory, and implementation of Harry Partch's just intonation system applied to Bach chorales.

**Repository:** https://github.com/prentrodgers/One-footed-bride-tuning

---

## Chart 1: Technology of Tuning

Comparison of equal temperament and just intonation systems, showing how the project bridges modern MIDI with historical tuning theory.

```mermaid
graph TB
    subgraph TuningSystems["Tuning Systems Comparison"]
        ET["12-Tone Equal Temperament<br/>(12-TET)"]
        JI["Just Intonation<br/>(Rational Intervals)"]
    end
    
    ET --> ET1["• All semitones = 100 cents<br/>• Octave = 1200 cents<br/>• Intervals slightly impure"]
    ET --> ET2["• Can modulate freely<br/>• Universal in modern music<br/>• Mathematically equal"]
    
    JI --> JI1["• Intervals from small ratios<br/>• 3:2 = Perfect Fifth (702¢)<br/>• 5:4 = Major Third (386¢)"]
    JI --> JI2["• Pure harmonics<br/>• Varies by key<br/>• Natural acoustics"]
    
    subgraph Diamond["Tonality Diamond Concept"]
        TD["Harry Partch's<br/>Tonality Diamond"]
        TD --> TD1["Limit determines ratios<br/>19-limit: 66 intervals<br/>31-limit: 214 intervals<br/>47-limit: 506 intervals"]
        TD --> TD2["Score = num + den<br/>Lower score = more consonant<br/>3:2 scores 5 (perfect fifth)"]
    end
    
    subgraph Process["This Project's Approach"]
        P1["1. Start with MIDI (12-TET)"]
        P2["2. Build tonality diamond"]
        P3["3. Optimize chords with SA"]
        P4["4. Find low-ratio intervals"]
        P5["5. Export to Csound"]
        
        P1 --> P2 --> P3 --> P4 --> P5
    end
    
    style ET fill:#fff,stroke:#000,stroke-width:2px
    style JI fill:#fff,stroke:#000,stroke-width:2px
    style TD fill:#fff,stroke:#000,stroke-width:3px
    style TuningSystems fill:#f0f0f0,stroke:#000,stroke-width:2px
    style Diamond fill:#f0f0f0,stroke:#000,stroke-width:2px
    style Process fill:#f0f0f0,stroke:#000,stroke-width:2px
```

---

## Chart 2: Harry Partch's Tonality Diamond

The mathematical and musical structure of the tonality diamond, showing how ratios are generated and scored.

```mermaid
graph TB
    subgraph Construction["Building the Tonality Diamond"]
        Start["Start: Define Prime Limit<br/>(e.g., 19, 31, or 47)"]
        Start --> Ratios["Generate All Ratios<br/>Otonality (n/1) & Utonality (1/n)"]
        Ratios --> Unique["Remove Duplicates<br/>& Sort by Value"]
        Unique --> Convert["Convert to Cents<br/>cents = 1200 × log₂(ratio)"]
        Convert --> Score["Calculate Consonance Score<br/>score = numerator + denominator"]
    end
    
    subgraph Structure["Harry Partch's Diamond Structure"]
        O["Otonality Series<br/>(Overtone Series)"]
        U["Utonality Series<br/>(Undertone Series)"]
        
        O --> O1["1/1, 3/1, 5/1, 7/1, 9/1..."]
        O --> O2["Multiply: 1×1, 1×3, 1×5..."]
        
        U --> U1["1/1, 1/3, 1/5, 1/7, 1/9..."]
        U --> U2["Divide: 1/1, 1/3, 1/5..."]
        
        O1 -.Cross Product.-> Diamond
        U1 -.Cross Product.-> Diamond
    end
    
    subgraph Example["Example: 11-Limit Diamond"]
        L11["Primes: 1, 3, 5, 7, 9, 11"]
        L11 --> Ex1["Ratios include:<br/>3/2 (702¢) - Perfect 5th<br/>5/4 (386¢) - Major 3rd<br/>7/4 (969¢) - Harmonic 7th<br/>11/8 (551¢) - Neutral 4th"]
        Ex1 --> Ex2["Total intervals in 11-limit:<br/>~36 unique ratios"]
    end
    
    subgraph ProjectImpl["Implementation in Project"]
        Build["build_tonal_diamond()<br/>adaptive_tuning_util.py"]
        Build --> Array["Returns numpy array:<br/>[ratio, cents, limit_score]"]
        Array --> Usage["Used by:<br/>• ChordScorer<br/>• LowNumberRatioIntervals<br/>• Simulated Annealing"]
    end
    
    Diamond["Diamond Matrix<br/>All Interval Combinations"]
    Diamond --> Store["Store as:<br/>ratio | cents | score"]
    
    style Start fill:#fff,stroke:#000,stroke-width:3px
    style Diamond fill:#fff,stroke:#000,stroke-width:3px
    style Build fill:#fff,stroke:#000,stroke-width:3px
    style Construction fill:#f0f0f0,stroke:#000,stroke-width:2px
    style Structure fill:#f0f0f0,stroke:#000,stroke-width:2px
    style Example fill:#f0f0f0,stroke:#000,stroke-width:2px
    style ProjectImpl fill:#f0f0f0,stroke:#000,stroke-width:2px
```

---

## Chart 3: Simulated Annealing Optimization

The core algorithm that finds optimal tunings for 4-note chords using temperature-based probabilistic search.

```mermaid
flowchart TD
    Start([Start: 4-Note Chord<br/>in 12-TET cents])
    
    Start --> Init["Initialize Parameters<br/>• Temperature = 2.5<br/>• Cooling rate = 0.999<br/>• Tolerance = 1 cent<br/>• Max iterations = 1000"]
    
    Init --> Perturb["Perturb Chord<br/>Small random spread"]
    
    Perturb --> ScoreCurrent["Score Current Solution<br/>ChordScorer.score_chord()"]
    
    ScoreCurrent --> IterStart{Iteration Loop<br/>temp > 0.05?}
    
    IterStart -->|Yes| NewSolution["Generate New Solution<br/>For each interval pair:"]
    
    NewSolution --> SelectRatio["Select Ratio from<br/>Tonality Diamond<br/>LowNumberRatioIntervals"]
    
    SelectRatio --> TempWeight{"Temperature<br/>Weighting"}
    
    TempWeight -->|Hot<br/>Early| Explore["Explore widely<br/>More random choices<br/>spread = 15"]
    
    TempWeight -->|Cool<br/>Later| Exploit["Exploit best<br/>Favor low scores<br/>r_value = 0.3"]
    
    Explore --> ScoreNew["Score New Solution"]
    Exploit --> ScoreNew
    
    ScoreNew --> Compare{"New Score<br/>Better?"}
    
    Compare -->|Yes| Accept["Accept New Solution<br/>current = new<br/>Update best if improved"]
    
    Compare -->|No| Probability{"Accept with<br/>SA probability?<br/>e^((old-new)/temp)"}
    
    Probability -->|Yes| Accept
    Probability -->|No| Reject["Keep Current Solution"]
    
    Accept --> Cool["Cool Temperature<br/>temp *= 0.999"]
    Reject --> Cool
    
    Cool --> CheckStop{"Early Stop?<br/>No improvement<br/>for N iterations"}
    
    CheckStop -->|Yes| Finalize
    CheckStop -->|No| IterStart
    
    IterStart -->|No| Finalize["Finalize Solution<br/>• Rearrange notes<br/>• Force pitch class match<br/>• Return tuned chord"]
    
    Finalize --> End([Output: Optimized<br/>4-Note Chord in Cents])
    
    subgraph Key["Key Concepts"]
        KC1["Simulated Annealing:<br/>Probabilistic optimization<br/>inspired by metallurgy"]
        KC2["Temperature Schedule:<br/>High → explore<br/>Low → refine"]
        KC3["4-Note Chord:<br/>6 intervals to optimize<br/>C(4,2) = 6 pairs"]
    end
    
    subgraph Scoring["Chord Scoring Method"]
        S1["For each pair of notes:<br/>1. Calculate interval in cents<br/>2. Find closest ratio in diamond<br/>3. Sum limit scores"]
        S2["Lower score = more consonant<br/>3/2 (score 5) > 45/32 (score 77)"]
    end
    
    style Start fill:#000,stroke:#000,color:#fff,stroke-width:3px
    style End fill:#000,stroke:#000,color:#fff,stroke-width:3px
    style Compare fill:#fff,stroke:#000,stroke-width:2px
    style Probability fill:#fff,stroke:#000,stroke-width:2px
    style TempWeight fill:#fff,stroke:#000,stroke-width:2px
    style Key fill:#f0f0f0,stroke:#000,stroke-width:2px
    style Scoring fill:#f0f0f0,stroke:#000,stroke-width:2px
```

---

## Chart 4: Bach Chorale Harmony & Tuning

The complete process for analyzing and retuning Bach's four-part chorales using just intonation.

```mermaid
flowchart TD
    Start([Bach Chorale<br/>MIDI File])
    
    Start --> Load["Load MIDI File<br/>read_from_midi()"]
    
    Load --> Analyze["Analyze with music21<br/>• Find root & mode<br/>• Detect time signature<br/>• Extract 4 voices"]
    
    Analyze --> Convert["Convert to Chorale Array<br/>shape: (4 voices, n chords)<br/>MIDI note numbers"]
    
    Convert --> Initial["Initialize to 12-TET<br/>Each semitone = 100 cents"]
    
    Initial --> Diamond["Build Tonality Diamond<br/>limit_max = 19, 31, or 47"]
    
    Diamond --> Process["Process Each Chord"]
    
    Process --> Check{Same as<br/>Previous?}
    
    Check -->|Yes| Reuse["Reuse Previous Tuning<br/>Cache hit!"]
    
    Check -->|No| Compress["Compress Unique Notes<br/>Remove duplicates"]
    
    Compress --> Roll["Roll & Tune<br/>Try multiple rotations<br/>rolls = 5 or 8"]
    
    Roll --> SA["Simulated Annealing<br/>For each roll:<br/>• Initialize temp = 2.5<br/>• Optimize intervals<br/>• Cool temp *= 0.999"]
    
    SA --> Best["Select Best Result<br/>Lowest score across rolls"]
    
    Best --> Rearrange["Rearrange Notes<br/>Match original MIDI<br/>pitch class order"]
    
    Rearrange --> Gap{Large gap from<br/>previous chord?}
    
    Gap -->|Yes| Retune["Retune with Continuity<br/>enforce_pitch_class_continuity()<br/>Minimize jumps"] 
    
    Gap -->|No| Store["Store Tuned Chord"]
    
    Retune --> Store
    Reuse --> Store
    
    Store --> More{More<br/>Chords?}
    
    More -->|Yes| Process
    More -->|No| Output["Output Results<br/>• Tuned chorale (cents)<br/>• Scores per chord<br/>• Cache statistics"]
    
    Output --> Save["Save Numpy Array<br/>{version}_sa_{params}.npy"]
    
    Save --> End([Tuned Bach Chorale<br/>Ready for Synthesis])
    
    subgraph BachAnalysis["Bach Chorale Analysis"]
        B1["Wedding Chorales<br/>BWV 253-264<br/>Four-part harmony"]
        B2["Identify cadences<br/>Analyze harmonic motion<br/>Preserve voice leading"]
    end
    
    subgraph Optimization["Optimization Strategy"]
        O1["Compress: ~80% cache hit<br/>Many repeated chords"]
        O2["Roll: Try different orders<br/>Escape local minima"]
        O3["Continuity: Smooth transitions<br/>Add glissandi if needed"]
    end
    
    style Start fill:#000,stroke:#000,color:#fff,stroke-width:3px
    style End fill:#000,stroke:#000,color:#fff,stroke-width:3px
    style Check fill:#fff,stroke:#000,stroke-width:2px
    style Gap fill:#fff,stroke:#000,stroke-width:2px
    style More fill:#fff,stroke:#000,stroke-width:2px
    style BachAnalysis fill:#f0f0f0,stroke:#000,stroke-width:2px
    style Optimization fill:#f0f0f0,stroke:#000,stroke-width:2px
```

---

## Chart 5: Csound Sample-Based Synthesis

The audio rendering pipeline that converts tuned chords into high-quality WAV files using sample libraries.

```mermaid
flowchart TD
    Start([Tuned Chorale<br/>Cents Array])
    
    Start --> Features["Build Note Features Array<br/>notes_features:<br/>• Onset time<br/>• Duration (hold)<br/>• Octave<br/>• Cent value<br/>• Volume<br/>• Velocity"]
    
    Features --> VoiceTime["Initialize Voice/Instrument Map<br/>init_voice_time()<br/>8+ instruments:<br/>celesta, marimba, harp,<br/>xylophone, vibraphone, etc."]
    
    VoiceTime --> Assign["Assign Notes to Instruments<br/>Based on:<br/>• Voice number (S/A/T/B)<br/>• Octave range<br/>• Section preferences"]
    
    Assign --> Gliss{Detect<br/>Glissandi?}
    
    Gliss -->|Yes| GlissTable["Generate Glissando Tables<br/>f-tables for smooth slides<br/>Store in gliss_tables array"]
    
    Gliss -->|No| Direct["Direct Pitch<br/>No interpolation"]
    
    GlissTable --> Score
    Direct --> Score["Build Csound Score<br/>i-statements:<br/>i inst start dur oct vol vel"]
    
    Score --> Template["Load Csound Template<br/>.csd file with:<br/>• Orchestra (instruments)<br/>• Sample mappings<br/>• Effects routing"]
    
    Template --> Insert["Insert Generated Content<br/>• Glissando f-tables<br/>• Score section<br/>• Tempo markings"]
    
    Insert --> Output["Write Output .csd File<br/>Complete Csound document"]
    
    Output --> Render["Render Audio<br/>csound output.csd<br/>→ WAV file"]
    
    Render --> End([Audio File<br/>24-bit WAV])
    
    subgraph Samples["Sample-Based Synthesis"]
        S1["McGill Sample Library<br/>(or public placeholders)"]
        S2["Instrument samples:<br/>• Multiple dynamics<br/>• Multiple octaves<br/>• Mapped to MIDI notes"]
        S3["Sample playback:<br/>Pitch-shifted by cents<br/>Dynamic velocity mapping"]
    end
    
    subgraph CsoundOps["Csound Operations"]
        C1["Opcodes used:<br/>• diskin2 (sample playback)<br/>• poscil (oscillator)<br/>• ftgen (table generation)<br/>• reverb, compress"]
        C2["Just Intonation:<br/>Precise cent detuning<br/>No equal temperament<br/>constraints"]
    end
    
    subgraph GlissDetails["Glissando Implementation"]
        G1["When adjacent chords have<br/>same pitch class but<br/>different cent values"]
        G2["Generate interpolation table<br/>Smooth transition over time<br/>Natural voice leading"]
    end
    
    style Start fill:#000,stroke:#000,color:#fff,stroke-width:3px
    style End fill:#000,stroke:#000,color:#fff,stroke-width:3px
    style Gliss fill:#fff,stroke:#000,stroke-width:2px
    style Samples fill:#f0f0f0,stroke:#000,stroke-width:2px
    style CsoundOps fill:#f0f0f0,stroke:#000,stroke-width:2px
    style GlissDetails fill:#f0f0f0,stroke:#000,stroke-width:2px
```

---

## Chart 6: Complete Workflow Overview

The end-to-end system showing how all components work together to create just intonation music from MIDI sources.

```mermaid
graph TB
    subgraph Input["1. INPUT: Bach Wedding Chorales"]
        MIDI["MIDI Files<br/>BWV 253-264<br/>Four-part harmony"]
        Analysis["Music21 Analysis<br/>• Root & Mode<br/>• Time Signature<br/>• Voice Extraction"]
        MIDI --> Analysis
    end
    
    subgraph Theory["2. THEORY: Just Intonation Framework"]
        Partch["Harry Partch's<br/>Tonality Diamond"]
        Build["Build Diamond<br/>limit: 19, 31, or 47"]
        Ratios["214 ratios @ 31-limit<br/>ratio | cents | score"]
        
        Partch --> Build --> Ratios
    end
    
    subgraph Optimization["3. OPTIMIZATION: Simulated Annealing"]
        Init["Initialize: 12-TET"]
        SA["Simulated Annealing<br/>• Temperature schedule<br/>• Multi-roll strategy<br/>• Chord compression"]
        Cache["Caching<br/>~80% hit rate"]
        Tune["Tuned Chords<br/>in Cents"]
        
        Init --> SA
        SA --> Cache
        Cache --> SA
        SA --> Tune
    end
    
    subgraph Synthesis["4. SYNTHESIS: Csound Rendering"]
        Convert["Convert to<br/>Csound Score"]
        Gliss["Add Glissandi<br/>for continuity"]
        Samples["Sample Library<br/>Multiple instruments"]
        Render["Render Audio<br/>24-bit WAV"]
        
        Convert --> Gliss
        Gliss --> Samples
        Samples --> Render
    end
    
    subgraph Output["5. OUTPUT: Music & Analysis"]
        Audio["Audio Files<br/>Pure just intonation"]
        Viz["Visualizations<br/>Plots & charts"]
        Data["Analysis Data<br/>Scores & statistics"]
        
        Audio -.-> Listen[["Listen to Results"]]
        Viz -.-> Present[["Present Findings"]]
        Data -.-> Research[["Research Analysis"]]
    end
    
    Analysis -->|"MIDI Array<br/>4 voices × n chords"| Init
    Ratios -->|"Diamond Table"| SA
    Tune -->|"Cent Values"| Convert
    Render --> Audio
    SA --> Viz
    Tune --> Data
    
    subgraph Key["KEY INNOVATIONS"]
        K1["✓ Combines Bach's harmony<br/>   with Partch's tuning"]
        K2["✓ Automated optimization<br/>   via simulated annealing"]
        K3["✓ Sample-based synthesis<br/>   preserves natural timbre"]
        K4["✓ Smooth voice leading<br/>   with intelligent glissandi"]
    end
    
    subgraph Files["PROJECT FILES"]
        F1["optimize_chords_sa_v2.py<br/>Main optimization script"]
        F2["adaptive_tuning_util.py<br/>Core algorithms & classes"]
        F3["diamond_music_utils.py<br/>Diamond & ratio utilities"]
        F4["WreckingCrew.py<br/>Batch processing & output"]
    end
    
    style MIDI fill:#fff,stroke:#000,stroke-width:3px
    style Partch fill:#fff,stroke:#000,stroke-width:3px
    style SA fill:#fff,stroke:#000,stroke-width:3px
    style Samples fill:#fff,stroke:#000,stroke-width:3px
    style Audio fill:#000,stroke:#000,color:#fff,stroke-width:3px
    style Listen fill:#fff,stroke:#000,stroke-width:2px
    style Present fill:#fff,stroke:#000,stroke-width:2px
    style Research fill:#fff,stroke:#000,stroke-width:2px
    
    style Input fill:#f9f9f9,stroke:#000,stroke-width:2px
    style Theory fill:#f9f9f9,stroke:#000,stroke-width:2px
    style Optimization fill:#f9f9f9,stroke:#000,stroke-width:2px
    style Synthesis fill:#f9f9f9,stroke:#000,stroke-width:2px
    style Output fill:#f9f9f9,stroke:#000,stroke-width:2px
    style Key fill:#f0f0f0,stroke:#000,stroke-width:2px,stroke-dasharray: 5 5
    style Files fill:#f0f0f0,stroke:#000,stroke-width:2px,stroke-dasharray: 5 5
```

---

## Presentation Notes

### Key Talking Points

1. **Why Just Intonation?**
   - Pure harmonic intervals create more consonant chords
   - Historical tuning systems reveal new musical possibilities
   - Bach's harmonies sound even more beautiful with rational intervals

2. **Harry Partch's Contribution**
   - Systematic approach to organizing microtonal ratios
   - Tonality diamond provides complete interval palette
   - Score system (num + den) quantifies consonance

3. **Simulated Annealing Innovation**
   - Automated optimization of complex tuning problems
   - Temperature schedule balances exploration and exploitation
   - Multi-roll strategy escapes local minima

4. **Bach Chorale Selection**
   - Wedding chorales (BWV 253-264) are harmonically rich
   - Four-part structure ideal for demonstrating intervals
   - Repeated chords enable efficient caching

5. **Csound Synthesis Quality**
   - Sample-based approach preserves natural instrument timbre
   - Precise cent control enables pure just intonation
   - Glissando smoothing maintains voice leading integrity

6. **Measurable Results**
   - ~80% cache hit rate demonstrates efficiency
   - Lower scores indicate more consonant harmonies
   - Audio files demonstrate perceptible improvement

### Usage

This document can be:
- Viewed directly in GitHub (which renders Mermaid diagrams)
- Exported to PDF for presentations
- Used in VS Code with Mermaid preview extensions
- Converted to slides using tools like Marp or reveal.js

### Contact

For questions about this presentation or the One-Footed Bride Tuning project:
- Repository: https://github.com/prentrodgers/One-footed-bride-tuning
- Created: February 2026
