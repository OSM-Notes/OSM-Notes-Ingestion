# Submodule Troubleshooting Guide

## Problem

When you see the error:

```bash
/bin/cleanupAll.sh: line 22: /home/notes/OSM-Notes-Ingestion/lib/osm-common/commonFunctions.sh: No such file or directory
```

This indicates that the Git submodule has not been initialized or updated properly.

## Solution

### Option 1: Initialize Submodule (Recommended)

If you cloned the repository without submodules, initialize them now:

```bash
cd OSM-Notes-Ingestion
git submodule update --init --recursive
```

### Option 2: Re-initialize Completely

If the submodule exists but is corrupted or incomplete:

```bash
cd OSM-Notes-Ingestion

# Deinitialize the submodule
git submodule deinit -f lib/osm-common

# Remove the submodule directory
rm -rf lib/osm-common

# Re-initialize and update
git submodule update --init --recursive
```

### Option 3: Check Current Status

Check if the submodule is properly initialized:

```bash
# Check status
git submodule status

# If you see a '-' prefix, the submodule is not initialized
# Example output with '-':
# -71fc386be2d59495f8deb4eead8fcb6d048041ea lib/osm-common (heads/main)

# Example output without '-':
# 71fc386be2d59495f8deb4eead8fcb6d048041ea lib/osm-common (heads/main)
```

### Option 4: Clone Correctly from Scratch

If nothing else works, clone the repository with submodules from scratch:

```bash
# Remove the current directory
cd ..
rm -rf OSM-Notes-Ingestion

# Clone with submodules
git clone --recurse-submodules git@github.com:OSMLatam/OSM-Notes-Ingestion.git

cd OSM-Notes-Ingestion
```

## Verification

After initializing the submodule, verify it's working:

```bash
# Check if the file exists
ls -la lib/osm-common/commonFunctions.sh

# Run a script that uses the submodule
./bin/cleanupAll.sh --help
```

## Understanding Git Submodules

This repository uses a Git submodule to share common code with other projects:

- **Submodule repository**: <https://github.com/angoca/OSM-Notes-Common>
- **Submodule path**: `lib/osm-common/`
- **Purpose**: Share common functions across OSM-Notes-Ingestion and OSM-Notes-Analytics

The submodule contains:

- `commonFunctions.sh` - Core utility functions
- `validationFunctions.sh` - Data validation
- `errorHandlingFunctions.sh` - Error handling
- `bash_logger.sh` - Logging library

## Prevention

To avoid this issue in the future:

1. Always use `--recurse-submodules` when cloning:

   ```bash
   git clone --recurse-submodules git@github.com:OSMLatam/OSM-Notes-Ingestion.git
   ```

2. Or initialize submodules immediately after cloning:

   ```bash
   git clone git@github.com:OSMLatam/OSM-Notes-Ingestion.git
   cd OSM-Notes-Ingestion
   git submodule update --init --recursive
   ```

## Authentication Issues

If you encounter authentication errors when cloning the submodule:

### SSH Authentication (Recommended)

The repository is configured to use SSH for submodule cloning. Ensure you have:

1. SSH key configured:

   ```bash
   ls -la ~/.ssh/id_rsa.pub ~/.ssh/id_ed25519.pub
   ```

2. SSH key added to GitHub:

   - Copy your public key: `cat ~/.ssh/id_ed25519.pub`
   - Add it at: <https://github.com/settings/keys>

3. Test SSH connection:

   ```bash
   ssh -T git@github.com
   ```

### HTTPS with Token (Alternative)

If you must use HTTPS, you need a GitHub Personal Access Token:

**Step 1: Create a Personal Access Token**

1. Go to: <https://github.com/settings/tokens>
2. Click "Generate new token" → "Generate new token (classic)"
3. Give it a name: "OSM-Notes-Submodule"
4. Select scopes: `repo` (all repository permissions)
5. Click "Generate token"
6. **Copy the token immediately** (you won't see it again)

**Step 2: Configure Git to use the token**

```bash
# Option A: Configure credential helper to store the token
git config --global credential.helper store

# Now when prompted for password, paste the token instead of password
```

Or use it directly in the URL:

```bash
# Replace YOUR_TOKEN with your actual token
git config submodule.lib/osm-common.url https://YOUR_TOKEN@github.com/OSMLatam/OSM-Notes-Common.git

# Then initialize the submodule
git submodule update --init --recursive
```

**Security Note:** Store tokens securely. Consider using SSH instead (see above).

## Additional Resources

- [Git Submodule Documentation](https://git-scm.com/book/en/v2/Git-Tools-Submodules)
- [GitHub SSH Setup](https://docs.github.com/en/authentication/connecting-to-github-with-ssh)
- Main README: [README.md](../README.md)
- Submodule Usage: [README.md](../README.md#shared-functions-git-submodule)

## Version

Updated: 2025-10-27
