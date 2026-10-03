# digivice: node / package managers

ni() { npm install "$@" }
nr() { npm run "$@" }
nrs() { npm run start "$@" }
nrb() { npm run build "$@" }
nrt() { npm run test "$@" }

yi() { yarn install "$@" }
yr() { yarn run "$@" }

pni() { pnpm install "$@" }
pnr() { pnpm run "$@" }

# run the start/dev script with whichever package manager the project uses
drun() {
  local script="${1:-dev}"
  if [[ -f pnpm-lock.yaml ]]; then
    pnpm run "$script"
  elif [[ -f yarn.lock ]]; then
    yarn run "$script"
  elif [[ -f package-lock.json || -f package.json ]]; then
    npm run "$script"
  else
    echo "digivice: no package.json found" >&2
    return 1
  fi
}
