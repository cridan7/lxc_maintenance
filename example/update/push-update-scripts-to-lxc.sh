#!/bin/bash

DEB_SCRIPT="/opt/scripts/update/update_deb_to_trixie.sh"
UBUNTU_SCRIPT="/opt/scripts/update/update_ubuntu_to_plucky.sh"
DEST_DIR="/opt/update"
DESTINATION="$DEST_DIR/upgrade_system_release.sh"
LOG_DIR="/opt/scripts/update/log"
LOG_FILE="$LOG_DIR/lxc_system_summary_log"

# Ensure log directory exists
mkdir -p "$LOG_DIR"

# Header for summary file
[ ! -f "$LOG_FILE" ] && echo -e "CTID\tDISTRO\tCODENAME\tVERSION\tPUSHED_SCRIPT\tTIMESTAMP" > "$LOG_FILE"

# Sanity checks
[[ ! -f "$DEB_SCRIPT" ]] && { echo "ERROR: $DEB_SCRIPT missing"; exit 1; }
[[ ! -f "$UBUNTU_SCRIPT" ]] && { echo "ERROR: $UBUNTU_SCRIPT missing"; exit 1; }


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
#echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting push of system update scripts for ${#CTIDS[@]} containers" >> "$LOG_FILE"

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

    # === Reliable OS detection using only cat & grep (works everywhere) ===
    OS_RELEASE=$(pct exec "$CTID" -- cat /etc/os-release 2>/dev/null || echo "ERROR")
    
    if echo "$OS_RELEASE" | grep -q "^ID=debian"; then
        DISTRO="debian"
        CODENAME=$(echo "$OS_RELEASE" | grep '^VERSION_CODENAME=' | cut -d= -f2 | tr -d '"')
        VERSION=$(echo "$OS_RELEASE" | grep '^VERSION_ID=' | cut -d= -f2 | tr -d '"')
        SOURCE="$DEB_SCRIPT"
        TYPE="Debian → Trixie"
        
    elif echo "$OS_RELEASE" | grep -q "^ID=ubuntu"; then
        DISTRO="ubuntu"
        CODENAME=$(echo "$OS_RELEASE" | grep '^UBUNTU_CODENAME=' | cut -d= -f2 | tr -d '"' || echo "unknown")
        VERSION=$(echo "$OS_RELEASE" | grep '^VERSION_ID=' | cut -d= -f2 | tr -d '"')
        SOURCE="$UBUNTU_SCRIPT"
        TYPE="Ubuntu → Plucky"
        
    else
        # ←←← FIXED: same safe shutdown logic as everywhere else
        if [[ $STARTED_BY_US -eq 1 ]]; then
            echo "  Shutting down non-supported container..."
            pct shutdown "$CTID" --timeout 15
            sleep 20
            pct status "$CTID" | grep -q running && pct stop "$CTID"
        fi
        echo
        continue
    fi

    echo "  Detected: $DISTRO $VERSION ($CODENAME) → pushing $TYPE script"

    pct exec "$CTID" -- mkdir -p "$DEST_DIR"
    pct push "$CTID" "$SOURCE" "$DESTINATION"
    if [[ $? -eq 0 ]]; then
        echo "  → Successfully pushed: $SOURCE → $DESTINATION for $CTID"
        echo -e "$CTID\t$SOURCE\t$DESTINATION\t$(date '+%Y-%m-%d %H:%M')" >> "$LOG_FILE"
        pct exec "$CTID" -- chmod 755 "$DESTINATION"
    else
         echo "  → Push FAILED"
    fi

    echo -e "$CTID\t$DISTRO\t$CODENAME\t$VERSION\t$DEST_PATH ($TYPE)\t$(date '+%Y-%m-%d %H:%M')" >> "$LOG_FILE"

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