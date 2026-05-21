# SSH Connectivity Fix for Distrobox to one-footed-bride Pod

## Problem
IBM Bob running in Ubuntu 22 distrobox cannot SSH into the Kubernetes pod `one-footed-bride`, while VSCode on the host can connect successfully.

## Root Cause
The [`~/.ssh/config`](/var/home/prent/.ssh/config:1) file has incorrect ownership that SSH considers insecure:
- Owner: `root:root` (should be `prent:prent`)
- SSH error from distrobox: `Bad owner or permissions on /var/home/prent/.ssh/config`
- The file appears as `nobody:nogroup` when viewed from inside the distrobox, but is actually `root:root` on the host

## Current Configuration
The SSH config at [`~/.ssh/config`](/var/home/prent/.ssh/config:1) contains:
```
Host one-footed-bride
    HostName 192.168.68.16
    Port 30222
    User prent
```

The pod is accessible via NodePort 30222 on the Kubernetes node at 192.168.68.16.

## Solution

### Quick Fix: Run the Host-Side Script with Sudo

**IMPORTANT**: The fix must be run from the **HOST** system (not inside distrobox) because the file is owned by `root:root` and requires sudo privileges.

#### Step 1: Exit the distrobox (if you're in it)
```bash
exit
```

#### Step 2: Run the fix script from the host (will prompt for sudo password)
```bash
cd ~/Repos/One-footed-bride-tuning
./fix-ssh-permissions-host.sh
```

The script will use `sudo` to change ownership from `root:root` to `prent:prent`.

This script will:
1. Verify it's running on the host (not in distrobox)
2. Fix ownership on [`~/.ssh/config`](/var/home/prent/.ssh/config:1) to your user
3. Fix permissions on SSH keys
4. Set correct permissions on all SSH files

#### Step 3: Re-enter distrobox and test
```bash
distrobox enter ubuntu  # or your distrobox name
ssh one-footed-bride
```

### Manual Fix (Alternative)

#### Step 1: Fix File Ownership and Permissions
Run these commands from within the distrobox:

```bash
# Fix ownership of the config file
chmod 644 ~/.ssh/config
chown prent:prent ~/.ssh/config

# Verify the fix
ls -la ~/.ssh/config
```

Expected output:
```
-rw-r--r-- 1 prent prent 79 May  4 14:35 /var/home/prent/.ssh/config
```

#### Step 2: Test SSH Connection
```bash
# Test with verbose output
ssh -v one-footed-bride

# If successful, you should connect to the pod
```

#### Step 3: Verify SSH Key Authentication
Ensure the SSH key has correct permissions:
```bash
chmod 600 ~/.ssh/id_ed25519
chmod 644 ~/.ssh/id_ed25519.pub
```

## Alternative Solution (If Permissions Can't Be Fixed)
If the ownership issue persists due to filesystem sharing between host and distrobox, you can:

### Option A: Use Direct SSH Command
```bash
ssh -p 30222 prent@192.168.68.16
```

### Option B: Create Distrobox-Specific SSH Config
If the host fix doesn't work, create a separate config inside distrobox:
```bash
# Create a local config file
mkdir -p ~/.ssh-distrobox
cat > ~/.ssh-distrobox/config << 'EOF'
Host one-footed-bride
    HostName 192.168.68.16
    Port 30222
    User prent
    IdentityFile ~/.ssh/id_ed25519
EOF

chmod 600 ~/.ssh-distrobox/config

# Use it with SSH
ssh -F ~/.ssh-distrobox/config one-footed-bride
```

### Option C: Set SSH Alias in Distrobox
Add to [`~/.bashrc`](/var/home/prent/.bashrc) in distrobox:
```bash
alias ssh-bride='ssh -p 30222 prent@192.168.68.16'
```

Then reload: `source ~/.bashrc` and use: `ssh-bride`

## Verification Steps
1. ✅ Confirm [`~/.ssh`](/var/home/prent/.ssh) directory is shared between host and distrobox
2. ✅ Verify SSH config file exists and contains correct configuration
3. ✅ Fix file ownership and permissions with sudo
4. ✅ Test SSH connection from distrobox - **SUCCESS!**
5. ✅ Verify IBM Bob can use SSH to access the pod - **WORKING!**

## Test Results
Successfully connected from distrobox to pod:
```
📦[prent@bobbox One-footed-bride-tuning]$ ssh one-footed-bride
prent@one-footed-bride-7cc4bd77f9-52nv7:~$ hostname
one-footed-bride-7cc4bd77f9-52nv7
```

## Technical Details

### Pod Configuration
- **Pod Name**: one-footed-bride
- **Service**: one-footed-bride-ssh (NodePort)
- **SSH Port**: 2222 (internal), 30222 (NodePort)
- **Node IP**: 192.168.68.16
- **User**: prent
- **Authentication**: Public key (ed25519)

### Distrobox Environment
- **Container**: ubuntu 22.04 (bobbox)
- **Home Directory**: Shared with host at `/var/home/prent`
- **SSH Directory**: Shared at [`~/.ssh`](/var/home/prent/.ssh)

## Related Files
- [`one-footed-bride-jupyter.yaml`](one-footed-bride-jupyter.yaml:1) - Kubernetes deployment configuration
- [`~/.ssh/config`](/var/home/prent/.ssh/config:1) - SSH client configuration
- [`~/.ssh/id_ed25519`](/var/home/prent/.ssh/id_ed25519:1) - SSH private key

## Summary
The issue was caused by [`~/.ssh/config`](/var/home/prent/.ssh/config:1) being owned by `root:root` instead of `prent:prent`. SSH security checks reject configuration files with incorrect ownership. The file appeared as `nobody:nogroup` when viewed from inside the distrobox due to UID/GID mapping, but was actually `root:root` on the host system.

The fix required running `sudo chown` from the host system to change ownership to the correct user, after which SSH connections from the distrobox to the Kubernetes pod worked successfully.

## Date
- Diagnosed: 2026-05-21
- Fixed: 2026-05-21
- Status: ✅ **RESOLVED**