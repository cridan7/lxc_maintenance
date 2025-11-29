#!/bin/bash
set -euo pipefail

LOG_DIR="/opt/scripts/update/log"
LOG_FILE="$LOG_DIR/lxc_remove_log"
DIR_TO_LIST="/opt/update/"
FILE_NAMES="clean.sh, fstrim.sh, update_system.sh, update_docker_container.sh"   # ← comma-separated list, spaces allowed

# Split SOURCE_NAME into array (comma-separated, trim spaces)
IFS=',' read -ra FILES_TO_REMOVE <<< "$FILE_NAMES"
FILES_TO_REMOVE=("${FILES_TO_REMOVE[@]%"${FILES_TO_REMOVE##*[! ]}"}")  # trim trailing
FILES_TO_REMOVE=("${FILES_TO_REMOVE[@]#*"${FILES_TO_REMOVE%%[! ]*}"}")  # trim leading

# Ensure log directory exists
mkdir -p "$LOG_DIR"

# Get all container IDs by default
ALL_CTIDS=($(pct list | awk 'NR>1 {print $1}'))
CTIDS=("${ALL_CTIDS[@]}")  # Default: all containers

MODE="all"          # all | custom | skip
DELETE_ALL=false    # false = only specific files, true = rm -rf everything

# Parse arguments ---------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        -all|--all)
            DELETE_ALL=true
            shift
            ;;
        -c|--custom)
            MODE="custom"
            shift
            IFS=',' read -ra CTIDS <<< "$(echo "$1" | tr -d '[:space:]')"
            shift
            ;;
        -s|--skip)
            MODE="skip"
            shift
            IFS=',' read -ra SKIP_IDS <<< "$(echo "$1" | tr -d '[:space:]')"
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [-all] [-c 100,101] [-s 102]"
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

# Apply mode logic -------------------------------------------------------------
if [[ "$MODE" == "custom" ]]; then
    : # CTIDS already set above
elif [[ "$MODE" == "skip" ]]; then
    NEW_CTIDS=()
    for ct in "${ALL_CTIDS[@]}"; do
        skip=false
        for id in "${SKIP_IDS[@]}"; do
            [[ "$ct" == "$id" ]] && skip=true && break
        done
        if ! $skip; then
            NEW_CTIDS+=("$ct")
        fi
    done
    CTIDS=("${NEW_CTIDS[@]}")
else
    CTIDS=("${ALL_CTIDS[@]}")   # default = all
fi

[[ ${#CTIDS[@]} -eq 0 ]] && { echo "No containers selected"; exit 1; }

echo "Found ${#CTIDS[@]} LXC containers. Starting processing..."
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting cleanup for ${#CTIDS[@]} containers" >> "$LOG_FILE"

# Loop through containers -------------------------------------------------------
for CTID in "${CTIDS[@]}"; do
    echo "=== CT $CTID ==="
    STARTED_BY_US=0
    if [[ "$(pct status "$CTID" | awk '{print $2}')" == "stopped" ]]; then
        echo "  Stopped → starting temporarily"
        pct start "$CTID"
        STARTED_BY_US=1
        sleep 10
    else
        echo "  Already running"
    fi

    if $DELETE_ALL; then
        # ───── NUCLEAR OPTION ─────
        if pct exec "$CTID" -- bash -c "rm -rf ${DIR_TO_LIST}*"; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] CTID $CTID: Removed all files & folders from ${DIR_TO_LIST}" >> "$LOG_FILE"
        else
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] CTID $CTID: ERROR removing all files & folders from ${DIR_TO_LIST}" >> "$LOG_FILE"
        fi
        if pct exec "$CTID" -- bash -c "sed -i -e '/^\s*#/s/^\\s*#\\s*//' -e '/^\s*$/d' -e '/update-menu\.sh/d' /bin/update"; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] CTID $CTID: Removed all comments from /bin/update, update-menu.sh entry" >> "$LOG_FILE"
        else
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] CTID $CTID: ERROR editing /bin/update" >> "$LOG_FILE"
        fi
    else
        # ───── NORMAL MODE – only specific files ─────
        for file in "${FILES_TO_REMOVE[@]}"; do
            CURRENT_FILE_TO_REMOVE="$(echo "$file" | xargs)"  # trim whitespace
            [[ -z "$CURRENT_FILE_TO_REMOVE" ]] && continue
            FILE_TO_REMOVE="${DIR_TO_LIST}${CURRENT_FILE_TO_REMOVE}"   # ← fixed: no \ before $
            
            if pct exec "$CTID" -- rm -f "$FILE_TO_REMOVE"; then
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] CTID $CTID: Removed $FILE_TO_REMOVE" >> "$LOG_FILE"
            else
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] CTID $CTID: ERROR removing file" >> "$LOG_FILE"
            fi
        done 
    fi

    # Capture the directory listing and log everything nicely
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] CTID $CTID: listing directory $DIR_TO_LIST" >> "$LOG_FILE"
    pct exec "$CTID" -- ls -lh "$DIR_TO_LIST" | \
    sed 's/^/    /' | \
    tee -a "$LOG_FILE"      
    echo "" >> "$LOG_FILE"

    # Shutdown if we started it
    if [[ $STARTED_BY_US -eq 1 ]]; then
        echo "  Shutting down again..."
        pct shutdown "$CTID" --timeout 15
        sleep 20
        pct status "$CTID" | grep -q running && pct stop "$CTID"
    fi
done

echo
echo "===================================================================="
echo "Finished! Log saved to →  $LOG_FILE"
# tail -15 "$LOG_FILE"
echo "===================================================================="