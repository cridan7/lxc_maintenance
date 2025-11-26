#!/usr/bin/env bash
# generate_update_menus.sh
# Reads installed_services.md, applies selection logic, and generates update menus with URL and Docker support

SERVICES_FILE="/opt/scripts/update/installed_services.md"
MENU_DIR="/opt/scripts/update/update_menu"
LOG_DIR="/opt/scripts/update/log"
LOG_FILE="$LOG_DIR/generate_update_menu_log"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

mkdir -p "$MENU_DIR" "$LOG_DIR"

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

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Reading installed services..." | tee -a "$LOG_FILE"

# Step 1: Read installed_services.md into CT_SERVICES and CT_DOCKER
declare -A CT_SERVICES
declare -A CT_DOCKER

while IFS='|' read -r col1 ctid service url dockerized col6; do
    [[ "$ctid" =~ ^CTID$ || "$ctid" =~ ^------$ ]] && continue
    [[ -z "$ctid" || -z "$service" || -z "$url" ]] && continue

    ctid=$(echo "$ctid" | xargs)
    service=$(echo "$service" | xargs)
    url=$(echo "$url" | xargs)
    dockerized=$(echo "$dockerized" | xargs)

    if [[ "$dockerized" == "Yes" ]]; then
        CT_DOCKER["$ctid"]+="$service|$url;"
    else
        CT_SERVICES["$ctid"]+="$service|$url;"
    fi
done < "$SERVICES_FILE"

ALL_CTIDS=($(printf "%s\n" "${!CT_SERVICES[@]}" "${!CT_DOCKER[@]}" | sort -u))

# Step 2: Apply mode logic
TARGET_CTIDS=()
if [[ "$MODE" == "custom" ]]; then
    for id in "${CUSTOM_IDS[@]}"; do
        TARGET_CTIDS+=("$id")
    done
elif [[ "$MODE" == "skip" ]]; then
    for id in "${ALL_CTIDS[@]}"; do
        skip=false
        for s in "${SKIP_IDS[@]}"; do
            [[ "$id" == "$s" ]] && skip=true && break
        done
        if ! $skip; then
            TARGET_CTIDS+=("$id")
        fi
    done
else
    TARGET_CTIDS=("${ALL_CTIDS[@]}")
fi

echo "Found ${#TARGET_CTIDS[@]} containers to process: ${TARGET_CTIDS[*]}" | tee -a "$LOG_FILE"

# Step 3: Generate menus
for CTID in "${TARGET_CTIDS[@]}"; do
    menu_file="$MENU_DIR/${CTID}_update-menu.sh"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Generating menu for CTID $CTID..." | tee -a "$LOG_FILE"

    if [[ -f "$menu_file" ]]; then
        mv "$menu_file" "${menu_file}.bak_$TIMESTAMP"
    fi

    {
        echo "#!/usr/bin/env bash"
        echo "# Auto-generated update menu for CTID $CTID"
        echo ""
        echo "# Define URLs for each update script"
    } > "$menu_file"

    # Normal services variables
    IFS=';' read -ra services <<< "${CT_SERVICES[$CTID]}"
    for svc in "${services[@]}"; do
        [[ -z "$svc" ]] && continue
        name="${svc%%|*}"
        url="${svc##*|}"
        var_name=$(echo "${name}_URL" | tr '[:lower:]' '[:upper:]' | tr '-' '_')
        echo "$var_name=\"$url\"" >> "$menu_file"
    done

    # Docker services variables
    IFS=';' read -ra docker_services <<< "${CT_DOCKER[$CTID]}"
    for dsvc in "${docker_services[@]}"; do
        [[ -z "$dsvc" ]] && continue
        name="${dsvc%%|*}"
        image="${dsvc##*|}"
        var_name=$(echo "DOCKER_${name}_IMAGE" | tr '[:lower:]' '[:upper:]' | tr '-' '_')
        echo "$var_name=\"$image\"" >> "$menu_file"
    done

    # Functions
    {
        echo ""
        echo "run_update() {"
        echo "  local url=\"\$1\""
        echo "  echo \"Running update script...\""
        echo "  bash -c \"\$(wget -qLO - \"\$url\")\""
        echo "  echo \"Done.\""
        echo "}"
        echo ""
        echo "update_docker_service() {"
        echo "  local image_tag=\"\$1\""
        echo "  echo \"Updating Docker service for image: \$image_tag\""
        echo "  docker pull \"\$image_tag\""
        echo "  container_id=\$(docker ps --filter \"ancestor=\$image_tag\" --format \"{{.ID}}\")"
        echo "  if [[ -n \"\$container_id\" ]]; then"
        echo "    docker stop \"\$container_id\" && docker rm \"\$container_id\""
        echo "    docker run -d \"\$image_tag\""
        echo "  else"
        echo "    echo \"No running container found for \$image_tag\""
        echo "  fi"
        echo "}"
        echo ""
        echo "while true; do"
        echo "  clear"
        echo "  echo \"========== CTID $CTID Update Menu ==========\""
        echo "  echo \"1) Upgrade operating system\""
        echo "  echo \"2) Update operating system\""
        echo "  echo \"3) Clean operating system\""
        echo "  echo \"4) Fstrim container LVM\""
    } >> "$menu_file"

    idx=5
    for svc in "${services[@]}"; do
        [[ -z "$svc" ]] && continue
        name="${svc%%|*}"
        echo "  echo \"$idx) Update $name\"" >> "$menu_file"
        ((idx++))
    done

    for dsvc in "${docker_services[@]}"; do
        [[ -z "$dsvc" ]] && continue
        name="${dsvc%%|*}"
        echo "  echo \"$idx) Update Docker $name\"" >> "$menu_file"
        ((idx++))
    done

    {
        echo "  echo \"0) Exit\""
        echo "  echo \"============================================\""
        echo "  read -rp \"Choose an option: \" choice"
        echo "  case \"\$choice\" in"
        echo "    1) bash /opt/update/upgrade_system_release.sh ;;"
        echo "    2) bash /opt/update/update_system.sh ;;"
        echo "    3) bash /opt/update/clean.sh ;;"
        echo "    4) bash /opt/update/clean.sh ;;"
    } >> "$menu_file"

    idx=5
    for svc in "${services[@]}"; do
        [[ -z "$svc" ]] && continue
        var_name=$(echo "${svc%%|*}_URL" | tr '[:lower:]' '[:upper:]' | tr '-' '_')
        echo "    $idx) run_update \"\$$var_name\" ;;" >> "$menu_file"
        ((idx++))
    done

    for dsvc in "${docker_services[@]}"; do
        [[ -z "$dsvc" ]] && continue
        var_name=$(echo "DOCKER_${dsvc%%|*}_IMAGE" | tr '[:lower:]' '[:upper:]' | tr '-' '_')
        echo "    $idx) update_docker_service \"\$$var_name\" ;;" >> "$menu_file"
        ((idx++))
    done

    echo "    0) echo \"Exiting.\"; exit 0 ;;" >> "$menu_file"
    echo "    *) echo \"Invalid choice. Press enter to continue.\"; read -r ;;" >> "$menu_file"
    echo "  esac" >> "$menu_file"
    echo "done" >> "$menu_file"

    chmod +x "$menu_file"
done

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Completed generating menus for ${#TARGET_CTIDS[@]} containers." | tee -a "$LOG_FILE"
echo
echo "===================================================================="
echo "Finished!"
echo "===================================================================="
