#!/bin/bash

DESTINATION_PATH="/bin"
SOURCE_PATH="/opt/scripts/update/bin"
SOURCE_NAME="update"
LOG_DIR="/opt/scripts/update/log"
LOG_FILE="$LOG_DIR/lxc_push_log"

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
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting file push for ${#CTIDS[@]} containers" >> "$LOG_FILE"

for CTID in "${CTIDS[@]}"; do
    echo "=== CT $CTID ==="
    SOURCE="${SOURCE_PATH}/${CTID}_${SOURCE_NAME}"
    DESTINATION="${DESTINATION_PATH}/${SOURCE_NAME}"

    # Push forcing permissions (usually 700 -rwx------ or 755 -rwxr-xr-x)
    if [[ ! -f "$SOURCE" ]]; then 
        echo "ERROR: $SOURCE missing"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] CTID $CTID: $SOURCE is missing" >> "$LOG_FILE"
    else 
        STARTED_BY_US=0
        # if pct status "$CTID" | grep -q "stopped"; then
        if [[ "$(pct status "$CTID" | awk '{print $2}')" == "stopped" ]]; then
            echo "  Stopped → starting temporarily"
            pct start "$CTID"
            STARTED_BY_US=1
            sleep 10
        else
            echo "  Already running"
        fi

        # Check if the file actually exists inside the container
        if pct exec "$CTID" -- test -f "$DESTINATION"; then
            
            # Backup existing file to /opt/update/backup
            BACKUP_FOLDER="/opt/update/backup"
            pct exec "$CTID" -- mkdir -p "$BACKUP_FOLDER"

            BACKUP_FILE="${BACKUP_FOLDER}/$(date '+%Y%m%d_%H%M%S')_${SOURCE_NAME}"
            pct exec "$CTID" -- cp "$DESTINATION" "$BACKUP_FILE"
            
            echo "  Backed up: $DESTINATION → $BACKUP_FILE inside $CTID"
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] CTID $CTID: Backed up $DESTINATION → $BACKUP_FILE" >> "$LOG_FILE"
        fi 

        # pct push "$CTID" "$SOURCE" "$DEST_PATH" --perms 755
        pct push "$CTID" "$SOURCE" "$DESTINATION"
        if [[ $? -eq 0 ]]; then
            echo "  → Successfully pushed: $SOURCE → $DESTINATION for $CTID"
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] CTID $CTID: Pushed $SOURCE → $DESTINATION" >> "$LOG_FILE"
            pct exec "$CTID" -- chmod 755 "$DESTINATION"
        else
            echo "  → Push FAILED"
        fi
       
    fi
    
    # Shutdown if we started it
    if [[ $STARTED_BY_US -eq 1 ]]; then
        echo "  Shutting down again..."
        pct shutdown "$CTID" --timeout 15
        sleep 20
        pct status "$CTID" | grep -q running && pct stop "$CTID"
    fi
    echo
done

echo "===================================================================="
echo "Finished! Log saved to → $LOG_FILE"
# tail -15 "$LOG_FILE"
echo "===================================================================="