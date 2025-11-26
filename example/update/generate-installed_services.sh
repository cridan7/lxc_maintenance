
#!/bin/bash
set -euo pipefail

COMMUNITY_FILE="/opt/opt/scripts/update/community_services"
OUTPUT_MD="/opt/scripts/update/installed_services.md"

[[ -f "$COMMUNITY_FILE" ]] || { echo "ERROR: $COMMUNITY_FILE not found"; exit 1; }

# ── Parse community_services ──
declare -A URL_FOR
declare -A DOCKER_FOR
declare -a SERVICES

while IFS= read -r line; do
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    cleaned_line="${line%,DOCKER}"
    if [[ $cleaned_line =~ ^([A-Z0-9_]+)_URL=\"([^\"]+)\"$ ]]; then
        svc="${BASH_REMATCH[1]}"
        url="${BASH_REMATCH[2]}"
        URL_FOR["$svc"]="$url"
        DOCKER_FOR["$svc"]=$( [[ "$line" == *",DOCKER"* ]] && echo "Yes" || echo "No" )
        SERVICES+=("$svc")
    fi
done < "$COMMUNITY_FILE"

echo "Loaded ${#SERVICES[@]} community services"

# ── Backup existing file ──
if [[ -f "$OUTPUT_MD" ]]; then
    ts=$(date +'%Y%m%d_%H%M%S')
    cp "$OUTPUT_MD" "${OUTPUT_MD%.md}_$ts.md"
    echo "Backup created: ${OUTPUT_MD%.md}_$ts.md"
fi

# ── Header ──
cat > "$OUTPUT_MD" <<EOF
# Proxmox LXC → Installed Community Services (parseable)
*Generated on $(date +'%Y-%m-%d %H:%M') – one service per line*

| CTID | Service | Script URL | Dockerized |
|------|---------|------------|------------|
EOF

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

for CTID in "${CTIDS[@]}"; do

    echo "=== Scanning CT $CTID ... ==="

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

    UNITS=$(pct exec "$CTID" -- systemctl list-units --no-legend --no-pager 2>/dev/null || echo "")

    # Community services detection
    for svc in "${SERVICES[@]}"; do
        lower=$(echo "$svc" | tr '[:upper:]' '[:lower:]')
        if echo "$UNITS" | awk '{$1=$2=$3=$4=""; gsub(/^ +/, "", $0); print $0}' | grep -qiE "(^| )${lower}( |$)"; then
            if [[ "$svc" == "DOCKER" ]]; then
                echo "| $CTID | $svc | ${URL_FOR[$svc]} | No |" >> "$OUTPUT_MD"
            else
                echo "| $CTID | $svc | ${URL_FOR[$svc]} | ${DOCKER_FOR[$svc]} |" >> "$OUTPUT_MD"
            fi
        fi
    done

    # Docker detection and listing
    if echo "$UNITS" | grep -qi 'docker.service'; then
        echo "Docker detected in CT$CTID, listing containers..."
        DOCKER_PS=$(pct exec "$CTID" -- docker ps --format '{{.Names}}|{{.Image}}' 2>/dev/null || echo "")
        if [[ -n "$DOCKER_PS" ]]; then
            while IFS='|' read -r name image; do
                [[ -z "$name" || -z "$image" ]] && continue
                echo "| $CTID | DOCKER-$name | $image | Yes |" >> "$OUTPUT_MD"
            done <<< "$DOCKER_PS"
        fi
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

done

echo
echo "===================================================================="
echo "Finished! Inventory of running services in →  $OUTPUT_MD"
# tail -15 "$OUTPUT_MD"
echo "===================================================================="
