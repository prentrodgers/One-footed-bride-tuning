# Csound GLIBC Version Fix for Ubuntu Distrobox

## Problem
Csound binary installed in `~/.local/bin/csound` required GLIBC 2.38+ and GLIBC 2.42, which are not available in Ubuntu 22.04 (GLIBC 2.35) or even Ubuntu 24.04 (GLIBC 2.39).

Error message:
```
csound: /lib/x86_64-linux-gnu/libc.so.6: version `GLIBC_2.42' not found (required by /var/home/prent/.local/lib/libcsound64.so.7.0)
```

## Root Cause
The local csound installation in `~/.local/bin/csound` was being found first in PATH before the system-installed csound from Ubuntu repositories.

## Solution Implemented
1. Created Ubuntu 24.04 distrobox:
   ```bash
   distrobox create -n ubuntu24 -i ubuntu:24.04
   distrobox enter ubuntu24
   ```

2. Installed system csound:
   ```bash
   sudo apt update && sudo apt upgrade -y
   sudo apt install csound sox libsox-fmt-mp3 -y
   ```

3. Renamed incompatible local csound installation:
   ```bash
   mv ~/.local/bin/csound ~/.local/bin/csound.glibc242
   mv ~/.local/lib/libcsound64.so.7.0 ~/.local/lib/libcsound64.so.7.0.glibc242
   ```

## Verification
- ✅ `csound -h` works from command line
- ✅ `python3 -c "import subprocess; subprocess.run(['csound', '-h'])"` works
- ✅ IBM Bob continues to function correctly

## Notes
- The `~/.local/bin` directory is shared between host and distrobox
- Renaming the local csound affects both host and distrobox
- System csound from Ubuntu 24.04 repos is now used by default
- Original csound binary backed up as `csound.glibc242` if needed later

## Restoration (if needed)
To restore the original csound:
```bash
mv ~/.local/bin/csound.glibc242 ~/.local/bin/csound
mv ~/.local/lib/libcsound64.so.7.0.glibc242 ~/.local/lib/libcsound64.so.7.0
```

## Date
Fixed: 2026-05-21
To proceed with diagnosing the SSH connectivity issue, I need to understand the current state. Can you run these commands from within the distrobox and share the results?

1. `ls -la ~/.ssh/` - Check if SSH directory exists and what files are present
2. `cat ~/.ssh/config` - Check if the SSH config is accessible
3. `ssh -v one-footed-bride` - Try connecting with verbose output to see where it fails