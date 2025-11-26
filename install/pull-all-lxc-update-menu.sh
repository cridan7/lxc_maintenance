#!/bin/bash

LOG_DIR="/opt/scripts/update/log"
LOG_FILE="$LOG_DIR/lxc_pull_log"

DEST_DIR="/opt/scripts/update/update_menu"
SCRIPT_NAME="update-menu.sh"

# Create destination folder if it doesn't exist
mkdir -p "$DEST_DIR"

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
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting to pull update menu ${#CTIDS[@]} containers" >> "$LOG_FILE"

for CTID in "${CTIDS[@]}"; do
    echo "=== Processing CT $CTID ==="

    # Check current status
    STATUS=$(pct status "$CTID" | awk '{print $2}')

    # Remember if we had to start it
    STARTED_BY_US=0

    if [ "$STATUS" = "stopped" ]; then
        echo "  Container is stopped → starting temporarily..."
        pct start "$CTID"
        STARTED_BY_US=1
        # Give it a few seconds to fully boot (adjust if your containers are slow)
        sleep 10
    else
        echo "  Container is already running."
    fi

    # Check if the file actually exists inside the container
    if pct exec "$CTID" -- test -f "/opt/update/$SCRIPT_NAME"; then
        SOURCE="/opt/update/$SCRIPT_NAME"
        DEST="$DEST_DIR/${CTID}_$SCRIPT_NAME"

        echo "  Pulling $SOURCE → $DEST"
        pct pull "$CTID" "$SOURCE" "$DEST"

        if [ $? -eq 0 ]; then
            echo "  Successfully pulled and saved as ${CTID}_$SCRIPT_NAME"
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] CTID $CTID: Pulled $SOURCE → $DEST" >> "$LOG_FILE"
            # Make it executable just in case
            # chmod +x "$DEST"
        else
            echo "  ERROR: pct pull failed for CT $CTID"
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: pct pull failed for CT $CTID" >> "$LOG_FILE"
        fi
    else
        echo "  WARNING: /opt/update/$SCRIPT_NAME does not exist in CT $CTID → skipping"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: /opt/update/$SCRIPT_NAME does not exist in CT $CTID → skipping" >> "$LOG_FILE"
    fi

    # Stop again if we started it
    if [ $STARTED_BY_US -eq 1 ]; then
        echo "  Stopping container again..."
        pct shutdown "$CTID" --timeout 15
        # If it doesn't shut down gracefully, force after timeout
        sleep 20
        if pct status "$CTID" | grep -q running; then
            echo "  Forcing stop..."
            pct stop "$CTID"
        fi
    fi

    echo
done

echo
echo "===================================================================="
echo "Finished! Files are in  →  $DEST_DIR"
# tail -15 "$LOG_FILE"
echo "===================================================================="

