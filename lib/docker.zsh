# dev-vice: docker

dps() { docker ps "$@" }
dpsa() { docker ps -a "$@" }
dimg() { docker images "$@" }
dlog() { docker logs -f "$@" }
dprune() { docker system prune -f "$@" }

# exec into a running container by (partial) name
dsh() {
  local name="$1"
  if [[ -z "$name" ]]; then
    echo "usage: dsh <container-name-or-id>" >&2
    return 1
  fi
  docker exec -it "$name" sh -c 'exec bash || exec sh'
}
