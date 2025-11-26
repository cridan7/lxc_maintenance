
#!/bin/bash

LOG_DIR="/opt/scripts/update/log"
LOG_FILE="$LOG_DIR/lxc_remove_log"
DIR_TO_LIST="/opt/update/"
FILE_TO_REMOVE="/opt/update/update_system_release.sh"

# Ensure log directory exists
mkdir -p "$LOG_DIR"

# Get all container IDs by default
ALL_CTIDS=($(pct list | awk 'NR>1 {print $1}'))
CTIDS=("${ALL_CTIDS[@]}")  # Default: all containers

MODE="all"
SKIP_IDS=()
CUSTOM_IDS=()

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -c)
            MODE="custom"
            shift
            IFS=',' read -ra CUSTOM_IDS <<< "$1"
            ;;
        -s)
            MODE="skip"
            shift
            IFS=',' read -ra SKIP_IDS <<< "$1"
            ;;
        --help|-h)
            echo "Usage:"
            echo "  $0                # Process all containers"
            echo "  $0 -c 100,110     # Process only these containers"
            echo "  $0 -s 100,110     # Process all except these containers"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
    shift
done

# Apply mode logic
if [[ "$MODE" == "custom" ]]; then
    CTIDS=("${CUSTOM_IDS[@]}")

elif [[ "$MODE" == "skip" ]]; then
    NEW_CTIDS=()
    for ct in "${CTIDS[@]}"; do
        skip=false
        for id in "${SKIP_IDS[@]}"; do
            [[ "$ct" == "$id" ]] && skip=true && break
        done
        if ! $skip; then
            NEW_CTIDS+=("$ct")
        fi
    done
    CTIDS=("${NEW_CTIDS[@]}")
fi

echo "Found ${#CTIDS[@]} LXC containers. Starting processing..."
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting cleanup for ${#CTIDS[@]} containers" >> "$LOG_FILE"

# Loop through containers
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


    if pct exec "$CTID" -- rm -f $FILE_TO_REMOVE; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] CTID $CTID: Removed $FILE_TO_REMOVE" >> "$LOG_FILE"
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] CTID $CTID: ERROR removing file" >> "$LOG_FILE"
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
