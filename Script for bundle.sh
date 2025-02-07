#!/bin/bash

# Git Bundle Management Script
# Purpose: Manage git bundles for secure deployments across airgapped environments
# Version: 2.0.0

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/bundle_config.sh"
BUNDLE_DIR=""
LOG_DIR=""
LOG_FILE="${LOG_DIR}/bundle_operations.log"

# Default variables (can be overridden by config file)
REPO_DIR=""
BASELINE_VERSION="1.0.0"

# Load configuration if it exists
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
fi

# Logging function
log() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] $1" | tee -a "$LOG_FILE"
}

# Error handling function
handle_error() {
    log "ERROR: $1"
    exit 1
}

# Setup function
setup() {
    mkdir -p "$BUNDLE_DIR" "$LOG_DIR"
    if [[ ! -d "$REPO_DIR/.git" ]]; then
        handle_error "Directory '$REPO_DIR' is not a git repository"
    fi
    if [[ ! -f "$CONFIG_FILE" ]]; then
        cat > "$CONFIG_FILE" << EOF
# Git Bundle Management Configuration
REPO_DIR="$REPO_DIR"
BASELINE_VERSION="$BASELINE_VERSION"
BUNDLE_DIR="$BUNDLE_DIR"
LOG_DIR="$LOG_DIR"
EOF
        log "Configuration file created: $CONFIG_FILE"
    fi
}

validate_version() {
    if [[ ! $1 =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        handle_error "Invalid version format. Use semantic versioning (e.g., 1.0.0)"
    fi
}

create_baseline() {
    local version=$1
    validate_version "$version"
    log "Creating baseline version $version..."
    cd "$REPO_DIR" || handle_error "Failed to navigate to repo"

    git tag -a "baseline-$version" -m "Baseline version $version" || handle_error "Failed to create tag"
    local bundle_file="${BUNDLE_DIR}/baseline_${version}.bundle"
    git bundle create "$bundle_file" --all || handle_error "Failed to create baseline bundle"
    log "Baseline bundle created: $bundle_file"

    git bundle verify "$bundle_file" || handle_error "Bundle verification failed for $bundle_file"
    log "Baseline bundle verified successfully."

    create_verification_script "$bundle_file" "$version"
}

create_update() {
    local base_version=$1
    validate_version "$base_version"

    local base_tag="baseline-$base_version"
    if ! git rev-parse --verify "$base_tag" >/dev/null 2>&1; then
        handle_error "Baseline version $base_version not found"
    fi

    log "Creating update bundle from baseline $base_version..."
    cd "$REPO_DIR" || handle_error "Failed to navigate to repo"

    local update_id=$(date +%Y%m%d_%H%M%S)
    local bundle_file="${BUNDLE_DIR}/update_${base_version}_${update_id}.bundle"
    git bundle create "$bundle_file" "$base_tag..HEAD" || handle_error "Failed to create update bundle"
    log "Update bundle created: $bundle_file"

    git bundle verify "$bundle_file" || handle_error "Bundle verification failed for $bundle_file"
    log "Update bundle verified successfully."

    create_deployment_script "$bundle_file" "$base_version" "$update_id"
}

create_verification_script() {
    local bundle_file=$1
    local version=$2
    local verify_script="${bundle_file%.bundle}_verify.sh"
    cat > "$verify_script" << EOF
#!/bin/bash
# Verification script for baseline bundle $version

echo "Verifying bundle: $bundle_file"
git bundle verify "$bundle_file"

if [ \$? -eq 0 ]; then
    echo "Bundle verification successful"
else
    echo "Bundle verification failed"
    exit 1
fi
EOF
    chmod +x "$verify_script"
}

create_deployment_script() {
    local bundle_file=$1
    local base_version=$2
    local update_id=$3
    local deploy_script="${bundle_file%.bundle}_deploy.sh"
    cat > "$deploy_script" << EOF
#!/bin/bash
# Deployment script for update $update_id (baseline $base_version)

DEPLOY_DIR="\$1"
if [ -z "\$DEPLOY_DIR" ]; then
    echo "Usage: \$0 <deployment_directory>"
    exit 1
fi

mkdir -p "\$DEPLOY_DIR"
cd "\$DEPLOY_DIR"
if [ ! -d .git ]; then
    git init
fi
git bundle unbundle "$bundle_file"
git checkout -f master
EOF
    chmod +x "$deploy_script"
}

rollback_update() {
    cd "$REPO_DIR" || handle_error "Failed to navigate to repo"
    local commits=${1:-1}

    log "Rolling back the last $commits commit(s) using git revert..."
    local backup_branch="backup_$(date +%Y%m%d_%H%M%S)"
    git branch "$backup_branch" || handle_error "Failed to create backup branch"
    log "Backup branch created: $backup_branch"

    git revert --no-commit HEAD~"$commits"..HEAD || handle_error "Failed to revert commits"
    git commit -m "Rollback: Reverted the last $commits commit(s)"
    log "Rollback completed successfully. Changes are now committed."
}

show_help() {
    cat << EOF
Git Bundle Management Script

Usage: $0 [command] [options]

Commands:
  setup                   Initialize environment
  baseline <version>      Create baseline
  update <base_version>   Create update
  rollback [commits]      Rollback changes
EOF
}

case "${1:-help}" in
    setup) setup ;;
    baseline) create_baseline "$2" ;;
    update) create_update "$2" ;;
    rollback) rollback_update "${2:-1}" ;;
    help|*) show_help ;;
esac
