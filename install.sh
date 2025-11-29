#!/bin/bash
# =============================================================================
# LXC Maintenance - Install Script
# Downloads all files from install/ folder → /opt/scripts/update/
# Repo: https://github.com/cridan7/lxc_maintenance
# =============================================================================

set -euo pipefail

REPO="cridan7/lxc_maintenance"
BRANCH="main"
SRC_DIR="install"
DST_DIR="/opt/scripts/update"

# Colors for nice output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log()   { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

log "Starting installation from ${REPO} (branch: ${BRANCH})"

# Create destination directory
mkdir -p "$DST_DIR"
# chown $(whoami):$(whoami) "$DST_DIR" 2>/dev/null || true

# Temporary directory for download
TMP_DIR=$(mktemp -d)
cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

# Fetch the list of files in install/ folder using GitHub API (no token needed for public repo)
log "Fetching file list from install/ folder..."
FILES_JSON=$(curl -s https://api.github.com/repos/${REPO}/contents/${SRC_DIR}?ref=${BRANCH})

# Check if request succeeded
if ! echo "$FILES_JSON" | grep -q '"name":'; then
    error "Failed to fetch file list. Check repository/branch name or your internet connection."
fi

# Download each file
echo "$FILES_JSON" | grep '"name"' | cut -d'"' -f4 | while read -r filename; do
    if [[ -z "$filename" ]]; then continue; fi
    
    URL="https://raw.githubusercontent.com/${REPO}/${BRANCH}/${SRC_DIR}/${filename}"
    DEST="${DST_DIR}/${filename}"
    
    log "Downloading $filename ..."
    curl -sL "$URL" -o "${TMP_DIR}/${filename}"
    
    # Install file
    install -m 644 "${TMP_DIR}/${filename}" "$DEST" 2>/dev/null || \
        install -m 644 "${TMP_DIR}/${filename}" "$DEST"
    
    # If it's a shell script, make it executable
    if [[ "$filename" == *.sh ]] || head -n1 "${TMP_DIR}/${filename}" | grep -q "^#!/bin/.*bash.*"; then
        chmod 755 "$DEST" 2>/dev/null || chmod 755 "$DEST"
        log "  → $filename (executable)"
    else
        log "  → $filename"
    fi
done

log "Installation complete!"
log "Files are now in: ${DST_DIR}"
echo
ls -lh "$DST_DIR" | awk '{print "  " $9 "  (" $5 ")"}'

exit 0