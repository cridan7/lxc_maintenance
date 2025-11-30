#!/usr/bin/env bash
# generate_update_menus.sh
# Reads installed_services.md, applies selection logic, and generates update menus with URL and Docker support
# Check 114_update-menu to update script

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
        echo "set -euo pipefail"
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

    # Docker services variables (tags left exactly as in installed_services.md)
    IFS=';' read -ra docker_services <<< "${CT_DOCKER[$CTID]}"
    for dsvc in "${docker_services[@]}"; do
        [[ -z "$dsvc" ]] && continue
        name="${dsvc%%|*}"
        image="${dsvc##*|}"
        var_name=$(echo "DOCKER_${name}_IMAGE" | tr '[:lower:]' '[:upper:]' | tr '-' '_')
        echo "$var_name=\"$image\"" >> "$menu_file"
    done

    # ============ FUNCTIONS ============
    {
        echo ""
        echo "run_update() {"
        echo "  local url=\"\$1\""
        echo "  echo \"Running update script...\""
        echo "  bash -c \"\$(wget -qLO - \"\$url\")\""
        echo "  echo \"Done.\""
        echo "}"
        echo ""
        echo "pause() {"
        echo "    echo"
        echo "    read -n 1 -s -r -p \"Press any key to return to the menu...\""
        echo "    echo"
        echo "}"
        echo ""
        echo "check_image_update() {"
        echo "    local container_id=\"\$1\""
        echo "    local image_name"
        echo ""
        echo "    image_name=\$(docker inspect --format='{{.Config.Image}}' \"\$container_id\") || {"
        echo "        echo \"Error: Invalid container ID: \$container_id\""
        echo "        return 2"
        echo "    }"
        echo ""
        echo "    local current_digest new_digest pull_output"
        echo ""
        echo "    current_digest=\$(docker image inspect \"\$image_name\" --format='{{index .RepoDigests 0}}' 2>/dev/null | cut -d'@' -f2 || true)"
        echo ""
        echo "    echo \"Pulling latest \$image_name to check for update ...\""
        echo "    pull_output=\$(docker pull \"\$image_name\")"
        echo ""
        echo "    new_digest=\$(docker image inspect \"\$image_name\" --format='{{index .RepoDigests 0}}' 2>/dev/null | cut -d'@' -f2 || true)"
        echo ""
        echo "    if [[ \"\$pull_output\" == *\"Image is up to date\"* ]]; then"
        echo "        echo \"Up to date: \$image_name\""
        echo "        return 0"
        echo "    elif [[ -n \"\$current_digest\" && -n \"\$new_digest\" && \"\$current_digest\" != \"\$new_digest\" ]]; then"
        echo "        echo \"UPDATE AVAILABLE → \$image_name\""
        echo "        echo \"   Old: \$current_digest\""
        echo "        echo \"   New: \$new_digest\""
        echo "        return 1"
        echo "    else"
        echo "        echo \"Unknown status (likely local-only image): \$image_name\""
        echo "        return 2"
        echo "    fi"
        echo "}"
        echo ""
        echo "update_docker() {"
        echo "  local image_tag=\"\$1\""
        echo "  container_id=\$(docker ps --filter \"ancestor=\$image_tag\" --format \"{{.ID}}\")"
        echo ""
        echo "  [[ -z \"\$container_id\" ]] && {"
        echo "      echo \"No running container for \$image_tag\""
        echo "      return 0"
        echo "  }"
        echo ""
        echo "  echo \"Checking for update: \$image_tag\""
        echo "  if check_image_update \"\$container_id\"; then"
        echo "      echo \"No update needed\""
        echo "  else"
        echo "      echo \"Update available → recreating container for \$image_tag\""
        echo "      bash /opt/update/update_docker_container.sh \"\$image_tag\" \"\$container_id\""
        echo "  fi"
        echo "}"
        echo ""
        echo "while true; do"
        echo "  clear"
        echo "  echo \"========== CTID $CTID Update Menu ==========\""
        echo "  echo \"1) Upgrade operating system\""
        echo "  echo \"2) Update operating system\""
        echo "  echo \"3) Clean operating system\""
        echo "  echo \"4) Fstrim container LVM (will not work in unprivileged containers)\""
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
        echo "    1) bash /opt/update/upgrade_system_release.sh ; pause ;;"
        echo "    2) bash /opt/update/update_system.sh ; pause ;;"
        echo "    3) bash /opt/update/clean.sh ; pause ;;"
        echo "    4) bash /opt/update/fstrim.sh ; pause ;;"
    } >> "$menu_file"

    idx=5
    for svc in "${services[@]}"; do
        [[ -z "$svc" ]] && continue
        var_name=$(echo "${svc%%|*}_URL" | tr '[:lower:]' '[:upper:]' | tr '-' '_')
        echo "    $idx) run_update \"\$$var_name\" ; pause ;;" >> "$menu_file"
        ((idx++))
    done

    for dsvc in "${docker_services[@]}"; do
        [[ -z "$dsvc" ]] && continue
        var_name=$(echo "DOCKER_${dsvc%%|*}_IMAGE" | tr '[:lower:]' '[:upper:]' | tr '-' '_')
        echo "    $idx) update_docker \"\$$var_name\" ; pause ;;" >> "$menu_file"
        ((idx++))
    done

    {
        echo "    0) echo \"Exiting.\"; exit 0 ;;"
        echo "    *) echo \"Invalid choice.\"; pause ;;"
        echo "  esac"
        echo "done"
    } >> "$menu_file"

    chmod +x "$menu_file"
done

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Completed generating menus for ${#TARGET_CTIDS[@]} containers." | tee -a "$LOG_FILE"
echo
echo "===================================================================="
echo "Finished!"
echo "===================================================================="