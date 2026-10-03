# dev-vice: scaffold GitHub Actions workflows

# create .github/workflows/<name>.yml (default name: ci) from a
# starter template picked by what's in the current project - node
# (package.json), python (requirements.txt/pyproject.toml), or a
# generic placeholder otherwise. Refuses to overwrite an existing file.
ghwfnew() {
  local name="${1:-ci}"
  local dir=".github/workflows"
  local file="$dir/$name.yml"

  if [[ -f "$file" ]]; then
    echo "ghwfnew: $file already exists" >&2
    return 1
  fi

  mkdir -p "$dir"

  if [[ -f package.json ]]; then
    _devvice_workflow_template_node > "$file"
  elif [[ -f requirements.txt || -f pyproject.toml ]]; then
    _devvice_workflow_template_python > "$file"
  else
    _devvice_workflow_template_generic > "$file"
  fi

  echo "✅ created $file"
}

# list workflow files in this repo
ghwfls() {
  if [[ ! -d .github/workflows ]]; then
    echo "ghwfls: no .github/workflows directory here" >&2
    return 1
  fi
  ls .github/workflows
}

# open a workflow file in $EDITOR (defaults to vi)
ghwfedit() {
  local name="${1:?usage: ghwfedit <name>}"
  "${EDITOR:-vi}" ".github/workflows/$name.yml"
}

_devvice_workflow_template_node() {
  cat <<'EOF'
name: CI

on:
  push:
    branches: [main]
  pull_request:

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
      - run: npm ci
      - run: npm test
EOF
}

_devvice_workflow_template_python() {
  cat <<'EOF'
name: CI

on:
  push:
    branches: [main]
  pull_request:

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: "3.12"
      - run: pip install -r requirements.txt
      - run: pytest
EOF
}

_devvice_workflow_template_generic() {
  cat <<'EOF'
name: CI

on:
  push:
    branches: [main]
  pull_request:

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: echo "add your build/test commands here"
EOF
}
