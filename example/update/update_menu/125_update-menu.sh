#!/usr/bin/env bash
# Auto-generated update menu for CTID 125

# Define URLs for each update script
GRAFANA_URL="https://github.com/community-scripts/ProxmoxVE/raw/main/ct/grafana.sh"
INFLUXDB_URL="https://github.com/community-scripts/ProxmoxVE/raw/main/ct/influxdb.sh"
TELEGRAF_URL="https://github.com/community-scripts/ProxmoxVE/raw/main/ct/telegraf.sh"
GLANCES_URL="https://github.com/community-scripts/ProxmoxVE/raw/main/tools/addon/glances.sh"

run_update() {
  local url="$1"
  echo "Running update script..."
  bash -c "$(wget -qLO - "$url")"
  echo "Done."
}

update_docker_service() {
  local image_tag="$1"
  echo "Updating Docker service for image: $image_tag"
  docker pull "$image_tag"
  container_id=$(docker ps --filter "ancestor=$image_tag" --format "{{.ID}}")
  if [[ -n "$container_id" ]]; then
    docker stop "$container_id" && docker rm "$container_id"
    docker run -d "$image_tag"
  else
    echo "No running container found for $image_tag"
  fi
}

while true; do
  clear
  echo "========== CTID 125 Update Menu =========="
  echo "1) Upgrade operating system"
  echo "2) Update operating system"
  echo "3) Clean operating system"
  echo "4) Fstrim container LVM"
  echo "5) Update GRAFANA"
  echo "6) Update INFLUXDB"
  echo "7) Update TELEGRAF"
  echo "8) Update GLANCES"
  echo "0) Exit"
  echo "============================================"
  read -rp "Choose an option: " choice
  case "$choice" in
    1) bash /opt/update/upgrade_system_release.sh ;;
    2) bash /opt/update/update_system.sh ;;
    3) bash /opt/update/clean.sh ;;
    4) bash /opt/update/clean.sh ;;
    5) run_update "$GRAFANA_URL" ;;
    6) run_update "$INFLUXDB_URL" ;;
    7) run_update "$TELEGRAF_URL" ;;
    8) run_update "$GLANCES_URL" ;;
    0) echo "Exiting."; exit 0 ;;
    *) echo "Invalid choice. Press enter to continue."; read -r ;;
  esac
done
