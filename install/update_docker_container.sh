#!/usr/bin/env bash
set -euo pipefail

image_tag="$1"
container_id="$2"

# Ensure jq is installed
command -v jq >/dev/null 2>&1 || {
  echo "Installing jq..."
  apt update && apt install -y jq
}

# Base arguments every container gets
declare -a docker_args=(
docker run
--detach                  # -d
)

    # ── Name ─────────────────────────────────────
    name=$(docker inspect --format '{{.Name}}' "$container_id" | sed 's|^/||')
    [[ -n "$name" ]] && docker_args+=(--name "$name")

    # ── Ports (-p) ───────────────────────────────
    while IFS= read -r mapping; do
    [[ -n "$mapping" ]] && docker_args+=(-p "$mapping")
    done < <(
    docker inspect --format='{{json .HostConfig.PortBindings}}' "$container_id" \
        | jq -r 'to_entries[] | "\(.value[0].HostPort):\(.key | sub("/tcp$";""))"' 2>/dev/null || true
    )

    # ── Restart policy ───────────────────────────
    restart=$(docker inspect --format '{{.HostConfig.RestartPolicy.Name}}' "$container_id")
    if [[ "$restart" != "no" && -n "$restart" ]]; then
    docker_args+=(--restart="$restart")
    fi

    # ── Environment variables (-e) ───────────────
    while IFS= read -r env; do
    [[ -n "$env" ]] && docker_args+=(-e "$env")
    done < <(
    docker inspect --format='{{json .Config.Env}}' "$container_id" \
        | jq -r '.[]' 2>/dev/null || true
    )

    # ── Volumes / binds (-v) ─────────────────────
    while IFS= read -r bind; do
    [[ -n "$bind" ]] && docker_args+=(-v "$bind")
    done < <(
    docker inspect --format='{{json .HostConfig.Binds}}' "$container_id" \
        | jq -r '.[]?' 2>/dev/null || true
    )

    # ── Command / Entrypoint (optional) ──────────
    cmd=$(docker inspect --format='{{json .Config.Cmd}}' "$container_id" | jq -r '@sh' 2>/dev/null || true)
    # jq '@sh' properly quotes the arguments for shell; we eval it safely because we control the input
    if [[ "$cmd" != "null" && -n "$cmd" ]]; then
    # shellcheck disable=SC2086
    eval "cmd_array=($cmd)"
    else
    cmd_array=()
    fi

# ── Stop + remove old container ──────────────
echo "Stopping and removing old container ($name / $container_id)..."
docker stop "$container_id" >/dev/null
docker rm "$container_id" >/dev/null

# ── Start new one ────────────────────────────
echo "Starting new container with the same configuration..."
# echo " → ${docker_args[*]} $image_tag ${cmd_array[*]}"

"${docker_args[@]}" "$image_tag" "${cmd_array[@]}"

echo "Container $name successfully restarted with latest $image_tag"
echo