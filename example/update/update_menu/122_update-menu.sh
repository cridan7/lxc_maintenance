#!/usr/bin/env bash
# Auto-generated update menu for CTID 122

# Define URLs for each update script
DOCKER_URL="https://github.com/community-scripts/ProxmoxVE/raw/main/ct/docker.sh"
DOCKER_DOCKER_PORTAINER_IMAGE="portainer/portainer-ce:lts"
DOCKER_DOCKER_OWNTRACKS_RECORDER_IMAGE="owntracks/recorder:latest"
DOCKER_DOCKER_MQTTX_WEB_IMAGE="emqx/mqttx-web:latest"
DOCKER_DOCKER_OWNTRACKS_FRONTEND_IMAGE="owntracks/frontend:latest"
DOCKER_DOCKER_CHANNELTUBE_IMAGE="thewicklowwolf/channeltube:latest"
DOCKER_DOCKER_FIREFOX_IMAGE="linuxserver/firefox:latest"

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
  echo "========== CTID 122 Update Menu =========="
  echo "1) Upgrade operating system"
  echo "2) Update operating system"
  echo "3) Clean operating system"
  echo "4) Fstrim container LVM"
  echo "5) Update DOCKER"
  echo "6) Update Docker DOCKER-portainer"
  echo "7) Update Docker DOCKER-owntracks-recorder"
  echo "8) Update Docker DOCKER-mqttx-web"
  echo "9) Update Docker DOCKER-owntracks-frontend"
  echo "10) Update Docker DOCKER-channeltube"
  echo "11) Update Docker DOCKER-firefox"
  echo "0) Exit"
  echo "============================================"
  read -rp "Choose an option: " choice
  case "$choice" in
    1) bash /opt/update/upgrade_system_release.sh ;;
    2) bash /opt/update/update_system.sh ;;
    3) bash /opt/update/clean.sh ;;
    4) bash /opt/update/clean.sh ;;
    5) run_update "$DOCKER_URL" ;;
    6) update_docker_service "$DOCKER_DOCKER_PORTAINER_IMAGE" ;;
    7) update_docker_service "$DOCKER_DOCKER_OWNTRACKS_RECORDER_IMAGE" ;;
    8) update_docker_service "$DOCKER_DOCKER_MQTTX_WEB_IMAGE" ;;
    9) update_docker_service "$DOCKER_DOCKER_OWNTRACKS_FRONTEND_IMAGE" ;;
    10) update_docker_service "$DOCKER_DOCKER_CHANNELTUBE_IMAGE" ;;
    11) update_docker_service "$DOCKER_DOCKER_FIREFOX_IMAGE" ;;
    0) echo "Exiting."; exit 0 ;;
    *) echo "Invalid choice. Press enter to continue."; read -r ;;
  esac
done
