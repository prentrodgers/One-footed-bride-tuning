# Refactored optimize_chords_sa_v2.py - Portable Installation

## Summary of Changes

The script has been refactored to be portable and work on any user's system without hardcoded Dropbox paths or hostname dependencies.

### Key Changes

#### 1. **Removed Hardcoded Paths**
- **Before:** Hardcoded `/home/prent/Dropbox/Tutorials/TonicNet/` and other user-specific paths
- **After:** All paths are relative to the script's location

#### 2. **New Directory Structure**
```
Project Root/
├── Archive/
│   └── opt/
│       ├── tolerance-1/     ← numpy tuning files for tolerance=1
│       ├── tolerance-2/     ← numpy tuning files for tolerance=2
│       ├── tolerance-3/     ← numpy tuning files for tolerance=3
│       └── tolerance-4/     ← numpy tuning files for tolerance=4
├── One-footed-bride-tuning/
│   └── optimize_chords_sa_v2.py
└── [other project files]
```

#### 3. **Tolerance as Argument**
- **New CLI argument:** `--tolerance TOLERANCE` (default: 1, range: 1-4)
- Data goes to `Archive/opt/tolerance-{N}/` based on the tolerance level
- Enables running multiple tolerance configurations without overwriting results

#### 4. **Automatic Path Resolution**
The `setup_paths()` function now:
- Determines the script's location
- Finds the project root automatically
- Creates tolerance-specific subdirectories
- Works whether cloned from GitHub or copied to any location

### Updated Function: `setup_paths(tolerance=1)`

```python
def setup_paths(tolerance=1):
    """
    Configure Python path and data directories relative to script location.
    
    Directories are created relative to the script directory:
    - Archive/opt/tolerance-N/ for numpy data files
    - (current directory) for log files
    
    Args:
        tolerance: tolerance level (1-4), determines subdirectory name
    
    Returns:
        dict with keys: script_dir, project_dir, numpy_dir, log_dir
    """
```

## Usage

### Basic Usage (default tolerance=1)
```bash
python3 optimize_chords_sa_v2.py --chorale bwv253
```

### With Different Tolerance Levels
```bash
# Run with tolerance level 2
python3 optimize_chords_sa_v2.py --tolerance 2 --chorale bwv253

# Run with tolerance level 3
python3 optimize_chords_sa_v2.py --tolerance 3 --chorale bwv253

# Run with tolerance level 4 (highest)
python3 optimize_chords_sa_v2.py --tolerance 4 --chorale bwv253
```

### Process All Chorales with Tolerance 2
```bash
python3 optimize_chords_sa_v2.py --tolerance 2
```

### Dry-Run Test (no file writes)
```bash
python3 optimize_chords_sa_v2.py --dry-run --quick --tolerance 1 --chorale bwv253
```

### Quick/Testing Mode
```bash
python3 optimize_chords_sa_v2.py --quick --tolerance 2
```

## Installation for New Users

### Step 1: Clone Repository
```bash
git clone https://github.com/prentrodgers/One-footed-bride-tuning.git ~/One-footed-bride-tuning
cd ~/One-footed-bride-tuning
```

### Step 2: Create Directory Structure
```bash
mkdir -p Archive/opt/tolerance-{1,2,3,4}
```

### Step 3: Run the Script
```bash
cd One-footed-bride-tuning
python3 optimize_chords_sa_v2.py --tolerance 1 --quick
```

The script automatically:
- Detects project location
- Creates necessary directories
- Logs to the project directory (or `/tmp` if in Kubernetes)
- Stores numpy files in `Archive/opt/tolerance-{N}/`

## File Organization

### Data Files by Tolerance
```
Archive/opt/tolerance-1/
├── bwv253-sa-opt.npy          (optimized chord tunings)
├── bwv253-sa-opt.txt          (metadata: scores, deciles, etc)
├── bwv254-sa-opt.npy
├── bwv254-sa-opt.txt
└── ...

Archive/opt/tolerance-2/
├── bwv253-sa-opt.npy          (same chord, different tolerance)
├── bwv253-sa-opt.txt
└── ...
```

### Log Files
```
Project Root/
├── optimize_chords_sa_v2.log           (overall log)
├── optimize_chords_sa_v2_bwv253.log    (single chorale when --chorale specified)
└── optimize_chords_sa_v2_bwv254.log
```

## Example Log Output

```
2026-02-08 09:05:43 - INFO - ================================================================================
2026-02-08 09:05:43 - INFO - CHORD TUNING OPTIMIZATION - SIMULATED ANNEALING V2
2026-02-08 09:05:43 - INFO - ================================================================================
2026-02-08 09:05:43 - INFO - Mode: PRODUCTION
2026-02-08 09:05:43 - INFO - Tolerance: 2
2026-02-08 09:05:43 - INFO - Data directory: /home/user/One-footed-bride-tuning/Archive/opt/tolerance-2
2026-02-08 09:05:43 - INFO - Processing 1 chorales
2026-02-08 09:05:43 - INFO - SA parameters: {'tolerance': 2, 'limit_max': 19, ...}
```

## Backwards Compatibility

- All existing command-line arguments still work
- Default behavior unchanged (tolerance=1)
- Can be called from any directory
- Works on any Unix-like system (Linux, macOS)

## Error Handling

Invalid tolerance values are caught and reported:
```bash
$ python3 optimize_chords_sa_v2.py --tolerance 5
Error: tolerance must be 1-4, got 5
```

## Technical Details

### Path Resolution Logic
1. Determines script directory: `os.path.dirname(os.path.abspath(__file__))`
2. If script is in `One-footed-bride-tuning/` subdirectory, project root is parent
3. Otherwise, project root = script directory
4. Data directory: `{project_root}/Archive/opt/tolerance-{N}/`
5. Log directory: project root (or `/tmp` if in Kubernetes)

### Why This Works for New Users
- ✅ No hardcoded usernames or paths
- ✅ No Dropbox dependency
- ✅ No hostname checks
- ✅ Self-contained within project directory
- ✅ Works in containers and CI/CD systems
- ✅ Multiple tolerance levels can coexist
- ✅ Tolerances are independent (separate directories)

## Migration from Old Version

If you have existing data in the old structure:
```bash
# Move old numpy files to tolerance-1 (default)
mv Archive/opt/*.npy Archive/opt/tolerance-1/
mv Archive/opt/*.txt Archive/opt/tolerance-1/
```

The script will then find them automatically when run with `--tolerance 1` (the default).

## Testing

Verify the refactoring works:
```bash
# Test with dry-run (no writes)
python3 optimize_chords_sa_v2.py --dry-run --quick --tolerance 2

# Check log output
cat ../optimize_chords_sa_v2.log | grep -E "Tolerance|Data directory"

# Verify directory creation
ls -la ../Archive/opt/tolerance-{1,2,3,4}/
```
