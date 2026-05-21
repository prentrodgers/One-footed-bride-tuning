# Bob IDE Remote SSH Connection Fix - Missing wget/curl

## Problem
Bob IDE (IBM's VSCode fork) fails to connect to the remote SSH server (one-footed-bride pod) with the error:
```
Error no tool to download server binary
```

**Note:** Regular VSCode (version 1.121.0) connects successfully to the same pod. The issue is specific to Bob IDE (version 1.109.5).

## Root Cause
The remote server (Kubernetes pod at `one-footed-bride`) is missing both `wget` and `curl`, which Bob IDE's installation script requires to download the `bobide-server` component.

From the error log (line 228):
```
Error no tool to download server binary
exitCode==1==
```

The VSCode installation script tries to use either `wget` or `curl` to download the server binary from:
```
https://api.us-east.bob.ibm.com/update/reh/ibm-bob/linux/x64/1.109.5+bob1.0.2
```

## Solution

### Option 1: Manual Server Installation (Recommended - No sudo required)

Since you cannot install packages on the remote pod (no sudo, no apt permissions), use the provided script to manually install the Bob IDE server:

```bash
# Run from your local machine (not in the pod)
./install-bobide-server.sh
```

This script will:
1. Download the Bob IDE server on your local machine (which has wget/curl)
2. Copy it to the remote pod via SSH/SCP
3. Extract and set up the server in `~/.bobide-server/`

After running this script, try connecting with Bob IDE Remote SSH again.

### Option 2: Install wget or curl on the Remote Server (If you have sudo)

If you have sudo access on the pod:

```bash
# Connect to the pod
ssh one-footed-bride

# Install wget (Debian/Ubuntu)
sudo apt-get update && sudo apt-get install -y wget
```

**Note:** Based on your feedback, this option is not available as sudo is not installed and apt requires permissions you don't have.

### Option 2: Pre-install wget/curl in the Pod Image

If you control the Kubernetes deployment, add `wget` or `curl` to the container image:

**Update the Dockerfile or deployment:**
```dockerfile
# Add to your Dockerfile
RUN apt-get update && apt-get install -y wget curl && rm -rf /var/lib/apt/lists/*
```

**Or update the Kubernetes deployment YAML:**
```yaml
# Add an init container or modify the main container
spec:
  containers:
  - name: one-footed-bride
    image: your-image:tag
    # Add a command to install wget/curl on startup
    lifecycle:
      postStart:
        exec:
          command: ["/bin/sh", "-c", "apt-get update && apt-get install -y wget"]
```

### Option 3: Use Regular VSCode Instead

Since regular VSCode already works with the pod, you could continue using it instead of Bob IDE for remote development on this pod.

## Verification

After running the installation script, verify the Bob IDE server is installed:

```bash
ssh one-footed-bride "ls -la ~/.bobide-server/bin/473fcbe9e52a0216936d3c384820ebb51fb5cfc2/bin/bobide-server"
```

Expected output:
```
-rwxr-xr-x 1 prent prent [size] [date] /home/prent/.bobide-server/bin/473fcbe9e52a0216936d3c384820ebb51fb5cfc2/bin/bobide-server
```

Then try connecting with Bob IDE Remote SSH again.

## Technical Details

### Error Log Analysis
- **Server**: one-footed-bride (192.168.68.16:30222)
- **User**: prent
- **Bob IDE Version**: 1.109.5
- **Regular VSCode Version**: 1.121.0 (works fine)
- **Server Commit**: 473fcbe9e52a0216936d3c384820ebb51fb5cfc2
- **Platform**: linux (Debian)
- **Architecture**: x86_64
- **Missing Tools**: wget AND curl (on remote pod)
- **Sudo Access**: Not available on pod
- **Package Installation**: Not possible (no permissions)

### Installation Script Requirements
The VSCode remote installation script (lines 140-146 of error log) requires either:
1. `wget` - for downloading with retry logic
2. `curl` - as a fallback option

Without either tool, the installation cannot proceed.

## Related Files
- [`install-bobide-server.sh`](install-bobide-server.sh) - **Automated installation script (USE THIS)**
- [`~/.ssh/config`](/var/home/prent/.ssh/config) - SSH configuration
- [`SSH_DISTROBOX_FIX.md`](SSH_DISTROBOX_FIX.md) - Previous SSH permission fix
- [`one-footed-bride-jupyter.yaml`](one-footed-bride-jupyter.yaml) - Kubernetes deployment

## Summary
Bob IDE Remote SSH requires `wget` or `curl` on the remote server to download and install the server component. Since you cannot install packages on the pod (no sudo, no apt permissions), use the `install-bobide-server.sh` script to manually download the server locally and copy it to the remote pod.

**Key Insight:** Regular VSCode works because it already has its server installed on the pod. Bob IDE needs its own separate server (`bobide-server`) which hasn't been installed yet.

## Status
- Diagnosed: 2026-05-21
- Status: 🔧 **AWAITING FIX** - Install wget/curl on remote server

## Date
2026-05-21