# Git Bundle Management Script

## Overview
This script manages Git bundles for secure deployments across air-gapped environments. 
It supports creating a baseline, generating update bundles, rolling back updates, and validating bundles.

## Prerequisites
- Ensure you have `git` installed.
- You should be running this script in a **WSL (Windows Subsystem for Linux) environment** or a Linux system.
- Your repository should be initialized (`git init`) before running the script.

## Setup Instructions
1. Clone or copy the script into your repository directory.
2. Open a terminal and navigate to the script location.
3. Make the script executable:
   ```bash
   chmod +x bundle.sh
   ```
4. Run the setup:
   ```bash
   ./bundle.sh setup
   ```

## Commands & Usage

### 1. Creating a Baseline
A baseline is the initial full repository snapshot.
```bash
./bundle.sh baseline <version>
```
Example:
```bash
./bundle.sh baseline 1.0.0
```
This creates `baseline_1.0.0.bundle` in the `bundles` directory.

### 2. Creating an Update Bundle
An update bundle contains only the changes made after the baseline.
```bash
./bundle.sh update <baseline_version>
```
Example:
```bash
./bundle.sh update 1.0.0
```
This creates `update_1.0.0_<timestamp>.bundle`.

### 3. Rolling Back to Previous Version
Use rollback to revert the last commit(s).
```bash
./bundle.sh rollback [number_of_commits]
```
Example:
```bash
./bundle.sh rollback 1
```
This rolls back the last commit while keeping a backup branch.

### 4. Checking Bundle Size
To check the size of a created bundle:
```bash
ls -lh bundles/
```

### 5. Verifying a Bundle
To verify that a bundle is valid:
```bash
git bundle verify bundles/<bundle_file>
```
Example:
```bash
git bundle verify bundles/update_1.0.0_<timestamp>.bundle
```

### 6. Applying a Bundle in a Different Environment
To clone from a baseline bundle:
```bash
git clone -b master bundles/baseline_1.0.0.bundle new_repo
```

To apply an update bundle:
```bash
cd new_repo
git pull bundles/update_1.0.0_<timestamp>.bundle
```

---

## Notes
- This script does **not** modify your actual remote repository (e.g., Azure DevOps).
- Always verify a bundle before deploying it.
- For air-gapped deployments, transfer bundles manually and apply them using `git pull <bundle>`.
- MAKE SURE TO MODIFY LINE 15 "REPO_DIR" to match your location for project files 

For any issues, modify `bundle_config.sh` or check the log at `logs/bundle_operations.log`.

---

**Author:** Adam Knight  
**Version:** 1.0.0  
